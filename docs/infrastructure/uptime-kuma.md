# Uptime Kuma External Monitoring

> External uptime monitoring and status page
> HTTP/TCP/Ping/Keyword checks, notifications

---

## Overview

**Uptime Kuma** monitors external services and provides status pages.

| Attribute | Value |
|-----------|-------|
| **Image** | `louislam/uptime-kuma:1.23.16` |
| **Container** | uptime-kuma |
| **Port** | `192.168.2.101:3001` |
| **LAN URL** | `http://uptime.lan:3001` |
| **Data** | `./uptime-kuma/data/` |

---

## Configuration

### Docker Compose

```yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1.23.16
    container_name: uptime-kuma
    ports:
      - "192.168.2.101:3001:3001"
    volumes:
      - ./uptime-kuma/data:/app/data
    restart: unless-stopped
```

### Caddyfile

```caddyfile
uptime.lan {
    reverse_proxy 192.168.2.101:3001
}
```

---

## First Setup

1. Open `http://uptime.lan:3001`
2. Create admin account
3. Add monitors

---

## Monitor Types

| Type | Use Case |
|------|----------|
| **HTTP(s)** | Web services, APIs |
| **TCP** | Database, MQTT |
| **Ping** | Host availability |
| **Keyword** | Check page content |
| **DNS** | DNS resolution |
| **Docker** | Container health |

---

## Monitor Configuration

### HTTP Monitor Example

```
Type: HTTP(s)
Friendly Name: Grafana
URL: http://192.168.2.101:3003
Heartbeat Interval: 60s
Retry: 3 times
Request Timeout: 10s
```

### Keyword Monitor

```
Type: HTTP(s) - Keyword
Friendly Name: Pi-hole Admin
URL: http://192.168.2.101:8080/admin
Keyword: "Pi-hole"
```

---

## Notifications

### ntfy Integration

```
Settings → Notifications → ntfy
Server URL: http://192.168.2.101:8900
Topic: uptime-alerts
Priority: 3
```

### Notification Events

| Event | When |
|-------|------|
| **Down** | Monitor fails |
| **Up** | Monitor recovers |
| **Cert Expiry** | SSL cert < 14 days |

---

## Status Page

```
Status Pages → New Status Page
Title: PiLab Status
Monitors: Select all
Public: Yes/No
```

**Public URL:** `http://uptime.lan:3001/status/pilab`

---

## Maintenance Windows

```
Maintenance → New
Title: "Weekly Backup"
Start: Sunday 03:00
Duration: 30 minutes
Monitors: Select affected
```

---

## API

```bash
# Get monitors (requires API key from Settings)
curl -H "Authorization: Bearer API_KEY" \
  http://192.168.2.101:3001/api/monitors

# Get status
 curl http://192.168.2.101:3001/api/status-page/pilab
```

---

## Recommended Monitors

| Service | Type | Interval |
|---------|------|----------|
| Pi-hole DNS | Ping | 30s |
| Home Assistant | HTTP | 60s |
| Grafana | HTTP | 60s |
| Vaultwarden | HTTP | 120s |
| Internet (1.1.1.1) | Ping | 60s |

---

## Troubleshooting

### False positives

```
Increase retry count: 3 → 5
Increase timeout: 10s → 20s
```

### Notifications not working

```
Settings → Notifications → Test
Check ntfy topic exists: curl http://ntfy.lan/uptime-alerts
```

### High memory usage

```bash
# Too many monitors?
docker stats uptime-kuma

# Reduce retention: Settings → Monitor History
```

---

## Backup

```bash
# Data directory
./uptime-kuma/data/ → /mnt/usb-backup/backups/YYYYMMDD/uptime-kuma/
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Documentation created, Uptime Kuma 1.23.16 |
