# Alertmanager Alert Routing

> Alert routing, grouping, and notification dispatch
> Routes alerts to ntfy, handles silencing and inhibition

---

## Overview

**Alertmanager** receives alerts from Prometheus and routes them to notification channels.

| Attribute | Value |
|-----------|-------|
| **Image** | `prom/alertmanager:v0.28.1` |
| **Container** | alertmanager |
| **Port** | `192.168.2.101:9093` |
| **Config** | `./alertmanager/config/alertmanager.yml` |
| **Storage** | Alert state, silences |

---

## Architecture

```
Prometheus (firing alerts)
    ↓
Alertmanager (:9093)
    │
    ├──→ Grouping by label
    ├──→ Routing by severity
    └──→ Notification
            │
            ├──→ ntfy (push)
            └──→ (webhook extensible)
```

---

## Configuration

### Docker Compose

```yaml
services:
  alertmanager:
    image: prom/alertmanager:v0.28.1
    container_name: alertmanager
    ports:
      - "192.168.2.101:9093:9093"
    volumes:
      - ./alertmanager/config/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
    env_file: .env
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=http://alertmanager.lan'
```

### alertmanager.yml (Live-Konfiguration)

```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'instance']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  receiver: 'telegram'
  routes:
    - matchers:
        - severity="critical"
      receiver: 'telegram-and-ntfy'
      continue: false

receivers:
  - name: 'telegram'
    telegram_configs:
      - bot_token: '<TELEGRAM_BOT_TOKEN>'
        chat_id: <TELEGRAM_CHAT_ID>
        parse_mode: HTML
        message: |
          {{ if eq .Status "firing" }}🔴{{ else }}✅{{ end }} <b>{{ .CommonLabels.alertname }}</b>
          {{ range .Alerts }}
          <b>Host:</b> {{ .Labels.instance | default "pilab" }}
          <b>Info:</b> {{ .Annotations.summary }}
          {{ if .Annotations.description }}<b>Detail:</b> {{ .Annotations.description }}{{ end }}
          {{ end }}

  - name: 'telegram-and-ntfy'
    telegram_configs:
      - bot_token: '<TELEGRAM_BOT_TOKEN>'
        chat_id: <TELEGRAM_CHAT_ID>
        parse_mode: HTML
        message: |
          🚨 <b>CRITICAL: {{ .CommonLabels.alertname }}</b>
          {{ range .Alerts }}
          <b>Host:</b> {{ .Labels.instance | default "pilab" }}
          <b>Info:</b> {{ .Annotations.summary }}
          {{ end }}
    webhook_configs:
      - url: 'http://<NTFY_USER>:<NTFY_PASS>@192.168.2.101:8900/alerts?priority=urgent&tags=rotating_light,pilab'
        send_resolved: true

inhibit_rules:
  - source_matchers:
      - severity="critical"
    target_matchers:
      - severity="warning"
    equal: ['alertname', 'instance']
```

### Routing-Logik

| Severity | Empfänger | Kanal |
|----------|-----------|-------|
| `critical` | `telegram-and-ntfy` | Telegram + ntfy (Priority: urgent) |
| alle anderen | `telegram` | Telegram |

### ntfy-Integration

- Empfänger: `telegram-and-ntfy` (nur bei `severity="critical"`)
- ntfy-User: `alertmanager` (nur Schreibzugriff auf Topic `alerts`)
- Credentials: `NTFY_ALERTMANAGER_USER` / `NTFY_ALERTMANAGER_PASSWORD` in `.env`
- Topic: `alerts` — URL: `http://192.168.2.101:8900/alerts`
- Priorität via Query-Parameter: `?priority=urgent&tags=rotating_light,pilab`
- ntfy-Auth konfigurieren: `docker exec ntfy ntfy user list`

---

## Alert Structure

Prometheus sends alerts in this format:

```json
{
  "status": "firing",
  "labels": {
    "alertname": "HighCPUUsage",
    "severity": "warning",
    "instance": "192.168.2.101:9100",
    "job": "node-exporter"
  },
  "annotations": {
    "summary": "High CPU usage on 192.168.2.101:9100",
    "description": "CPU usage is above 80% for 5 minutes"
  },
  "startsAt": "2026-04-10T12:00:00Z",
  "endsAt": "0001-01-01T00:00:00Z"
}
```

---

## Grouping

Alerts with same `group_by` labels are batched:

```yaml
route:
  group_by: ['alertname', 'severity']  # Same alertname + severity = one notification
  group_wait: 30s                      # Wait 30s for more alerts
  group_interval: 5m                   # Re-notify every 5m if still firing
  repeat_interval: 4h                   # Max re-notify every 4h
```

---

## Silencing

Silence alerts via UI or API:

```bash
# Web UI
open http://alertmanager.lan

# API
curl -X POST http://192.168.2.101:9093/api/v2/silences \
  -H 'Content-Type: application/json' \
  -d '{
    "matchers": [
      {"name": "alertname", "value": "HighCPUUsage", "isRegex": false}
    ],
    "startsAt": "2026-04-10T12:00:00Z",
    "endsAt": "2026-04-10T13:00:00Z",
    "createdBy": "steges",
    "comment": "Planned maintenance"
  }'
```

---

## Inhibition

Suppress alerts based on other alerts:

```yaml
inhibit_rules:
  # If NodeDown critical, suppress all NodeDown warnings
  - source_match:
      alertname: 'NodeDown'
      severity: 'critical'
    target_match:
      alertname: 'NodeDown'
      severity: 'warning'
    equal: ['instance']
```

---

## Templates

```yaml
# alertmanager/template/ntfy.tmpl
{{ define "ntfy.title" }}
[{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .GroupLabels.alertname }}
{{ end }}

{{ define "ntfy.message" }}
{{ range .Alerts }}
{{ .Annotations.summary }}
{{ if .Annotations.description }}
{{ .Annotations.description }}
{{ end }}
Instance: {{ .Labels.instance }}
Severity: {{ .Labels.severity }}
Started: {{ .StartsAt.Format "15:04" }}
---
{{ end }}
{{ end }}
```

---

## Troubleshooting

### Alerts not received

```bash
# Check Alertmanager is receiving alerts
curl http://192.168.2.101:9093/api/v2/alerts

# Check routing
curl http://192.168.2.101:9093/api/v2/status

# Test webhook manually
curl -X POST http://192.168.2.101:8900/alerts-test \
  -d 'test alert'
```

### Too many notifications

```yaml
# Increase group_interval and repeat_interval
route:
  group_interval: 15m   # Wait 15m between batched notifications
  repeat_interval: 12h  # Max 2 notifications per 12h per alert group
```

### Routing not working

```bash
# Enable debug logging
docker logs alertmanager --tail 200 | grep routing

# Check config is valid
docker exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
```

---

## API Reference

| Endpoint | Description |
|----------|-------------|
| `GET /api/v2/alerts` | List active alerts |
| `POST /api/v2/silences` | Create silence |
| `GET /api/v2/silences` | List silences |
| `GET /api/v2/status` | Status and config |
| `POST /-/reload` | Reload config |

---

## Backup

```bash
# Alertmanager data (silences, notification log)
docker run --rm -v alertmanager_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/alertmanager-$(date +%Y%m%d).tar.gz -C /data .

# Config is in Git
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Documentation created, v0.28.1 |
