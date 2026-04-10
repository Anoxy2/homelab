# Backup Failure Recovery Runbook

> Was tun wenn Backup fehlschlägt?  
> Schritt-für-Schritt Recovery für alle Backup-Szenarien

---

## Überblick

| Szenario | Schwere | Erste Maßnahme |
|----------|---------|----------------|
| USB nicht gemountet | Mittel | Manuell mounten |
| GitHub Push failed | Mittel | Network check, retry |
| USB voll | Kritisch | Alte Backups löschen |
| Beides failed | Kritisch | Sofort untersuchen |
| Datenbank korrupt | Kritisch | Previous Backup nutzen |

---

## Szenario 1: USB nicht gemountet

### Symptome

```bash
# Status-Check zeigt:
USB: NOT MOUNTED (/mnt/usb-backup)
```

### Diagnose

```bash
# 1. Stick eingesteckt?
lsusb
# Sollte zeigen: Bus 002 Device 003: ID xxxx:xxxx ...

# 2. Device erkannt?
lsblk
# Sollte zeigen: sda, sda1 oder nvme0n1p3

# 3. fstab korrekt?
cat /etc/fstab | grep usb
```

### Lösung

```bash
# Manuell mounten
sudo mount -a

# Oder direkt
sudo mount /dev/sda1 /mnt/usb-backup

# Prüfen
mount | grep usb-backup
ls /mnt/usb-backup
```

### Persistente Lösung

```bash
# Wenn Stick nicht automatisch mountet:
# 1. Label prüfen
sudo e2label /dev/sda1

# 2. fstab korrigieren
echo 'LABEL=usb-backup /mnt/usb-backup ext4 defaults,noatime,nofail 0 2' | \
    sudo tee -a /etc/fstab
```

---

## Szenario 2: USB voll (Disk Full)

### Symptome

```bash
# Status zeigt:
USB: WARNING (95% full) oder CRITICAL
```

### Diagnose

```bash
# Platz anzeigen
df -h /mnt/usb-backup

# Alte Backups zählen
ls /mnt/usb-backup/backups/ | wc -l

# Größe pro Backup
du -sh /mnt/usb-backup/backups/*
```

### Sofortmaßnahme

```bash
# Alte Backups löschen (>14 Tage)
find /mnt/usb-backup/backups -maxdepth 1 -type d -mtime +14 -exec sudo rm -rf {} + 2>/dev/null

# Platz prüfen
df -h /mnt/usb-backup
```

### Automatische Cleanup

```bash
# Backup-Skill hat eigene Cleanup-Logik
# Manuelles Cleanup falls nötig:
/home/steges/agent/skills/backup-automation/scripts/backup-usb.sh --cleanup-only
```

### Langfristige Lösung

```bash
# 1. Größeren Stick kaufen (siehe hardware-upgrades.md)
# 2. Retention anpassen in backup-usb.sh
# 3. Kompression prüfen (SQLite ist bereits komprimiert)
```

---

## Szenario 3: GitHub Push Failed

### Symptome

```bash
# GitHub Status zeigt:
GitHub: ERROR - Push failed
```

### Diagnose

```bash
# 1. Network check
ping github.com -c 3

# 2. GitHub erreichbar?
curl -I https://github.com

# 3. Auth check
gh auth status

# 4. Remote URL
cd /home/steges && git remote -v
```

### Lösung: Network Issue

```bash
# DNS prüfen
nslookup github.com

# Temporär 1.1.1.1 nutzen
sudo sed -i 's/nameserver.*/nameserver 1.1.1.1/' /etc/resolv.conf

# Retry
cd /home/steges && git push
```

### Lösung: Auth Issue

```bash
# Token erneuern
gh auth refresh

# Oder neu einloggen
gh auth logout
gh auth login

# Retry push
cd /home/steges && git push
```

### Lösung: Conflict

```bash
# Pull first
git pull --rebase origin main

# Resolve conflicts if any
# Then push
git push
```

---

## Szenario 4: Beide Backups fehlgeschlagen

### Sofortmaßnahmen (Kritisch!)

```bash
# 1. Manuelles Backup anstoßen
sudo /home/steges/agent/skills/backup-automation/scripts/backup-full.sh 2>&1 | tee /tmp/backup-debug.log

# 2. Logs prüfen
tail -50 /var/log/backup-automation.log

# 3. State prüfen
cat /home/steges/agent/skills/backup-automation/.state/last-backup.json
```

