# Watchtower Auto-Updates

> Automated Docker container updates
> Schedule-based or webhook-triggered updates

---

## Overview

**Watchtower** automatically updates Docker containers when new images are available.

| Attribute | Value |
|-----------|-------|
| **Image** | `containrrr/watchtower:1.7.1` |
| **Container** | watchtower |
| **Schedule** | Sundays 03:00 |
| **Scope** | Labeled containers only |

---

## Configuration

### Docker Compose

```yaml
services:
  watchtower:
    image: containrrr/watchtower:1.7.1
    container_name: watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      TZ: Europe/Berlin
      WATCHTOWER_SCHEDULE: "0 0 3 * * 0"  # Sunday 03:00
      WATCHTOWER_LABEL_ENABLE: "true"     # Only labeled containers
      WATCHTOWER_NOTIFICATIONS: "shoutrrr"
      WATCHTOWER_NOTIFICATION_URL: "ntfy://192.168.2.101:8900/watchtower"
      WATCHTOWER_CLEANUP: "true"          # Remove old images
      WATCHTOWER_ROLLING_RESTART: "true"  # One at a time
      WATCHTOWER_TIMEOUT: "30s"
    restart: unless-stopped
```

---

## Label-Based Control

### Enable Auto-Update

```yaml
services:
  grafana:
    image: grafana/grafana:11.6.0
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

### Disable Auto-Update

```yaml
services:
  pihole:
    image: pihole/pihole:2026.04.0
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
```

---

## Update Behavior

| Container | Label | Updates? |
|-----------|-------|----------|
| Grafana | `enable=true` | ✅ Yes |
| Pi-hole | `enable=false` | ❌ No |
| Portainer | none | ❌ No (no label) |
| Home Assistant | `enable=true` | ✅ Yes |

---

## Notifications

### ntfy

```
Watchtower → ntfy → http://ntfy.lan/watchtower

Message: "Updates applied: grafana, influxdb"
```

### Email (optional)

```yaml
environment:
  WATCHTOWER_NOTIFICATION_EMAIL_FROM: "watchtower@pilab.local"
  WATCHTOWER_NOTIFICATION_EMAIL_TO: "admin@pilab.local"
  WATCHTOWER_NOTIFICATION_EMAIL_SERVER: "smtp.gmail.com"
  WATCHTOWER_NOTIFICATION_EMAIL_SERVER_PORT: "587"
```

---

## Manual Trigger

```bash
# Force check now
docker exec watchtower watchtower --run-once

# Check specific container
docker exec watchtower watchtower --run-once grafana
```

---

## Monitoring Updates

### Logs

```bash
docker logs watchtower -f
```

### Last check

```bash
docker exec watchtower date
docker logs watchtower --tail 10
```

---

## Exclusions

**Never auto-update (manual only):**
- Pi-hole (DNS critical)
- Tailscale (VPN critical)
- Vaultwarden (data integrity)
- MQTT (IoT messaging)

**Update with caution:**
- Home Assistant (check breaking changes)
- InfluxDB (data migration risk)

---

## Rollback

If update fails:

```bash
# Find previous image
docker images | grep grafana

# Stop and recreate with old tag
docker compose stop grafana
docker compose up -d grafana
# Edit docker-compose.yml first to pin old version
```

---

## Troubleshooting

### "Cannot connect to Docker"

```bash
# Check socket
docker exec watchtower ls -la /var/run/docker.sock

# Permission fix
sudo chmod 666 /var/run/docker.sock
```

### Updates not happening

```bash
# Check schedule
docker exec watchtower echo $WATCHTOWER_SCHEDULE

# Check labels
docker inspect grafana | grep watchtower

# Test manually
docker exec watchtower watchtower --run-once --debug
```

### Too many restarts

```yaml
# Increase interval
WATCHTOWER_SCHEDULE: "0 0 3 * * 0"  # Weekly, not daily

# Or disable rolling restart
WATCHTOWER_ROLLING_RESTART: "false"
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Documentation created, Watchtower 1.7.1 |
