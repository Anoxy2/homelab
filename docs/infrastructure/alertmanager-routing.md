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

### alertmanager.yml

```yaml
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alertmanager@localhost'
  smtp_auth_username: ''
  smtp_auth_password: ''
  
  # ntfy webhook defaults
  http_config:
    timeout: 10s

templates:
- '/etc/alertmanager/template/*.tmpl'

# Routing tree
route:
  group_by: ['alertname', 'severity', 'instance']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'ntfy-default'
  
  routes:
    # Critical alerts: immediate
    - match:
        severity: critical
      receiver: ntfy-critical
      group_wait: 10s
      repeat_interval: 30m
      continue: true
      
    # Warning alerts: batched
    - match:
        severity: warning
      receiver: ntfy-warning
      group_wait: 5m
      repeat_interval: 2h
      
    # System alerts: separate channel
    - match:
        job: node-exporter
      receiver: ntfy-system
      group_by: ['alertname']

# Receivers
receivers:
  - name: 'ntfy-default'
    webhook_configs:
      - url: 'http://192.168.2.101:8900/alerts-default'
        send_resolved: true
        max_alerts: 5
        
  - name: 'ntfy-critical'
    webhook_configs:
      - url: 'http://192.168.2.101:8900/alerts-critical'
        send_resolved: true
        http_config:
          headers:
            Priority: '5'
            Tags: 'rotating_light'
            
  - name: 'ntfy-warning'
    webhook_configs:
      - url: 'http://192.168.2.101:8900/alerts-warning'
        send_resolved: true
        http_config:
          headers:
            Priority: '3'
            Tags: 'warning'
            
  - name: 'ntfy-system'
    webhook_configs:
      - url: 'http://192.168.2.101:8900/alerts-system'
        send_resolved: true

# Inhibition: suppress warnings if critical firing
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
    
  # Inhibit info if warning firing
  - source_match:
      severity: 'warning'
    target_match:
      severity: 'info'
    equal: ['alertname']
```

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