### Eskalation

**Wenn Backup 3+ Tage fehlschlägt:**

1. **Issue erstellen**
   ```bash
   /home/steges/agent/skills/github-automation/scripts/gh-issue-create.sh \
       "CRITICAL: Backup failure" \
       "Backup failed 3 days in a row. Logs attached."
   ```

2. **Manuelles Backup auf externe SSD**
   ```bash
   sudo tar czf /media/external/emergency-backup-$(date +%Y%m%d).tar.gz \
       /home/steges/infra/openclaw-data/
   ```

3. **Steges informieren**
   ```bash
   /home/steges/scripts/claw-send.sh "🚨 Backup failure - manual intervention needed"
   ```

---

## Szenario 5: Datenbank korrupt

### Symptome

```bash
# Verify zeigt:
Database integrity: FAILED
```

### Diagnose

```bash
# Welche DB?
ls -la /home/steges/infra/openclaw-data/memory/

# Integrität prüfen
sqlite3 /path/to/db.db "PRAGMA integrity_check;"
```

### Lösung

```bash
# 1. Stoppe Services die DB nutzen
docker compose stop openclaw-agent  # oder entsprechender Service

# 2. Backup der korrupten DB (für forensische Analyse)
cp /path/to/corrupt.db /mnt/usb-backup/corrupt-backup-$(date +%Y%m%d).db

# 3. Vorherige Version aus USB-Backup restoren
LATEST_BACKUP=$(ls -t /mnt/usb-backup/backups/*/infra/openclaw-data/memory/*.db | head -1)
cp "$LATEST_BACKUP" /path/to/db.db

# 4. Services neustarten
docker compose start openclaw-agent

# 5. Daten-Integrität prüfen
sqlite3 /path/to/db.db "PRAGMA integrity_check;"
```

---

## Szenario 6: USB-Stick defekt

### Symptome

- I/O Errors beim Lesen/Schreiben
- SMART-Attribute zeigen Fehler
- Stick wird nicht erkannt

### Sofortmaßnahme

```bash
# 1. Aktuellen Zustand sichern (falls möglich)
rsync -av --ignore-errors /mnt/usb-backup/ /tmp/emergency-backup/ 2>/dev/null || true

# 2. GitHub-Backup ist noch OK → Code/Configs sicher
# 3. Neue Datenbanken manuell exportieren
```

### Recovery

```bash
# 1. Neuen Stick kaufen (siehe hardware-upgrades.md)
# 2. Setup folgen: docs/setup/usb-backup-setup.md
# 3. Restore aus GitHub:
git clone https://github.com/steges/homelab.git /tmp/recovery

# 4. Datenbanken neu erstellen (Services starten, autom. Initialisierung)
docker compose up -d

# 5. Manuelles Backup auf neuen Stick
/home/steges/agent/skills/backup-automation/scripts/backup-usb.sh
```

---

## Preventive Measures

### Tägliche Checks

```bash
# In crontab oder HEARTBEAT:
/home/steges/agent/skills/backup-automation/scripts/backup-status.sh
```

### Weekly Verify

```bash
# Timer läuft automatisch sonntags 04:00
# Oder manuell:
/home/steges/agent/skills/backup-automation/scripts/backup-verify.sh
```

### Monitoring

```bash
# Prometheus Alert
- alert: BackupFailed
  expr: backup_last_success < (time() - 86400 * 2)
  for: 1h
  severity: critical
```

---

## Checkliste: Post-Recovery

- [ ] Backup manuell ausgeführt?
- [ ] Logs auf Fehler geprüft?
- [ ] State-File zeigt SUCCESS?
- [ ] USB Status OK?
- [ ] GitHub Status OK?
- [ ] Datenbank-Integrität OK?
- [ ] Alle Services laufen?
- [ ] Monitoring aktiviert?

---

## Verweise

- `docs/setup/usb-backup-setup.md` – USB Setup
- `docs/setup/github-automation-setup.md` – GitHub Setup
- `docs/runbooks/usb-restore-procedure.md` – Full Restore
- `docs/runbooks/github-auth-refresh.md` – Token erneuern
