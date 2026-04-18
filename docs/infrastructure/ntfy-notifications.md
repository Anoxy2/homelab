# ntfy Push Notifications

> Selbstgehosteter Push-Notification-Service
> HTTP-basiert, kein Google/Apple-Push nötig

---

## Überblick

**ntfy** sendet Push-Notifications an Browser und Mobile Apps – komplett selbstgehostet, keine externe Infrastruktur.

| Attribut | Wert |
|----------|------|
| **Image** | `binwiederhier/ntfy:v2.13.0` |
| **Container** | ntfy |
| **Port** | `192.168.2.101:8900` → Container `80` |
| **LAN URL** | `http://ntfy.lan` |
| **Config** | `./ntfy/server.yml` |
| **Speicher** | SQLite + Cache |

---

## Architektur

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Script    │────→│    ntfy     │────→│  Browser/   │
│   (curl)    │     │   Server    │     │  Mobile App │
└─────────────┘     └─────────────┘     └─────────────┘
        │
        ↓
┌─────────────┐
│  WebSocket  │ ←── Echtzeit-Updates
│  (Subscribe)│
└─────────────┘
```

---

## Konfiguration

### Docker Compose

```yaml
services:
  ntfy:
    image: binwiederhier/ntfy:v2.13.0
    container_name: ntfy
    ports:
      - "192.168.2.101:8900:80"
    volumes:
      - ./ntfy/server.yml:/etc/ntfy/server.yml:ro
      - ntfy_cache:/var/cache/ntfy
      - ntfy_data:/var/lib/ntfy
    command: serve --config /etc/ntfy/server.yml
```

### server.yml

```yaml
# ntfy/server.yml
base-url: "http://ntfy.lan"
listen-http: ":80"

# Speicher
cache-file: "/var/cache/ntfy/cache.db"
auth-file: "/var/lib/ntfy/auth.db"
auth-default-access: "read-write"  # Oder "deny-all" für private Topics

# Limits
message-size-limit: "4096"
message-delay: "1s"
message-timeout: "30s"

# Keepalive
keepalive-interval: "45s"
manager-interval: "1m"

# Web UI
web-root: "app"

# Enable attachments (optional)
attachment-cache-dir: "/var/cache/ntfy/attachments"
attachment-total-size-limit: "500M"
attachment-file-size-limit: "15M"
attachment-expiry-duration: "3h"

# Enable SMTP (optional für Email-Bridge)
# smtp-sender-addr: "smtp.gmail.com:587"
# smtp-sender-user: "your-email@gmail.com"
# smtp-sender-pass: "your-app-password"
# smtp-sender-from: "ntfy@yourdomain.com"
```

### Caddyfile

```caddyfile
ntfy.lan {
    reverse_proxy 192.168.2.101:8900
}
```

---

## Verwendung

### 1. Einfache Notification

```bash
# CLI curl
curl -d "Backup completed successfully" http://ntfy.lan/backups

# Mit Priorität (1-5, default 3)
curl -d "CRITICAL: Disk full" -H "Priority: 5" http://ntfy.lan/alerts

# Mit Tags/Emojis
curl -d "Update available" -H "Tags: rotating_light" http://ntfy.lan/updates
```

### 2. Im Backup-Script

```bash
# backup-full.sh erweitern
notify_ntfy() {
    local message="$1"
    local priority="${2:-3}"
    
    curl -s \
        -d "$message" \
        -H "Priority: $priority" \
        http://ntfy.lan/backups \
        > /dev/null 2>&1 || true
}

# Usage
notify_ntfy "✅ Backup completed: GitHub + USB" 3
notify_ntfy "🚨 Backup FAILED" 5
```

### 3. Home Assistant Integration

```yaml
# configuration.yaml
notify:
  - platform: rest
    name: ntfy_backups
    resource: http://ntfy.lan/backups
    method: POST
    headers:
      Priority: "3"

# Automation
automation:
  - alias: "Backup Notification"
    trigger:
      - platform: state
        entity_id: sensor.last_backup_status
        to: "failed"
    action:
      - service: notify.ntfy_backups
        data:
          message: "🚨 Backup failed! Check logs."
```

### 4. Prometheus Alertmanager Integration

ntfy ist mit Alertmanager für `severity="critical"` verdrahtet. Credentials via `.env`:

```bash
# ntfy User für Alertmanager anlegen (bereits eingerichtet):
docker exec ntfy ntfy user add --role=user alertmanager
docker exec ntfy ntfy access alertmanager alerts rw

# Auth testen:
curl -u alertmanager:<PASSWORD> -d "test" http://192.168.2.101:8900/alerts
```

```yaml
# alertmanager.yml (Live – Receiver telegram-and-ntfy):
webhook_configs:
  - url: 'http://<user>:<pass>@192.168.2.101:8900/alerts?priority=urgent&tags=rotating_light,pilab'
    send_resolved: true
```

- Credentials: `NTFY_ALERTMANAGER_USER` / `NTFY_ALERTMANAGER_PASSWORD` in `.env`
- Nur `severity="critical"` landet in ntfy (Warning/Info nur Telegram)
- Vollständige Routing-Konfiguration: [alertmanager-routing.md](alertmanager-routing.md)

---

## Topics (Kanäle)

| Topic | Zweck | Zugriff |
|-------|-------|---------|
| `backups` | Backup-Status | intern |
| `alerts` | Kritische Alerts | intern |
| `updates` | Update-Notifications | intern |
| `growbox` | Growbox-Status | intern |
| `system` | System-Meldungen | intern |

**Subscriben:**
```bash
# Browser: http://ntfy.lan → Topic eingeben
# Mobile App: Server-URL http://ntfy.lan → Topic "backups"
```

---

## Authentifizierung (optional)

```bash
# Auth aktivieren
ntfy user add --role=admin admin
ntfy user add --role=user viewer

# Token-basiert
curl -u admin:password -d "test" http://ntfy.lan/private
```

In `server.yml`:
```yaml
auth-default-access: "deny-all"
```

---

## Mobile App Setup

### Android

1. F-Droid oder Play Store: "ntfy"
2. Server-URL: `http://ntfy.lan` (im LAN) oder Tailscale-IP
3. Topics abonnieren: `backups`, `alerts`, etc.

### iOS

1. App Store: "ntfy"
2. Gleiche Schritte wie Android

### Web

Einfach `http://ntfy.lan` im Browser öffnen.

---

## Troubleshooting

### Keine Notifications auf Mobile

```bash
# Server erreichbar?
curl http://ntfy.lan/v1/health

# WebSocket-Test
wscat -c ws://ntfy.lan/ws

# Firewall prüfen
sudo ufw status | grep 8900
```

### "Connection refused"

```bash
# Container läuft?
docker ps | grep ntfy

# Logs
docker logs ntfy --tail 50

# Config-Format prüfen
docker exec ntfy ntfy serve --config /etc/ntfy/server.yml --dry-run
```

### Hohe CPU/RAM

```yaml
# Limits in server.yml anpassen
cache-size: "50M"  # Default: 200M
message-size-limit: "2048"  # Default: 4096
keepalive-interval: "60s"  # Default: 45s
```

---

## Backup

```bash
# SQLite-DB ist wichtig
./ntfy/ → /mnt/usb-backup/backups/YYYYMMDD/ntfy/

# Oder manuell
cp /var/lib/ntfy/*.db /backup/
```

---

## Changelog

| Datum | Änderung |
|-------|----------|
| 2026-04-10 | Dokumentation erstellt, ntfy v2.13.0 |
| 2026-04-13 | auth-default-access=deny-all; Alertmanager-Integration mit dediziertem Publisher-User |
