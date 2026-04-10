# Scripts-Referenz – Alle Automatisierungen

> Vollständige Übersicht aller Scripts in `/home/steges/scripts/`  
> Stand: April 2026

---

## Übersicht

| Kategorie | Anzahl | Verzeichnis |
|-----------|--------|-------------|
| **Backup** | 2 | `backup.sh`, `sync-offsite.sh` |
| **OpenClaw** | 4 | `claw-send.sh`, `openclaw-config-guard.sh`, `install-openclaw-autostart.sh`, `rag-quality-report.sh` |
| **Health** | 3 | `health-check.sh`, `canvas-drift-check.sh`, `auth-failure-monitor.sh` |
| **Maintenance** | 4 | `update-stacks.sh`, `lint-shell.sh`, `canvas-ops-brief.sh`, `canvas-playwright-smoke.sh` |
| **Utility** | ~10 | Verschiedene Helper |

---

## Backup & Sync

### backup.sh

**Zweck:** Lokales Backup aller wichtigen Daten

| Parameter | Wert |
|-----------|------|
| **Ziel** | `/mnt/backup/` oder externe USB |
| **Frequenz** | Täglich (cron) |
| **Retention** | 7 Tage lokal |

**Backup-Set:**
- `agent/` – Workspace, Skills, Configs
- `infra/` – OpenClaw Data, Memory
- `systemd/` – Service-Dateien
- `scripts/` – Alle Scripts
- `docker-compose.yml` – Stack-Definition
- `caddy/Caddyfile` – Reverse-Proxy-Config
- `pihole/` – DNS-Config (ohne Logs)
- `homeassistant/` – Smart-Home-Config

```bash
#!/bin/bash
# /home/steges/scripts/backup.sh (Auszug)

BACKUP_DIR="/mnt/backup/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Agent-Daten
rsync -av --exclude='node_modules' \
  /home/steges/agent/ "$BACKUP_DIR/agent/"

# OpenClaw
rsync -av \
  /home/steges/infra/openclaw-data/ "$BACKUP_DIR/openclaw/"

# Systemd
rsync -av \
  /home/steges/systemd/ "$BACKUP_DIR/systemd/"

# Cleanup (älter als 7 Tage)
find /mnt/backup -type d -mtime +7 -exec rm -rf {} \;
```

**Restore:**
```bash
# Einzelnes Backup
cd /mnt/backup/20260410
sudo rsync -av agent/ /home/steges/agent/
sudo systemctl restart homelab
```

---

### sync-offsite.sh

**Zweck:** Cloud-Backup zu Backblaze B2

| Parameter | Wert |
|-----------|------|
| **Ziel** | Backblaze B2 Bucket |
| **Tool** | restic |
| **Frequenz** | Wöchentlich |
| **Retention** | 30 Tage, 12 Monate |

---

## OpenClaw Management

### claw-send.sh

**Zweck:** Nachricht an OpenClaw senden (Wrapper)

```bash
#!/bin/bash
# Usage: ./claw-send.sh "Nachricht" [--session name]

MESSAGE="${1:-Status check}"
SESSION="${2:-main}"

docker exec openclaw openclaw agent \
  --message "$MESSAGE" \
  --session "$SESSION" \
  --json
```

**Verwendung:**
```bash
# Einfach
./claw-send.sh "Backup complete"

# Mit Session
./claw-send.sh "Deploy successful" "deployment"

# Von anderem Script
/home/steges/scripts/claw-send.sh "Growbox alert: $ALERT_MSG"
```

---

### openclaw-config-guard.sh

**Zweck:** Config-Änderungen überwachen

| Check | Aktion |
|-------|--------|
| Syntax-Fehler | Alert + Rollback |
| Pfad-Änderung | Warnung |
| Secrets im Klartext | Block + Alert |
| Backup vor Änderung | Automatisch |

```bash
# Wird vor config-Änderung ausgeführt
./openclaw-config-guard.sh validate /tmp/new-config.json

# Bei Fehler: Rollback auf letzte funktionierende Config
```

---

### install-openclaw-autostart.sh

**Zweck:** OpenClaw systemd-Services installieren

