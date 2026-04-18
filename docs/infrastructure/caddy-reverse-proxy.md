# Caddy Reverse Proxy

> Automatischer HTTPS-Reverse-Proxy für LAN-Hostnames
> Kein manuelles Zertifikats-Management nötig

---

## Überblick

**Caddy** routet LAN-URLs (`home.lan`, `vault.lan`, etc.) zu internen Services.

| Attribut | Wert |
|----------|------|
| **Image** | `caddy:2-alpine` |
| **Container** | caddy |
| **Port** | `80` (Host mode) |
| **Config** | `./caddy/Caddyfile` |
| **Features** | Auto-HTTPS (intern), Reverse Proxy, Static Files |

---

## Architektur

```
┌──────────┐     ┌──────────┐     ┌─────────────┐
|  Client  │────→|  :80     │────→|   Caddy     │
|  Browser │     |  pihole  │     |  (Host)     |
└──────────┘     └──────────┘     └─────────────┘
                                        │
          ┌─────────────────────────────┼─────────────────────────────┐
          ↓                             ↓                             ↓
    ┌──────────┐                 ┌──────────┐                 ┌──────────┐
    | vault.lan|                 | home.lan |                 |grafana.lan
    | :8888    |                 | :3002    |                 | :3003    |
    └──────────┘                 └──────────┘                 └──────────┘
```

---

## Konfiguration

### Docker Compose

```yaml
services:
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    network_mode: host
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - pihole
      - homeassistant
      - esphome
      # ... alle Services
```

### Caddyfile

```caddyfile
# ─── Internal Health Check ────────────────────────────────────────────────────
:80 {
    respond /health "ok" 200
}

# ─── Dashboard ────────────────────────────────────────────────────────────────
home.lan, dashboard.lan {
    reverse_proxy 192.168.2.101:3002
}

# ─── Password Manager ───────────────────────────────────────────────────────────
vault.lan {
    reverse_proxy 192.168.2.101:8888
}

# ─── DNS / Ad-blocking ────────────────────────────────────────────────────────
pihole.lan {
    reverse_proxy 192.168.2.101:8080
}

# ─── Home Automation ──────────────────────────────────────────────────────────
homeassistant.lan, hass.lan {
    reverse_proxy 192.168.2.101:8123
}

esphome.lan {
    reverse_proxy 192.168.2.101:6052
}

mosquitto.lan, mqtt.lan {
    reverse_proxy 192.168.2.101:1883
}

# ─── Monitoring ───────────────────────────────────────────────────────────────
grafana.lan {
    reverse_proxy 192.168.2.101:3003
}

prometheus.lan {
    reverse_proxy 192.168.2.101:9090
}

alertmanager.lan {
    reverse_proxy 192.168.2.101:9093
}

glances.lan {
    reverse_proxy 192.168.2.101:61208
}

# ─── Management ───────────────────────────────────────────────────────────────
portainer.lan {
    reverse_proxy 192.168.2.101:9000
}

uptime.lan {
    reverse_proxy 192.168.2.101:3001
}

# ─── VPN ──────────────────────────────────────────────────────────────────────
tailscale.lan {
    reverse_proxy 192.168.2.101:8088
}

# ─── Search ───────────────────────────────────────────────────────────────────
search.lan {
    reverse_proxy 192.168.2.101:8085
}

# ─── Notifications ──────────────────────────────────────────────────────────────
ntfy.lan {
    reverse_proxy 192.168.2.101:8900
}

# ─── Hardware Monitoring ───────────────────────────────────────────────────────
scrutiny.lan {
    reverse_proxy 192.168.2.101:8891
}

# ─── OpenClaw ─────────────────────────────────────────────────────────────────
openclaw.lan, claw.lan {
    reverse_proxy 192.168.2.101:18789
}

ops.lan {
    reverse_proxy 192.168.2.101:8090
}

# ─── Auth ─────────────────────────────────────────────────────────────────────
auth.lan {
    reverse_proxy 192.168.2.101:9091
}

# ─── Logs ─────────────────────────────────────────────────────────────────────
loki.lan {
    reverse_proxy 192.168.2.101:3100
}
```

---

## Pi-hole Integration

**DNS Records setzen:**

```bash
# Pi-hole Local DNS Records
192.168.2.101    home.lan
192.168.2.101    dashboard.lan
192.168.2.101    vault.lan
192.168.2.101    pihole.lan
192.168.2.101    homeassistant.lan
192.168.2.101    hass.lan
192.168.2.101    esphome.lan
192.168.2.101    grafana.lan
192.168.2.101    prometheus.lan
192.168.2.101    portainer.lan
192.168.2.101    uptime.lan
192.168.2.101    openclaw.lan
192.168.2.101    ops.lan
192.168.2.101    ui.lan
192.168.2.101    search.lan
192.168.2.101    auth.lan
192.168.2.101    ntfy.lan
192.168.2.101    scrutiny.lan
192.168.2.101    loki.lan
```

Oder via `Local DNS → DNS Records` in Pi-hole Web-UI.

---

## Authelia Integration (optional)

Forward-Auth für Services:

```caddyfile
grafana.lan {
    forward_auth 192.168.2.101:9091 {
        uri /api/verify?rdm=https://auth.lan
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy 192.168.2.101:3003
}
```

---

## HTTPS (intern)

Caddy erstellt automatisch interne Zertifikate:

```caddyfile
{
    local_certs
    auto_https disable_redirects
}
```

**Hinweis:** Im LAN ist HTTP ausreichend. Für Tailscale-Remote-Zugriff nutzt Tailscale internes HTTPS.

---

## Troubleshooting

### "connection refused"

```bash
# Service läuft?
docker ps | grep <service>

# Port erreichbar?
curl http://192.168.2.101:<port>

# Caddy Config valid?
docker exec caddy caddy validate --config /etc/caddy/Caddyfile
```

### DNS funktioniert nicht

```bash
# Pi-hole prüfen
nslookup vault.lan 192.168.2.101

# Falls NXDOMAIN: DNS Record in Pi-hole fehlt
```

### 502 Bad Gateway

```bash
# Backend-Port prüfen
docker inspect <service> | grep -A 5 '"NetworkMode"'

# Service neu starten
docker compose restart <service>
```

---

## Backup

```bash
# Caddyfile ist im Git-Repo (automatisch gesichert)
# Data-Volumes werden im USB-Backup gesichert
caddy_data:/data
caddy_config:/config
```

---

## Changelog

| Datum | Änderung |
|-------|----------|
| 2026-04-10 | Dokumentation erstellt, Caddy 2-alpine |
