# Backup-Strategie

> GitHub + USB-Stick als primäre Backup-Ziele  
> Stand: April 2026

---

## Übersicht

| Ziel | Typ | Was | Frequenz |
|------|-----|-----|----------|
| **GitHub** | Cloud | Code, Configs, Docs, Skills | Bei jeder Änderung (git push) |
| **USB-Stick** | Lokal | Daten, Secrets, große Files, SQLite | Täglich (automatisch) |

**Prinzip:** GitHub für alles versionierbare, USB-Stick für lokale Daten und schnelle Wiederherstellung.

---

## GitHub-Backup

### Repository: `steges/homelab`

**URL:** https://github.com/steges/homelab

### Was ist auf GitHub?

| Kategorie | Pfad (lokal) | GitHub-Pfad |
|-----------|--------------|-------------|
| **Dokumentation** | `docs/` | `docs/` |
| **OpenClaw Doku** | `docs/openclaw/` | `docs/openclaw/` |
| **Infrastructure Doku** | `docs/infrastructure/` | `docs/infrastructure/` |
| **Skills** | `agent/skills/` | `agent/skills/` |
| **Scripts** | `scripts/` | `scripts/` |
| **systemd** | `systemd/` | `systemd/` |
| **Configs** | `*.yml`, `*.yaml`, `*.json` | Root |
| **Docker Compose** | `docker-compose.yml` | Root |
| **Caddy** | `caddy/Caddyfile` | `caddy/` |
| **READMEs** | `README.md`, `CLAUDE.md` | Root |
| **CHANGELOG** | `CHANGELOG.md` | Root |

### Was ist NICHT auf GitHub?

| Typ | Grund |
|-----|-------|
| **Secrets** (`.env`, API-Keys) | Sicherheit |
| **SQLite DBs** | Binär, zu groß |
| **Logs** | Temporär |
| **Docker Volumes** | Werden neu generiert |
| **Home Assistant DB** | Zu groß, sensibel |
| **Pi-hole Logs** | Temporär |

### Git-Workflow

```bash
# Täglicher Workflow
cd /home/steges

# 1. Status checken
git status

# 2. Neue/änderte Dateien adden
git add docs/infrastructure/backup-strategy.md
git add agent/skills/openclaw-rag/

# 3. Commit mit Message
git commit -m "feat: add backup strategy docs

- GitHub + USB dual backup
- Daily automated sync
- Recovery procedures"

# 4. Push zu GitHub
git push origin main

# 5. Verify
git log --oneline -5
```

### .gitignore

```gitignore
# Secrets
.env
*.env
secrets.yaml
**/secrets/
**/*.key
**/*.pem

# Datenbanken (zu groß, binär)
*.db
*.sqlite
*.sqlite3
infra/openclaw-data/memory/
pihole/etc-pihole/*.db
homeassistant/home-assistant_v2.db

# Logs
*.log
logs/
log/

# Docker
.docker/

# Temporäre Dateien
tmp/
temp/
*.tmp

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
```

---

## USB-Stick Backup

### Hardware

| Parameter | Wert |
|-----------|------|
| **Gerät** | USB-Stick (z.B. SanDisk Ultra) |
| **Kapazität** | 128GB oder 256GB |
| **Mount-Point** | `/mnt/usb-backup/` |
| **Filesystem** | ext4 (empfohlen) oder exFAT |
| **Automount** | systemd oder /etc/fstab |

### Mount-Konfiguration

```bash
# /etc/fstab Eintrag
UUID=1234-5678 /mnt/usb-backup ext4 defaults,noatime,nofail 0 0
```

ODER systemd-Automount:

```ini
# /etc/systemd/system/mnt-usb\x2dbackup.mount
[Unit]
Description=USB Backup Stick

[Mount]
What=/dev/disk/by-uuid/1234-5678
Where=/mnt/usb-backup
Type=ext4
Options=defaults,noatime

[Install]
WantedBy=multi-user.target
```

### Was wird auf USB gesichert?