```bash
#!/bin/bash
# 1. Symlinks erstellen
# 2. systemctl daemon-reload
# 3. Services enablen
# 4. Timer starten

SERVICES=(
  "homelab.service"
  "openclaw-compose.service"
  "openclaw-heartbeat.timer"
  "nightly-self-check.timer"
  "rag-reindex-daily.timer"
)

for svc in "${SERVICES[@]}"; do
  sudo ln -sf "/home/steges/systemd/$svc" "/etc/systemd/system/"
done

sudo systemctl daemon-reload
sudo systemctl enable homelab.service openclaw-compose.service
sudo systemctl enable openclaw-heartbeat.timer nightly-self-check.timer
sudo systemctl start openclaw-heartbeat.timer nightly-self-check.timer
```

---

### rag-quality-report.sh

**Zweck:** RAG-Index-Qualität prüfen

**Metriken:**
- Dokumenten-Anzahl
- Chunk-Größen
- Embedding-Qualität
- Query-Latenz
- Retrieval-Accuracy

**Output:**
```json
{
  "timestamp": "2026-04-10T02:00:00Z",
  "total_docs": 150,
  "total_chunks": 3200,
  "avg_chunk_size": 512,
  "query_latency_ms": 45,
  "retrieval_accuracy": 0.94,
  "status": "healthy"
}
```

---

## Health Checks

### health-check.sh

**Zweck:** Kompletter System-Check

**Checks:**
1. **Load:** `< 8.0` (für Pi 5 8GB)
2. **Memory:** `< 90%`
3. **Disk:** `< 80%`
4. **Docker:** Alle Container `Up`
5. **Services:** `homelab`, `openclaw`
6. **Network:** Gateway erreichbar
7. **NVMe:** SMART `PASSED`
8. **RAG:** Index erreichbar

**Exit Codes:**
- `0` – Alles OK
- `1` – Warning
- `2` – Critical

---

### canvas-drift-check.sh

**Zweck:** Canvas-UI Konsistenz prüfen

**Checks:**
- State-Dateien vorhanden
- JSON-Validität
- Zeitstempel (nicht älter als 1h)
- Sync mit Agent

---

### auth-failure-monitor.sh

**Zweck:** SSH-Brute-Force erkennen

| Threshold | Aktion |
|-----------|--------|
| 5 Failures/1min | Log + Alert |
| 10 Failures/5min | NTFY Push |
| 20 Failures/10min | Temp-IP-Block (via UFW) |

---

## Maintenance

### update-stacks.sh

**Zweck:** Docker-Images aktualisieren

```bash
#!/bin/bash
# 1. Backup
/home/steges/scripts/backup.sh

# 2. Pull neue Images
cd /home/steges
docker-compose pull

# 3. Rolling Update (ein Service nach dem anderen)
for service in caddy pihole openclaw; do
  docker-compose up -d $service
  sleep 10
  docker-compose ps | grep $service | grep -q "Up" || exit 1
done

# 4. Cleanup
docker system prune -f

# 5. Notify
/home/steges/scripts/claw-send.sh "Stack update complete"
```

---

### lint-shell.sh

**Zweck:** Shell-Script Qualitäts-Check

**Tools:**
- `shellcheck` – Static Analysis
- `shfmt` – Formatting
- `checkbashisms` – POSIX-Compliance

**Usage:**
```bash
# Einzelnes Script
./lint-shell.sh my-script.sh

# Alle Scripts
./lint-shell.sh /home/steges/scripts/

# CI-Mode (exit 1 bei Fehler)
./lint-shell.sh --ci /home/steges/scripts/
```

---

### canvas-ops-brief.sh

**Zweck:** Operations-Übersicht für Canvas-UI generieren

**Output:** `ops-brief.latest.json`

```json
{
  "timestamp": "2026-04-10T02:00:00Z",
  "system": {
    "status": "healthy",
    "load": 0.8,
    "memory": "45%",
    "disk": "38%"
  },
  "docker": {
    "running": 15,
    "exited": 0,
    "images": 42
  },
  "alerts": [],
  "recent_actions": [
    {"time": "01:00", "action": "nightly-self-check", "status": "ok"}
  ]
}
```

---

### canvas-playwright-smoke.sh

**Zweck:** Canvas-UI End-to-End Test

**Framework:** Playwright

**Tests:**
1. UI lädt
2. Agent-Status verfügbar
3. Nachricht senden
4. Antwort empfangen
5. State korrekt

