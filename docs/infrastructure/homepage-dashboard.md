# Homepage Dashboard

> Zentrales Service-Dashboard für das Homelab
> Docker-Socket-Integration für Live-Status

---

## Überblick

**Homepage** von gethomepage.io zeigt alle Services mit Status, Metriken und Quick-Links.

| Attribut | Wert |
|----------|------|
| **Image** | `ghcr.io/gethomepage/homepage:v1.12.3` |
| **Container** | homepage |
| **Port** | `192.168.2.101:3002` → Container `3000` |
| **LAN URL** | `http://home.lan`, `http://dashboard.lan` |
| **Config** | `./homepage/config/` |

---

## Architektur

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Browser   │────→│    Caddy    │────→│   Homepage  │
└─────────────┘     └─────────────┘     └─────────────┘
                                                │
                                                ↓
                                       ┌─────────────────┐
                                       │ docker-socket-  │
                                       │ proxy:2375      │
                                       └─────────────────┘
```

**Sicher:** Kein direkter Docker-Socket Mount, nur via Proxy.

---

## Konfiguration

### Docker Compose

```yaml
services:
  homepage:
    image: ghcr.io/gethomepage/homepage:v1.12.3
    container_name: homepage
    ports:
      - "192.168.2.101:3002:3000"
    volumes:
      - ./homepage/config:/app/config
    environment:
      HOMEPAGE_ALLOWED_HOSTS: "home.lan,dashboard.lan,192.168.2.101:3002"
      DOCKER_HOST: tcp://docker-socket-proxy:2375
    depends_on:
      - docker-socket-proxy
```

### Caddyfile

```caddyfile
home.lan, dashboard.lan {
    reverse_proxy 192.168.2.101:3002
}
```

---

## Config-Struktur

```
homepage/config/
├── widgets.yaml          # System-Widgets (CPU, RAM, Uptime)
├── services.yaml         # Service-Kategorien & Links
├── bookmarks.yaml        # Quick-Links
├── settings.yaml         # Global Settings
└── custom.css            # (optional) Custom Styling
```

### widgets.yaml

```yaml
---
- resources:
    cpu: true
    memory: true
    disk: /
- search:
    provider: duckduckgo
    target: _blank
- datetime:
    text_size: xl
    format:
      timeStyle: short
      dateStyle: short
```

### services.yaml

```yaml
---
- Infrastructure:
    - Portainer:
        icon: portainer.png
        href: http://portainer.lan:9000
        description: Container Management
        widget:
          type: portainer
          url: http://192.168.2.101:9000
          env: 2
          node: pilab

    - Pi-hole:
        icon: pi-hole.png
        href: http://pihole.lan:8080/admin
        description: DNS & Ad-blocking
        widget:
          type: pihole
          url: http://192.168.2.101:8080
          key: ${PIHOLE_API_TOKEN}

- Monitoring:
    - Grafana:
        icon: grafana.png
        href: http://grafana.lan:3003
        description: Metrics Dashboard
        widget:
          type: grafana
          url: http://192.168.2.101:3003
          username: admin
          password: ${GRAFANA_ADMIN_PASSWORD}

    - Uptime Kuma:
        icon: uptime-kuma.png
        href: http://uptime.lan:3001
        description: Uptime Monitoring
        widget:
          type: uptimekuma
          url: http://192.168.2.101:3001
          key: ${UPTIME_KUMA_API_KEY}

- Home Automation:
    - Home Assistant:
        icon: home-assistant.png
        href: http://homeassistant.lan:8123
        description: Smart Home Hub
        widget:
          type: homeassistant
          url: http://192.168.2.101:8123
          key: ${HASS_TOKEN}

- Security:
    - Vaultwarden:
        icon: bitwarden.png
        href: http://vault.lan
        description: Password Manager
        widget:
          type: vaultwarden
          url: http://192.168.2.101:8888
```

### bookmarks.yaml

```yaml
---
- Developer:
    - GitHub:
        - icon: github.png
        - href: https://github.com/Anoxy2/homelab
    - Docker Hub:
        - icon: docker.png
        - href: https://hub.docker.com/

- Tools:
    - Tailscale:
        - icon: tailscale.png
        - href: https://login.tailscale.com/admin/machines
    - Speedtest:
        - icon: speedtest.png
        - href: https://www.speedtest.net/
```

### settings.yaml

```yaml
---
title: PiLab Dashboard
theme: dark
color: slate

layout:
  Infrastructure:
    style: row
    columns: 4
  Monitoring:
    style: row
    columns: 3
  Home Automation:
    style: row
    columns: 2

background:
  image: /images/background.jpg  # optional
  blur: sm
  opacity: 50
```

---

## Widgets mit Secrets

Secrets in `.env` definieren:

```bash
PIHOLE_API_TOKEN=your_token_here
GRAFANA_ADMIN_PASSWORD=your_password
HASS_TOKEN=long_lived_access_token
UPTIME_KUMA_API_KEY=api_key_here
```

Homepage lädt `.env` automatisch (via `env_file` in compose).

---

## Docker Integration

Homepage zeigt Container-Status automatisch für Services mit gleichem Container-Namen:

```yaml
# Wenn Container "portainer" heißt:
widget:
  type: portainer  # Automatisch verbunden
```

**Berechtigungen via docker-socket-proxy:**
- `CONTAINERS: 1` – Container-Status lesen
- Keine Schreib-Rechte (Exec, Build etc. deaktiviert)

---

## Custom CSS (optional)

```css
/* homepage/config/custom.css */
.service-icon img {
    border-radius: 12px;
}

.widget {
    backdrop-filter: blur(10px);
}
```

In `settings.yaml`:
```yaml
custom.css: true
```

---

## Troubleshooting

### "Forbidden" / Host Header Error

```yaml
environment:
  HOMEPAGE_ALLOWED_HOSTS: "home.lan,dashboard.lan,192.168.2.101:3002,localhost"
```

### Widget zeigt "Error"

```bash
# API-Key prüfen
curl http://192.168.2.101:8080/admin/api.php?status&auth=TOKEN

# Container Logs
docker logs homepage --tail 50
```

### Icons nicht sichtbar

- Icons liegen in `homepage/config/icons/` (PNG, 128x128)
- Alternativ: Material Design Icons via `icon: mdi-xxx`

---

## Backup

```bash
# Config sichern
tar czf homepage-config-$(date +%Y%m%d).tar.gz ./homepage/config/

# Oder im USB-Backup enthalten
./homepage/config/ → /mnt/usb-backup/backups/YYYYMMDD/homepage/
```

---

## Changelog

| Datum | Änderung |
|-------|----------|
| 2026-04-10 | Dokumentation erstellt, v1.12.3 |
