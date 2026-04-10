# Glances System Monitor

> Cross-platform system monitoring
> Web UI, REST API, export to various backends

---

## Overview

**Glances** provides system resource monitoring via web interface and API.

| Attribute | Value |
|-----------|-------|
| **Image** | `nicolargo/glances:4.3.0-full` |
| **Container** | glances |
| **Port** | `192.168.2.101:61208` |
| **LAN URL** | `http://glances.lan:61208` |
| **Mode** | Web server (`-w`) |

---

## Configuration

### Docker Compose

```yaml
services:
  glances:
    image: nicolargo/glances:4.3.0-full
    container_name: glances
    network_mode: host
    pid: host
    ports:
      - "192.168.2.101:61208:61208"
    environment:
      GLANCES_OPT: "-w"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./glances/config:/etc/glances
    restart: unless-stopped
```

### Caddyfile

```caddyfile
glances.lan {
    reverse_proxy 192.168.2.101:61208
}
```

---

## Web Interface

```
http://glances.lan:61208
```

### Sections

| Section | Shows |
|---------|-------|
| **CPU** | Usage per core, load average |
| **Memory** | RAM, swap usage |
| **Network** | IO per interface |
| **Disk** | Usage per mount |
| **Docker** | Container stats |
| **Processes** | Top processes by CPU/Mem |

---

## REST API

### Endpoints

```bash
# All stats
curl http://192.168.2.101:61208/api/4/all

# CPU
curl http://192.168.2.101:61208/api/4/cpu

# Memory
curl http://192.168.2.101:61208/api/4/mem

# Disk
curl http://192.168.2.101:61208/api/4/fs

# Network
curl http://192.168.2.101:61208/api/4/network

# Docker containers
curl http://192.168.2.101:61208/api/4/docker
```

### Prometheus Export

```bash
curl http://192.168.2.101:61208/metrics
```

---

## Alerts

### glances.conf

```ini
[global]
refresh=2

[cpu]
careful=50
warning=70
critical=90

[memory]
careful=60
warning=80
critical=90

[swap]
careful=20
warning=50
critical=80

[fs]
careful=70
warning=85
critical=95
```

---

## Export Backends

### InfluxDB

```bash
GLANCES_OPT="-w --export influxdb"
```

### Prometheus

```bash
GLANCES_OPT="-w --export prometheus"
```

### MQTT

```bash
GLANCES_OPT="-w --export mqtt"
```

---

## Client Mode

Run Glances locally to connect to server:

```bash
glances -c 192.168.2.101
```

---

## Troubleshooting

### "Connection refused"

```bash
# Check container running
docker ps | grep glances

# Check mode
docker exec glances ps aux | grep glances
# Should show: -w (web mode)
```

### Missing Docker stats

```bash
# Check socket mount
docker exec glances ls -la /var/run/docker.sock

# Permission fix
sudo chmod 666 /var/run/docker.sock
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Documentation created, Glances 4.3.0 |
