# Systemd Services & Timer

> Alle systemd-Units, Timer und automatisierte Tasks  
> Stand: April 2026

---

## Übersicht

| Service/Timer | Zweck | Status |
|---------------|-------|--------|
| `homelab.service` | Docker Compose Stack starten | enabled |
| `openclaw-compose.service` | OpenClaw Container | enabled |
| `openclaw-heartbeat.service` | RAG Heartbeat (07:00/19:00) | static |
| `chat-bridge.service` | HTTP-Bridge für OpenClaw | enabled |
| `nightly-self-check.service` | System-Check | static |
| `rag-reindex-daily.service` | RAG Reindex | static |

---

## Haupt-Services

### homelab.service

**Zweck:** Startet den gesamten Docker Compose Stack

```ini
# /home/steges/systemd/homelab.service
[Unit]
Description=Homelab Docker Compose Stack
Requires=docker.service
After=docker.service network.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/steges
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

| Parameter | Wert |
|-----------|------|
| **WorkingDir** | `/home/steges` |
| **Start** | `docker-compose up -d` |
| **Stop** | `docker-compose down` |

**Befehle:**
```bash
sudo systemctl status homelab
sudo systemctl restart homelab
sudo journalctl -u homelab -f
```

---

### openclaw-compose.service

**Zweck:** OpenClaw-spezifisches Management

```ini
# /home/steges/systemd/openclaw-compose.service
[Unit]
Description=OpenClaw Docker Compose
Requires=docker.service homelab.service
After=docker.service homelab.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/steges/infra
ExecStart=/usr/bin/docker-compose -f docker-compose.openclaw.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.openclaw.yml down

[Install]
WantedBy=multi-user.target
```

---

### openclaw-heartbeat.service

**Zweck:** Wird von Timer getriggert, sendet Heartbeat an Agent

```ini
# /home/steges/systemd/openclaw-heartbeat.service
[Unit]
Description=OpenClaw Heartbeat Dispatch
After=docker.service

[Service]
Type=oneshot
ExecStart=/home/steges/agent/skills/heartbeat/scripts/heartbeat-dispatch.sh
User=steges
Group=steges
```

**Script:** `heartbeat-dispatch.sh`
```bash
#!/bin/bash
# Sendet Heartbeat-Ping an OpenClaw

docker exec openclaw openclaw agent \
  --message "Heartbeat ping at $(date)" \
  --session heartbeat \
  --json >> /home/steges/logs/heartbeat.log 2>&1
```

---

### chat-bridge.service

**Zweck:** HTTP-Bridge für Canvas-UI → OpenClaw

```ini
# /home/steges/systemd/chat-bridge.service
[Unit]
Description=OpenClaw Chat Bridge
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/steges/scripts
ExecStart=/usr/bin/python3 /home/steges/scripts/chat-bridge.py
Restart=always
RestartSec=5
User=steges

[Install]
WantedBy=multi-user.target
```

| Parameter | Wert |
|-----------|------|
| **Port** | 127.0.0.1:18792 |
| **Protocol** | HTTP → WebSocket Bridge |
| **Purpose** | Canvas UI Kommunikation |

---

## Timer (Cron-Ersatz)

### openclaw-heartbeat.timer

```ini
# /home/steges/systemd/openclaw-heartbeat.timer
[Unit]
Description=Twice daily heartbeat for OpenClaw

[Timer]
OnCalendar=07:00
OnCalendar=19:00
Persistent=true

[Install]
WantedBy=timers.target
```

**Schedule:** 07:00 und 19:00 täglich

---

### nightly-self-check.timer

```ini
# /home/steges/systemd/nightly-self-check.timer
[Unit]
Description=Nightly system self-check

[Timer]
OnCalendar=03:00
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
```

**Zweck:** Führt `nightly-self-check.service` aus

**Script:**
```bash
#!/bin/bash
# /home/steges/agent/skills/runbook-maintenance/scripts/runbook-maintenance-dispatch.sh

echo "[$(date)] Starting nightly self-check..."

# 1. Disk-Check
df -h / | tail -1 | awk '{if($5+0 > 80) print "WARNING: Disk > 80%"}'

