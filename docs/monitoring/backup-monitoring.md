# Backup Monitoring

> Monitoring und Alerting für das Backup-System  
> Checks, Alerts, Dashboards

---

## Überblick

### Was wird überwacht?

| Komponente | Metrik | Frequenz | Alert |
|------------|--------|----------|-------|
| USB-Backup | Letztes Backup | Täglich | >24h = Warning, >48h = Critical |
| GitHub-Backup | Letzter Push | Täglich | >24h = Warning |
| USB-Platz | % belegt | Stündlich | >80% = Warning, >95% = Critical |
| Backup-Dauer | Zeit in Sekunden | Pro Backup | >300s = Info |
| Verifikation | Letzter Check | Wöchentlich | FAILED = Critical |

---

## Health Checks

### Check-Script

```bash
#!/bin/bash
# /home/steges/scripts/check-backup.sh

STATE_FILE="/home/steges/agent/skills/backup-automation/.state/last-backup.json"
USB_MOUNT="/mnt/usb-backup"

ERRORS=0

# 1. Backup-Status prüfen
if [[ -f "$STATE_FILE" ]]; then
    last_backup=$(jq -r '.timestamp' "$STATE_FILE")
    last_epoch=$(date -d "$last_backup" +%s)
    now_epoch=$(date +%s)
    hours_since=$(( (now_epoch - last_epoch) / 3600 ))
    
    if [[ $hours_since -gt 48 ]]; then
        echo "❌ CRITICAL: Backup >48h old ($hours_since hours)"
        ((ERRORS++))
    elif [[ $hours_since -gt 24 ]]; then
        echo "⚠️ WARNING: Backup >24h old ($hours_since hours)"
    else
        echo "✅ Backup: ${hours_since}h ago"
    fi
else
    echo "❌ CRITICAL: No backup state file"
    ((ERRORS++))
fi

# 2. USB-Status
if ! mountpoint -q "$USB_MOUNT"; then
    echo "❌ CRITICAL: USB not mounted"
    ((ERRORS++))
else
    used=$(df "$USB_MOUNT" | tail -1 | awk '{print $5}' | tr -d '%')
    if [[ $used -gt 95 ]]; then
        echo "❌ CRITICAL: USB ${used}% full"
        ((ERRORS++))
    elif [[ $used -gt 80 ]]; then
        echo "⚠️ WARNING: USB ${used}% full"
    else
        echo "✅ USB: ${used}% used"
    fi
fi

# 3. GitHub-Status
cd /home/steges
if git rev-parse --git-dir >/dev/null 2>&1; then
    if [[ -n $(git status --porcelain) ]]; then
        echo "⚠️ WARNING: Uncommitted changes"
    else
        echo "✅ GitHub: clean"
    fi
else
    echo "❌ CRITICAL: Not a git repo"
    ((ERRORS++))
fi

exit $ERRORS
```

### Cron-Integration

```bash
# /etc/crontab oder crontab -e
0 8 * * * /home/steges/scripts/check-backup.sh || \
    /home/steges/scripts/notify-backup-failed.sh
```

---

## Alerting

### OpenClaw Notification

```bash
#!/bin/bash
# notify-backup-failed.sh

MESSAGE="🚨 Backup Check Failed

$(/home/steges/scripts/check-backup.sh 2>&1)

Timestamp: $(date)
Host: $(hostname)
"

/home/steges/scripts/claw-send.sh "$MESSAGE"
```

### NTFY (Push Notifications)

```bash
# In backup-full.sh:
if [[ $backup_success == "false" ]]; then
    curl -d "Backup failed on $(hostname)" \
         ntfy.sh/your-topic
fi
```

### Telegram (Optional)

```bash
# Bot-Message
TELEGRAM_BOT_TOKEN="your-token"
TELEGRAM_CHAT_ID="your-chat-id"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=🚨 Backup failed on $(hostname)"
```

---

## Prometheus Metrics

### Node Exporter Textfile

```bash
#!/bin/bash
# /home/steges/scripts/backup-metrics.sh

TEXTFILE_DIR="/var/lib/node_exporter/textfile_collector"
STATE_FILE="/home/steges/agent/skills/backup-automation/.state/last-backup.json"

# Last backup timestamp
if [[ -f "$STATE_FILE" ]]; then
    last_backup=$(jq -r '.timestamp' "$STATE_FILE")
    last_epoch=$(date -d "$last_backup" +%s)
    
    cat << EOF > "$TEXTFILE_DIR/backup.prom.$$"
# HELP backup_last_success Unix timestamp of last successful backup
# TYPE backup_last_success gauge
backup_last_success $last_epoch

# HELP backup_success 1 if last backup succeeded, 0 otherwise
# TYPE backup_success gauge
backup_success $(jq -r '.success // 0' "$STATE_FILE" | sed 's/true/1/;s/false/0/')
EOF
    
    mv "$TEXTFILE_DIR/backup.prom.$$" "$TEXTFILE_DIR/backup.prom"
fi

# USB usage
if mountpoint -q /mnt/usb-backup; then
    usage=$(df /mnt/usb-backup | tail -1 | awk '{print $5}' | tr -d '%')
    
    cat << EOF >> "$TEXTFILE_DIR/backup.prom.$$"
# HELP backup_usb_usage_percent USB backup disk usage
# TYPE backup_usb_usage_percent gauge
backup_usb_usage_percent $usage
EOF
fi
```