---

## Utility Scripts

### tmux-session.sh

**Zweck:** Standardisierte tmux-Sessions

```bash
# Entwicklung
./tmux-session.sh dev
# - Fenster 1: Editor
# - Fenster 2: Terminal
# - Fenster 3: Logs

# Monitoring
./tmux-session.sh monitor
# - Fenster 1: htop
# - Fenster 2: docker stats
# - Fenster 3: journalctl -f
```

---

### log-viewer.sh

**Zweck:** Zentraler Log-Viewer

```bash
# Alles
./log-viewer.sh all

# Nur OpenClaw
./log-viewer.sh openclaw

# Letzte 100 Zeilen
./log-viewer.sh openclaw -n 100

# Mit Filter
./log-viewer.sh all -f "error"

# Loki-Query
./log-viewer.sh query '{container_name="openclaw"} |= "error"'
```

---

### port-check.sh

**Zweck:** Port-Verfügbarkeit testen

```bash
# Lokal
./port-check.sh 18789

# Remote
./port-check.sh 192.168.2.101 80

# Alle OpenClaw-Ports
./port-check.sh --all
```

---

### cert-check.sh

**Zweck:** SSL-Zertifikat-Expiry prüfen

```bash
# Einzelnes Zert
./cert-check.sh steges.duckdns.org

# Alle (von Caddy)
./cert-check.sh --all

# Mit Alert
./cert-check.sh --alert-if-days-left 30
```

---

### network-test.sh

**Zweck:** Netzwerk-Diagnose

```bash
# Full test
./network-test.sh

Tests:
- DNS (Pi-hole)
- Gateway (192.168.2.1)
- Internet (8.8.8.8)
- External IP
- Latenz zu wichtigen Services
```

---

## Script-Standards

### Template

```bash
#!/bin/bash
# Script: [name]
# Purpose: [Beschreibung]
# Author: steges
# Date: 2026-04-10
# Version: 1.0

set -euo pipefail  # Strict mode

# Config
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/$(basename "$0" .sh).log"

# Functions
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
  log "ERROR: $*" >&2
  exit 1
}

main() {
  log "Starting..."
  
  # Script logic here
  
  log "Completed successfully"
}

main "$@"
```

### Conventions

| Regel | Beispiel |
|-------|----------|
| Shebang | `#!/bin/bash` oder `#!/usr/bin/env bash` |
| Strict Mode | `set -euo pipefail` |
| Readonly Vars | `readonly VAR="value"` |
| Functions | `lower_snake_case()` |
| Logging | Zentral, mit Timestamp |
| Exit Codes | 0=OK, 1=Warning, 2=Error |

---

## Automation

### Cron-Integration

```bash
# crontab -l

# Backup täglich 2:00
0 2 * * * /home/steges/scripts/backup.sh >> /var/log/backup.log 2>&1

# Health-Check alle 5 Minuten
*/5 * * * * /home/steges/scripts/health-check.sh || /home/steges/scripts/claw-send.sh "Health check failed"

# Weekly Update (Sonntag 4:00)
0 4 * * 0 /home/steges/scripts/update-stacks.sh
```

### systemd-Integration

Die meisten Scripts werden über systemd Timer/Service aufgerufen:
- `nightly-self-check.service` → `runbook-maintenance-dispatch.sh`
- `rag-reindex-daily.service` → `reindex.sh`
- `openclaw-heartbeat.service` → `heartbeat-dispatch.sh`

---

## Troubleshooting

### Script finden

```bash
# Alle Scripts listen
ls -la /home/steges/scripts/

# Mit Beschreibung
grep -h "# Purpose" /home/steges/scripts/*.sh | sort
```

### Debug-Modus

```bash
# Bash-Debug
bash -x /home/steges/scripts/backup.sh

# Script-internes Debug
DEBUG=1 /home/steges/scripts/health-check.sh
```

### Logs

```bash
# System-Log
sudo journalctl -t backup

# Script-Log
cat /var/log/backup.sh.log

# Realtime
tail -f /var/log/*.log
```

---

## Referenzen

- `/home/steges/scripts/` – Alle Scripts
- `systemd/` – Service-Integration
- `agent/skills/*/scripts/` – Skill-Scripts
