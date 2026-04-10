# USB Restore Procedure

> Schritt-für-Schritt Wiederherstellung aus USB-Backup  
> Disaster Recovery für komplette oder partielle Restore

---

## Überblick

| Szenario | Restore-Zeit | Datenverlust |
|----------|--------------|--------------|
| Einzelne Datei | 1 min | Keiner |
| Datenbank | 5 min | Seit letztem Backup |
| Secrets/SSH | 5 min | Keiner |
| Full System | 30-60 min | Seit letztem Backup |

**Backup-Häufigkeit:** Täglich um 02:00

---

## Szenario 1: Einzelne Datei wiederherstellen

### Ziel

Eine spezifische Datei aus USB-Backup zurückholen.

### Schritte

```bash
# 1. Backup-Verzeichnis finden
ls -la /mnt/usb-backup/backups/
# 20260409  20260410  (Format: YYYYMMDD)

# 2. Datei lokalisieren
find /mnt/usb-backup/backups/20260410 -name "*.db" -o -name "*.yaml"

# 3. Restore (Dry-Run zuerst)
rsync -avn /mnt/usb-backup/backups/20260410/path/to/file.db /home/steges/path/to/

# 4. Wenn OK → echtes Restore
rsync -av /mnt/usb-backup/backups/20260410/path/to/file.db /home/steges/path/to/

# 5. Verify
ls -la /home/steges/path/to/file.db
diff /mnt/usb-backup/backups/20260410/path/to/file.db /home/steges/path/to/file.db
```

---

## Szenario 2: SQLite Datenbank wiederherstellen

### Vorbereitung

```bash
# 1. Service stoppen der die DB nutzt
docker compose stop <service>

# 2. Aktuelle DB sichern (falls nötig)
cp /home/steges/infra/openclaw-data/memory/current.db \
   /home/steges/infra/openclaw-data/memory/current-corrupt-$(date +%Y%m%d).db
```

### Restore

```bash
# 3. Aus Backup restoren
LATEST_BACKUP=$(ls -td /mnt/usb-backup/backups/*/infra/openclaw-data/memory/*.db | head -1)

cp "$LATEST_BACKUP" /home/steges/infra/openclaw-data/memory/current.db

# 4. Integrität prüfen
sqlite3 /home/steges/infra/openclaw-data/memory/current.db "PRAGMA integrity_check;"
# Sollte zeigen: ok

# 5. Permissions
cd /home/steges
find infra/openclaw-data -name "*.db" -exec chmod 644 {} \;

# 6. Service starten
docker compose start <service>

# 7. Health-Check
docker compose ps
```

---

## Szenario 3: Secrets und SSH Keys

### SSH Keys

```bash
# 1. Backup-Verzeichnis finden
SSH_BACKUP=$(find /mnt/usb-backup/backups -name ".ssh" -type d | head -1)

# 2. Aktuelle sichern
mv ~/.ssh ~/.ssh-old-$(date +%Y%m%d)

# 3. Restore
rsync -av "$SSH_BACKUP/" ~/.ssh/

# 4. Permissions fixen
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 644 ~/.ssh/authorized_keys 2>/dev/null || true

# 5. Test
ssh -T git@github.com
```

### .env Files

```bash
# 1. Finden
ENV_BACKUP=$(find /mnt/usb-backup/backups -name ".env" | head -1)

# 2. Restore
cp "$ENV_BACKUP" /home/steges/

# 3. Secrets prüfen
cat /home/steges/.env | head -5
```

---

## Szenario 4: Docker Volume Restore

### Vorbereitung

```bash
# 1. Container stoppen
cd /home/steges
docker compose down

# 2. Aktuelle Volumes sichern (optional)
docker run --rm \
  -v steges_grafana_data:/data \
  -v /mnt/usb-backup/emergency-volumes:/backup \
  alpine tar czf /backup/grafana-$(date +%Y%m%d).tar.gz /data
```

### Volume Restore

```bash
# 3. Volume-Inhalt löschen (VORSICHT!)
docker volume rm steges_grafana_data 2>/dev/null || true
docker volume create steges_grafana_data

# 4. Aus Backup restoren
LATEST_BACKUP=$(ls -td /mnt/usb-backup/backups/*/docker-volumes/grafana* | head -1)

docker run --rm \
  -v steges_grafana_data:/data \
  -v "$LATEST_BACKUP:/backup:ro" \
  alpine sh -c "cd /data && tar xzf /backup/grafana.tar.gz --strip-components=1"

# 5. Starten
docker compose up -d

# 6. Verify
docker compose ps
docker compose logs --tail=20
```

---

## Szenario 5: Full System Restore (Disaster Recovery)

### Voraussetzungen

- [ ] NVMe funktioniert (oder Ersatz-SD/NVMe)
- [ ] USB-Backup Stick vorhanden
- [ ] GitHub Repo zugänglich
- [ ] Internet-Zugang

### Phase 1: Base System