### Prometheus Alert Rules

```yaml
# /home/steges/monitoring/alert-rules/backup.yml
groups:
  - name: backup
    rules:
      - alert: BackupTooOld
        expr: (time() - backup_last_success) > 86400 * 2
        for: 1h
        labels:
          severity: critical
        annotations:
          summary: "Backup is more than 2 days old"
          description: "Last backup was {{ $value | humanizeDuration }} ago"

      - alert: BackupFailed
        expr: backup_success == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Last backup failed"

      - alert: USBDiskFull
        expr: backup_usb_usage_percent > 90
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "USB backup disk is {{ $value }}% full"
```

---

## Grafana Dashboard

### Panel: Backup Status

```json
{
  "title": "Backup Status",
  "type": "stat",
  "targets": [
    {
      "expr": "backup_success",
      "legendFormat": "Success"
    }
  ],
  "thresholds": {
    "steps": [
      {"color": "red", "value": 0},
      {"color": "green", "value": 1}
    ]
  }
}
```

### Panel: Time Since Last Backup

```json
{
  "title": "Time Since Backup",
  "type": "stat",
  "targets": [
    {
      "expr": "(time() - backup_last_success) / 3600",
      "legendFormat": "Hours"
    }
  ],
  "thresholds": {
    "steps": [
      {"color": "green", "value": 0},
      {"color": "yellow", "value": 24},
      {"color": "red", "value": 48}
    ]
  },
  "unit": "h"
}
```

### Panel: USB Disk Usage

```json
{
  "title": "USB Disk Usage",
  "type": "gauge",
  "targets": [
    {
      "expr": "backup_usb_usage_percent",
      "legendFormat": "Usage %"
    }
  ],
  "fieldConfig": {
    "max": 100,
    "thresholds": {
      "steps": [
        {"color": "green", "value": 0},
        {"color": "yellow", "value": 80},
        {"color": "red", "value": 95}
      ]
    }
  }
}
```

---

## Uptime Kuma

### Checks hinzufügen

```bash
# 1. Backup Script läuft?
# Type: Push
# Push URL: https://uptime.yourdomain.com/api/push/xxxx

# In backup-full.sh:
if [[ $success == true ]]; then
    curl -fsS -m 10 --retry 5 \
        "https://uptime.yourdomain.com/api/push/xxxx?status=up&msg=OK&ping=123"
else
    curl -fsS -m 10 --retry 5 \
        "https://uptime.yourdomain.com/api/push/xxxx?status=down&msg=Failed"
fi
```

### USB Mount Check

```bash
# Type: HTTP(s)
# URL: http://localhost:9090/metrics (Node Exporter)
# Keyword: backup_usb_usage_percent
```

---

## Log-Monitoring

### Loki Query

```logql
# Backup-Logs
{job="backup"} |= "backup-full.sh"

# Errors only
{job="backup"} |= "ERROR"

# Success
{job="backup"} |= "successful"
```

### Promtail Config

```yaml
# promtail-config.yml
scrape_configs:
  - job_name: backup
    static_configs:
      - targets:
          - localhost
        labels:
          job: backup
          __path__: /var/log/backup-automation.log
```

---

## Health Dashboard

### CLI Dashboard

```bash
#!/bin/bash
# backup-dashboard.sh

clear
echo "╔════════════════════════════════════════════════════╗"
echo "║         BACKUP MONITORING DASHBOARD                ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║                                                    ║"

# USB Status
if mountpoint -q /mnt/usb-backup; then
    usage=$(df -h /mnt/usb-backup | tail -1 | awk '{print $5}')
    echo "║  USB:    ✅ Mounted ($usage)                       ║"
else
    echo "║  USB:    ❌ NOT MOUNTED                            ║"
fi

# Last Backup
STATE_FILE="/home/steges/agent/skills/backup-automation/.state/last-backup.json"
if [[ -f "$STATE_FILE" ]]; then
    last=$(jq -r '.timestamp' "$STATE_FILE")
    success=$(jq -r '.success' "$STATE_FILE")
    if [[ "$success" == "true" ]]; then
        echo "║  Last:   ✅ $last                      ║"
    else
        echo "║  Last:   ❌ Failed                                 ║"
    fi
else
    echo "║  Last:   ❌ No state file                          ║"
fi

# GitHub
cd /home/steges
if [[ -z $(git status --porcelain) ]]; then
    echo "║  GitHub: ✅ Clean                                  ║"
else
    echo "║  GitHub: ⚠️  Uncommitted                           ║"
fi

echo "║                                                    ║"
echo "╚════════════════════════════════════════════════════╝"
```

---

## Troubleshooting Monitoring

### Keine Metriken?

```bash
# Node Exporter läuft?
systemctl status node_exporter

# Textfile-Collector existiert?
ls -la /var/lib/node_exporter/textfile_collector/

# Prometheus scraping?
curl -s localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job == "node")'
```

### Keine Alerts?

```bash
# Alertmanager läuft?
systemctl status alertmanager

# Rules geladen?
prometheus-tool promtool check rules /path/to/rules.yml

# Alerts firing?
curl -s localhost:9090/api/v1/alerts | jq '.data.alerts'
```

---

## Verweise

- `docs/monitoring/time-series-baseline.md` – Prometheus/Loki Setup
- `docs/infrastructure/backup-automation-skill.md` – Backup-Skill
- `docs/runbooks/backup-failure-recovery.md` – Recovery