# 2. NVMe-Check
sudo smartctl -H /dev/nvme0

# 3. Docker-Check
docker ps --filter "status=exited" --format "{{.Names}}"

# 4. Memory-Check
free -m | awk '/Mem:/ {if($3/$2 > 0.9) print "WARNING: Memory > 90%"}'

# 5. RAG-Quality-Check
/home/steges/scripts/rag-quality-report.sh

echo "[$(date)] Self-check complete"
```

---

### rag-reindex-daily.timer

```ini
# /home/steges/systemd/rag-reindex-daily.timer
[Unit]
Description=Daily RAG reindex

[Timer]
OnCalendar=02:00
RandomizedDelaySec=600
Persistent=true

[Install]
WantedBy=timers.target
```

**Zweck:** Aktualisiert RAG-Index

---

## Timer-Status

```bash
$ systemctl list-timers --all
NEXT                         LEFT          LAST                         PASSED      UNIT                         ACTIVATES
Fri 2026-04-10 07:00:00 CEST 4h 41min left Thu 2026-04-09 19:00:02 CEST 7h ago      openclaw-heartbeat.timer       openclaw-heartbeat.service
Fri 2026-04-10 02:00:00 CEST 13min left    Thu 2026-04-09 02:00:12 CEST 24h ago     rag-reindex-daily.timer        rag-reindex-daily.service
Fri 2026-04-10 03:05:00 CEST 1h 6min left  Thu 2026-04-09 03:00:45 CEST 23h ago     nightly-self-check.timer       nightly-self-check.service
```

---

## Installation

### Service aktivieren

```bash
# 1. Symlink erstellen
sudo ln -s /home/steges/systemd/homelab.service /etc/systemd/system/

# 2. Reload	sudo systemctl daemon-reload

# 3. Enable
sudo systemctl enable homelab.service

# 4. Starten
sudo systemctl start homelab.service
```

### Alle Services auf einmal

```bash
# setup-all-services.sh
cd /home/steges/systemd
for service in *.service; do
    sudo ln -sf "$(pwd)/$service" /etc/systemd/system/
done
for timer in *.timer; do
    sudo ln -sf "$(pwd)/$timer" /etc/systemd/system/
done
sudo systemctl daemon-reload
sudo systemctl enable openclaw-heartbeat.timer nightly-self-check.timer rag-reindex-daily.timer
sudo systemctl start openclaw-heartbeat.timer nightly-self-check.timer rag-reindex-daily.timer
```

---

## Log-Management

### Journal-Größe

```bash
$ journalctl --disk-usage
Archived and active journals take up 78.1M in the file system.
```

### Limits (/etc/systemd/journald.conf)

```ini
[Journal]
SystemMaxUse=500M
SystemMaxFileSize=100M
MaxRetentionSec=1month
```

---

## Wartung

### Service-Status checken

```bash
# Alle
systemctl list-units --type=service --state=failed

# Einzeln
systemctl status openclaw-heartbeat.timer
systemctl status homelab
```

### Logs ansehen

```bash
# Realtime
journalctl -u homelab -f

# Letzte Stunde
journalctl -u openclaw-heartbeat --since "1 hour ago"

# Alle Services
journalctl -u "*openclaw*" --since today
```

### Troubleshooting

```bash
# Service startet nicht
sudo systemctl restart homelab
sudo journalctl -u homelab -n 50

# Docker-Probleme
sudo docker-compose logs

# Timer nicht gelaufen
systemctl list-timers --failed
```

---

## Vergleich: Cron vs Systemd Timer

| Feature | Cron | Systemd Timer |
|---------|------|---------------|
| Logging | Limited | Journald (vollständig) |
| Dependencies | Manual | Native (After=, Requires=) |
| On-Failure | No | Restart-Policy |
| Randomized Delay | No | RandomizedDelaySec |
| Persistent | No | Persistent=true |
| Resource-Limits | No | CPU/Memory limits |

---

## Referenzen

- `systemd/` – Alle Service-Dateien
- `scripts/install-openclaw-autostart.sh` – Installation
- `agent/skills/runbook-maintenance/` – Maintenance-Logic