```bash
# 1. Raspberry Pi OS installieren
# → Raspberry Pi Imager
# → Raspberry Pi OS (64-bit)
# → Hostname: steges-pi

# 2. Erstes Booten, Basics konfigurieren
sudo apt update
sudo apt install -y git curl vim htop

# 3. SSH Key generieren (wenn nicht restored)
ssh-keygen -t ed25519 -C "steges@homelab"
```

### Phase 2: Repository Clone

```bash
# 4. Repo clonen
cd /home/steges
git clone https://github.com/steges/homelab.git .

# 5. Secrets aus USB-Backup kopieren
USB_BACKUP=$(ls -td /mnt/usb-backup/backups/*/ | head -1)
cp "$USB_BACKUP/secrets/"* /home/steges/secrets/ 2>/dev/null || echo "No secrets backup"

# 6. SSH Keys restoren (siehe Szenario 3)
```

### Phase 3: Docker Stack

```bash
# 7. Docker installieren
# → Siehe docs/setup/docker-compose-setup.md

# 8. Container starten
cd /home/steges
docker compose pull
docker compose up -d

# 9. Volumes restoren (siehe Szenario 4)
```

### Phase 4: Daten Restore

```bash
# 10. Datenbanken restoren
# → Siehe Szenario 2

# 11. Configs prüfen
cat /home/steges/.env
cat /home/steges/docker-compose.yml | head -20

# 12. Services health-check
/home/steges/scripts/health-check.sh
```

### Phase 5: Backup reaktivieren

```bash
# 13. USB-Backup Setup
# → Siehe docs/setup/usb-backup-setup.md

# 14. Backup-Skill installieren
sudo /home/steges/agent/skills/backup-automation/scripts/install.sh

# 15. Test-Backup
/home/steges/agent/skills/backup-automation/scripts/backup-full.sh
```

---

## Szenario 6: GitHub-only Restore (ohne USB)

### Wenn USB-Backup nicht verfügbar

```bash
# 1. Repo ist auf GitHub
# → Code, Configs, Skills sind sicher

# 2. Datenbanken müssen neu initialisiert werden
cd /home/steges
docker compose up -d

# 3. Services bauen DBs neu auf (meist automatisch)
docker compose logs -f

# 4. Secrets neu eingeben (wurden nicht gebackupt)
# → .env Files neu erstellen
# → API Keys neu eingeben

# 5. SSH Keys neu generieren
ssh-keygen -t ed25519 -C "steges@homelab"
```

**Datenverlust:**
- ✅ Code/Configs: Keiner (GitHub)
- ❌ Datenbanken: Seit letztem manuellem Export
- ❌ Secrets: Müssen neu eingegeben werden

---

## Verify nach Restore

### Checkliste

```bash
# 1. System läuft?
uptime
free -h
df -h

# 2. Docker läuft?
docker compose ps
docker compose logs --tail=10

# 3. Services erreichbar?
curl -s http://localhost:3000/health || echo "Grafana check"
curl -s http://localhost:9090/-/healthy || echo "Prometheus check"

# 4. Datenbanken OK?
sqlite3 /path/to/db.db "SELECT count(*) FROM table;"

# 5. Backup funktioniert?
/home/steges/agent/skills/backup-automation/scripts/backup-full.sh
```

### Automatische Verifikation

```bash
# Backup-Verify laufen lassen
/home/steges/agent/skills/backup-automation/scripts/backup-verify.sh
```

---

## Dry-Run Mode

### Restore simulieren

```bash
# --dry-run flag nutzen (wenn verfügbar)
/home/steges/agent/skills/backup-automation/scripts/backup-restore.sh \
    --date 20260410 \
    --dry-run

# Oder rsync mit -n (dry-run)
rsync -avn /mnt/usb-backup/backups/20260410/ /home/steges/
```

---

## Troubleshooting

### Problem: "Permission denied"

```bash
# Ownership fixen
sudo chown -R steges:steges /home/steges

# Docker-Permissions
sudo usermod -aG docker steges
newgrp docker
```

### Problem: "Device or resource busy"

```bash
# Prozesse finden
sudo lsof /home/steges/path/to/file

# Service stoppen
docker compose stop <service>
```

### Problem: Datenbank kann nicht geöffnet werden

```bash
# Lock-File?
ls -la /path/to/*.db*
rm /path/to/*.db-journal 2>/dev/null || true

# Corruption check
sqlite3 /path/to/db.db "PRAGMA integrity_check;"

# Wenn korrupt → älteres Backup versuchen
```

---

## Post-Restore Actions

### Sofort

- [ ] Alle Services laufen?
- [ ] Datenbank-Integrität OK?
- [ ] Backup neu durchführen
- [ ] Logs auf Fehler prüfen

### Innerhalb 24h

- [ ] Monitoring Dashboard prüfen
- [ ] GitHub Push funktioniert?
- [ ] USB-Backup läuft?
- [ ] Dokumentation updaten (was war der Grund?)

---

## Verweise

- `docs/setup/usb-backup-setup.md` – USB Setup
- `docs/runbooks/backup-failure-recovery.md` – Backup-Probleme
- `docs/infrastructure/backup-strategy.md` – Backup-Konzept