| Kategorie | Pfad | Größe | Grund |
|-----------|------|-------|-------|
| **OpenClaw Memory** | `infra/openclaw-data/memory/` | ~100MB | Langzeit-Gedächtnis |
| **Pi-hole DB** | `pihole/etc-pihole/*.db` | ~50MB | DNS-History |
| **Home Assistant DB** | `homeassistant/*.db` | ~200MB | Smart Home History |
| **Grafana DB** | `grafana/grafana.db` | ~10MB | Dashboards |
| **InfluxDB** | `influxdb/` | ~500MB | Time-Series |
| **Vaultwarden** | `vaultwarden/` | ~5MB | Passwörter |
| **.env Dateien** | `~/`, `infra/`, etc. | ~5KB | Secrets |
| **SSH Keys** | `~/.ssh/` | ~10KB | Backup |
| **Git-Config** | `~/.gitconfig` | ~1KB | Einstellungen |
| **Docker Volumes** | `/var/lib/docker/volumes/` | variabel | Falls restore nötig |

### Was NICHT auf USB?

| Typ | Grund |
|-----|-------|
| **Skills** | Sind auf GitHub |
| **Scripts** | Sind auf GitHub |
| **Configs** | Sind auf GitHub |
| **Docs** | Sind auf GitHub |
| **Container Images** | Können neu gepullt werden |

---

## Automatisierung

### backup-daily.sh

```bash
#!/bin/bash
# /home/steges/scripts/backup-daily.sh

set -euo pipefail

LOG_FILE="/var/log/backup-daily.log"
USB_MOUNT="/mnt/usb-backup"
DATE=$(date +%Y%m%d)

echo "[$(date)] Starting daily backup..." >> "$LOG_FILE"

# Check if USB mounted
if ! mountpoint -q "$USB_MOUNT"; then
    echo "[$(date)] ERROR: USB not mounted at $USB_MOUNT" >> "$LOG_FILE"
    # Try to mount
    mount "$USB_MOUNT" 2>/dev/null || {
        /home/steges/scripts/claw-send.sh "USB Backup failed: not mounted"
        exit 1
    }
fi

# Create dated backup dir
BACKUP_DIR="$USB_MOUNT/backups/$DATE"
mkdir -p "$BACKUP_DIR"

# 1. OpenClaw Memory
rsync -av --delete \
    /home/steges/infra/openclaw-data/memory/ \
    "$BACKUP_DIR/openclaw-memory/"

# 2. Pi-hole
rsync -av --delete \
    /home/steges/pihole/etc-pihole/*.db \
    "$BACKUP_DIR/pihole/"

# 3. Home Assistant
rsync -av --delete \
    /home/steges/homeassistant/home-assistant_v2.db \
    "$BACKUP_DIR/homeassistant/"

# 4. Grafana
rsync -av --delete \
    /home/steges/grafana/grafana.db \
    "$BACKUP_DIR/grafana/" 2>/dev/null || true

# 5. Vaultwarden
rsync -av --delete \
    /home/steges/vaultwarden/db.sqlite3 \
    "$BACKUP_DIR/vaultwarden/"

# 6. Secrets
mkdir -p "$BACKUP_DIR/secrets"
cp /home/steges/.env "$BACKUP_DIR/secrets/" 2>/dev/null || true
cp /home/steges/infra/.env "$BACKUP_DIR/secrets/" 2>/dev/null || true
cp /home/steges/homeassistant/secrets.yaml "$BACKUP_DIR/secrets/" 2>/dev/null || true

# 7. SSH Keys
cp -r /home/steges/.ssh "$BACKUP_DIR/ssh/"

# 8. Git Config
cp /home/steges/.gitconfig "$BACKUP_DIR/"

# Cleanup old backups (keep 14 days)
find "$USB_MOUNT/backups/" -type d -name "20*" -mtime +14 -exec rm -rf {} \; 2>/dev/null || true

# Sync filesystem
sync

# Notify
echo "[$(date)] Backup completed: $BACKUP_DIR" >> "$LOG_FILE"
/home/steges/scripts/claw-send.sh "Daily backup completed: $DATE"

# Unmount (optional - safer)
# umount "$USB_MOUNT"
```

### Automatisierung via systemd

```ini
# /home/steges/systemd/backup-daily.service
[Unit]
Description=Daily USB Backup
Requires=mnt-usb\x2dbackup.mount
After=mnt-usb\x2dbackup.mount

[Service]
Type=oneshot
ExecStart=/home/steges/scripts/backup-daily.sh
User=root

[Install]
WantedBy=multi-user.target
```

