# Docker Compose Stack – Vollständige Übersicht

> Alle Container, Services, Volumes und Netzwerke  
> Stand: April 2026

---

## Übersicht

| Kategorie | Anzahl | Services |
|-----------|--------|----------|
| **Core** | 3 | Caddy, Pi-hole, Unbound |
| **Monitoring** | 6 | Prometheus, Grafana, Loki, Promtail, Alertmanager, Node Exporter |
| **Smart Home** | 2 | Home Assistant, Mosquitto (MQTT) |
| **Tools** | 5 | Vaultwarden, SearXNG, NTFY, ESPHome, Scrutiny |
| **AI/Agent** | 1 | OpenClaw |
| **Auth** | 1 | Authelia |
| **Gesamt** | ~18 | |

---

## Core-Infrastruktur

### Caddy (Reverse Proxy)

```yaml
caddy:
  image: caddy:2.7-alpine
  container_name: caddy
  restart: unless-stopped
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
    - caddy-data:/data
    - caddy-config:/config
  networks:
    - caddy-net
```

| Parameter | Wert |
|-----------|------|
| **Image** | caddy:2.7-alpine |
| **Ports** | 80, 443 |
| **Config** | `./caddy/Caddyfile` |
| **Netzwerk** | caddy-net |

**Features:**
- Automatisches HTTPS (Let's Encrypt)
- Reverse Proxy für alle internen Services
- HTTP/3 Support
- Compression

---

### Pi-hole (DNS-Filter)

```yaml
pihole:
  image: pihole/pihole:2024.02.0
  container_name: pihole
  restart: unless-stopped
  ports:
    - "53:53/tcp"
    - "53:53/udp"
    - "8081:80"  # Admin UI
  environment:
    - TZ=Europe/Berlin
    - WEBPASSWORD=${PIHOLE_PASSWORD}
  volumes:
    - ./pihole/etc-pihole:/etc/pihole
    - ./pihole/etc-dnsmasq.d:/etc/dnsmasq.d
```

| Parameter | Wert |
|-----------|------|
| **DNS Ports** | 53/tcp, 53/udp |
| **Web UI** | http://192.168.2.101:8081 |
| **Blocklists** | ~100.000 Domains |

**Blocklists:**
- StevenBlack/hosts
- OISD (Full)
- Firebog (ticked lists)

---

### Unbound (DNS-Resolver)

```yaml
unbound:
  image: mvance/unbound:1.19.0
  container_name: unbound
  restart: unless-stopped
  ports:
    - "5335:53/tcp"
    - "5335:53/udp"
  volumes:
    - ./unbound:/opt/unbound/etc/unbound
```

**Upstream für Pi-hole:** `127.0.0.1#5335`

---

## Monitoring Stack

### Prometheus (Metrics-Sammlung)

```yaml
prometheus:
  image: prom/prometheus:v2.49.1
  container_name: prometheus
  restart: unless-stopped
  ports:
    - "9090:9090"
  volumes:
    - ./prometheus:/etc/prometheus
    - prometheus-data:/prometheus
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--storage.tsdb.retention.time=30d'
```

| Parameter | Wert |
|-----------|------|
| **Web UI** | http://192.168.2.101:9090 |
| **Retention** | 30 Tage |
| **Scrape Interval** | 15s |

**Targets:**
- Prometheus (self)
- Node Exporter (System)
- cAdvisor (Docker)
- OpenClaw Metrics
- Home Assistant

---

### Grafana (Visualisierung)

```yaml
grafana:
  image: grafana/grafana:10.3.1
  container_name: grafana
  restart: unless-stopped
  ports:
    - "3000:3000"
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource
  volumes:
    - grafana-data:/var/lib/grafana
    - ./grafana/provisioning:/etc/grafana/provisioning
```

| Parameter | Wert |
|-----------|------|
| **Web UI** | http://192.168.2.101:3000 |
| **Default Login** | admin / ${GRAFANA_PASSWORD} |
| **Dashboards** | Pi, Docker, OpenClaw, Smart Home |

---

### Loki + Promtail (Logs)

```yaml
loki:
  image: grafana/loki:2.9.0
  container_name: loki
  restart: unless-stopped
  ports:
    - "3100:3100"
  volumes:
    - ./loki:/etc/loki
    - loki-data:/tmp/loki
  command: -config.file=/etc/loki/local-config.yaml

promtail:
  image: grafana/promtail:2.9.0
  container_name: promtail
  restart: unless-stopped
  volumes:
    - ./promtail:/etc/promtail
    - /var/log:/var/log:ro
    - /var/lib/docker/containers:/var/lib/docker/containers:ro
  command: -config.file=/etc/promtail/config.yaml
```

---

### Alertmanager (Alerts)

```yaml
alertmanager:
  image: prom/alertmanager:v0.26.0
  container_name: alertmanager
  restart: unless-stopped
  ports:
    - "9093:9093"
  volumes:
    - ./alertmanager:/etc/alertmanager
    - alertmanager-data:/alertmanager
```

**Notification Channels:**
- Email (Gmail)
- NTFY (Push)
- Telegram (via Webhook)

---

## Smart Home

### Home Assistant

```yaml
homeassistant:
  image: ghcr.io/home-assistant/home-assistant:2024.2
  container_name: homeassistant
  restart: unless-stopped
  privileged: true
  ports:
    - "8123:8123"
  volumes:
    - ./homeassistant:/config
    - /run/dbus:/run/dbus:ro
  environment:
    - TZ=Europe/Berlin
```

| Parameter | Wert |
|-----------|------|
| **Web UI** | http://192.168.2.101:8123 |
| **HACS** | Installiert |
| **Integrationen** | Zigbee2MQTT, Tasmota, ESPHome |

---

### Mosquitto (MQTT Broker)

```yaml
mosquitto:
  image: eclipse-mosquitto:2.0.18
  container_name: mosquitto
  restart: unless-stopped
  ports:
    - "1883:1883"
    - "9001:9001"  # WebSocket
  volumes:
    - ./mosquitto/config:/mosquitto/config
    - ./mosquitto/data:/mosquitto/data
    - ./mosquitto/log:/mosquitto/log
```

---

## Tools & Services

### Vaultwarden (Password Manager)

| Parameter | Wert |
|-----------|------|
| **Web UI** | https://vault.steges.duckdns.org |
| **Admin** | /admin (mit Token) |
| **Storage** | SQLite |

---

### SearXNG (Search)

| Parameter | Wert |
|-----------|------|
| **Web UI** | https://search.steges.duckdns.org |
| **Engines** | Google, DDG, Bing, Startpage |
| **Privacy** | Keine Logs |

---

### NTFY (Push Notifications)

| Parameter | Wert |
|-----------|------|
| **Web UI** | https://ntfy.steges.duckdns.org |
| **MQTT** | Aktiviert |
| **Use-Case** | Alerts, Growbox, ESP32 |

---

### ESPHome (Firmware)

| Parameter | Wert |
|-----------|------|
| **Web UI** | https://esphome.steges.duckdns.org |
| **Purpose** | ESP32/ESP8266 flashen |
| **Devices** | Growbox-Sensoren |

---

### Scrutiny (SMART Monitoring)

| Parameter | Wert |
|-----------|------|
| **Web UI** | https://scrutiny.steges.duckdns.org |
| **Devices** | NVMe, externe USB-Drives |
| **Alerts** | Telegram via Webhook |

---

## AI Stack

### OpenClaw

```yaml
openclaw:
  image: openclaw/openclaw:latest
  container_name: openclaw
  restart: unless-stopped
  ports:
    - "18789:18789"
    - "8090:8090"
  volumes:
    - ./openclaw-data:/data
    - ./agent:/agent:ro
  environment:
    - OPENCLAW_CONFIG=/data/openclaw.json
    - NODE_OPTIONS=--max-old-space-size=1536
```

| Parameter | Wert |
|-----------|------|
| **Gateway** | ws://192.168.2.101:18789 |
| **Web UI** | http://192.168.2.101:8090 |
| **Config** | `infra/openclaw-data/openclaw.json` |

---

## Docker-Netzwerke

```yaml
networks:
  caddy-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
  
  monitoring:
    driver: bridge
    internal: true  # Kein externer Zugriff
```

---

## Volumes

| Volume | Purpose | Backup |
|--------|---------|--------|
| `caddy-data` | Certificates | ✅ |
| `caddy-config` | Caddy config | ❌ |
| `prometheus-data` | 30d Metrics | ❌ |
| `grafana-data` | Dashboards | ✅ |
| `loki-data` | Logs (7d) | ❌ |
| `alertmanager-data` | Alert state | ❌ |

---

## Resource-Limits (empfohlen für Pi)

```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 512M
    reservations:
      memory: 128M
```

---

## Wartung

### Updates

```bash
# Alle Images aktualisieren
cd /home/steges && docker-compose pull && docker-compose up -d

# Oder einzeln
docker-compose pull caddy && docker-compose up -d caddy
```

### Logs

```bash
# Alle Logs
docker-compose logs -f --tail 100

# Ein Service
docker-compose logs -f openclaw

# Loki-Query
{container_name="openclaw"} |= "error"
```

### Cleanup

```bash
# Unbenutzte Images/Container/Volumes
docker system prune -a --volumes

# Volume-Größen
docker system df -v
```

---

## Troubleshooting

### Container startet nicht

```bash
# Config validieren
docker-compose config

# Logs prüfen
docker logs <container>

# Dependencies
docker-compose ps
```

### Port-Konflikte

```bash
# Wer benutzt Port 80?
sudo lsof -i :80

# Alternative Ports
docker-compose -f docker-compose.alt.yml up
```

---

## Referenzen

- `docker-compose.yml` – Haupt-Definition
- `scripts/update-stacks.sh` – Update-Automation
- `scripts/backup.sh` – Volume-Backup
- `agent/skills/pi-control/` – Docker-Management Skills