```ini
# /home/steges/systemd/backup-daily.timer
[Unit]
Description=Daily backup at 02:00

[Timer]
OnCalendar=02:00
Persistent=true

[Install]
WantedBy=timers.target
```

**Aktivieren:**
```bash
sudo systemctl enable backup-daily.timer
sudo systemctl start backup-daily.timer
```

---

## Wiederherstellung

### Szenario 1: GitHub-Restore

```bash
# Frische Installation oder neuer Pi
sudo apt update && sudo apt install -y git docker docker-compose

# Clone Repository
cd /home
git clone https://github.com/steges/homelab.git steges
cd steges

# Start Services
docker-compose up -d

# USB-Backup mounten und restore
sudo mount /dev/sda1 /mnt/usb-backup
./scripts/restore-from-usb.sh
```

### Szenario 2: USB-Restore

```bash
# /home/steges/scripts/restore-from-usb.sh

USB_MOUNT="/mnt/usb-backup"
LATEST=$(ls -t "$USB_MOUNT/backups/" | head -1)

echo "Restoring from: $LATEST"

# OpenClaw Memory
rsync -av "$USB_MOUNT/backups/$LATEST/openclaw-memory/" \
    /home/steges/infra/openclaw-data/memory/

# Pi-hole
sudo systemctl stop docker-compose@pihole 2>/dev/null || docker stop pihole
rsync -av "$USB_MOUNT/backups/$LATEST/pihole/" \
    /home/steges/pihole/etc-pihole/
docker start pihole

# Home Assistant
rsync -av "$USB_MOUNT/backups/$LATEST/homeassistant/" \
    /home/steges/homeassistant/
docker restart homeassistant

# Secrets
cp "$USB_MOUNT/backups/$LATEST/secrets/.env" /home/steges/ 2>/dev/null || true

# Notify
/home/steges/scripts/claw-send.sh "Restore completed from $LATEST"
```

### Szenario 3: Komplette Katastrophe

```bash
# 1. Neues System aufsetzen (Pi 5, NVMe)
# 2. GitHub clone
git clone https://github.com/steges/homelab.git /home/steges

# 3. Secrets einspielen (von USB oder manuell)
cp /mnt/usb-backup/backups/latest/secrets/.env /home/steges/

# 4. Docker starten
cd /home/steges && docker-compose up -d

# 5. Daten restore
./scripts/restore-from-usb.sh

# 6. Systemd services installieren
./scripts/install-openclaw-autostart.sh

# 7. Verify
./scripts/health-check.sh
```

---

## Backup-Überwachung

### Status-Check

```bash
# GitHub-Status
cd /home/steges && git status

# USB-Status
ls -la /mnt/usb-backup/backups/
df -h /mnt/usb-backup

# Letztes Backup
tail /var/log/backup-daily.log

# Timer-Status
systemctl list-timers backup-daily
```

### Alerts

| Bedingung | Kanal |
|-----------|-------|
| Backup failed | NTFY + Telegram |
| USB not mounted | NTFY |
| Backup older than 48h | Telegram |
| GitHub push failed | NTFY |

---

## Best Practices

### GitHub

- ✅ **Commit early, commit often**
- ✅ **Meaningful commit messages**
- ✅ **Push am Ende des Tages**
- ✅ **README aktuell halten**
- ❌ **Keine Secrets commiten**
- ❌ **Keine großen Binärdateien**

### USB-Stick

- ✅ **Qualitäts-USB (SanDisk, Samsung)**
- ✅ **ext4 Filesystem**
- ✅ **Tägliche automatische Backups**
- ✅ **14 Tage Retention**
- ✅ **Zweiter Stick als Spiegel (optional)**
- ❌ **Kein exFAT (Permissions)**
- ❌ **Nicht dauerhaft eingesteckt lassen**

### Testing

```bash
# Monatlicher Restore-Test
# 1. Test-VM oder separater Pi
# 2. GitHub clone
# 3. USB restore
# 4. Verify alle Services laufen

./scripts/test-restore.sh /mnt/usb-test/
```

---

## Referenzen

- `scripts/backup-daily.sh` – Automatisierung
- `scripts/restore-from-usb.sh` – Wiederherstellung
- `systemd/backup-daily.*` – systemd Timer
- GitHub: https://github.com/steges/homelab
