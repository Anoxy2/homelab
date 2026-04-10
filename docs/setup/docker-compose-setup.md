# Docker Compose Stack Setup

> Initialer Setup-Guide für den Docker-Compose-Stack  
> Installation, erste Container, Grundkonfiguration

---

## Überblick

Das Homelab nutzt **Docker Compose** (v2) als Container-Orchestrator. Alle Services sind in einem zentralen `docker-compose.yml` definiert.

**Zentrale Philosophie:**
- Ein Stack-File: `/home/steges/docker-compose.yml`
- Daten in benannten Volumes
- Keine Bind Mounts für App-Daten (außer Configs)
- Alles versioniert in Git (außer Secrets)

---

## Voraussetzungen

### Hardware

| Komponente | Minimum | Empfohlen |
|------------|---------|-----------|
| Pi | Pi 4 4GB | ✅ Pi 5 8GB |
| Storage | 128GB SD | ✅ 1TB NVMe |
| Netzwerk | Ethernet 100M | ✅ Gigabit |

### Software

- Raspberry Pi OS (64-bit) oder Ubuntu Server
- Docker Engine >= 24.0
- Docker Compose >= 2.20

---

## Schritt 1: Docker Installation

### Standard-Install (Ubuntu/Debian)

```bash
# Alte Versionen entfernen
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    sudo apt-get remove $pkg 2>/dev/null || true
done

# Repository einrichten
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Installieren
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker Compose v2
sudo apt-get install docker-compose-plugin
```

### Raspberry Pi OS (bookworm)

```bash
# Standard Repos haben Docker
sudo apt update
sudo apt install docker.io docker-compose-v2

# Oder neueste Version via Docker Repos (siehe oben)
```

---

### Schritt 2: Docker konfigurieren

```bash
# User zur docker-Gruppe hinzufügen
sudo usermod -aG docker steges

# Neulogin nötig:
newgrp docker

# Testen:
docker --version
# Docker version 24.0.7, build afdd53b

docker compose version
# Docker Compose version v2.23.0
```

---

## Schritt 3: Projekt-Verzeichnis

```bash
# Hauptverzeichnis
mkdir -p /home/steges
cd /home/steges

# Unterverzeichnisse
mkdir -p {caddy,grafana,loki,scripts,infra}

# Repo initialisieren (falls noch nicht)
git init 2>/dev/null || echo "Already git repo"
git remote add origin https://github.com/steges/homelab.git 2>/dev/null || echo "Remote exists"
```

---

## Schritt 4: docker-compose.yml erstellen

### Template (Starter Stack)

```yaml
# /home/steges/docker-compose.yml
version: "3.8"

services:
  # ==================== INFRASTRUCTURE ====================
  
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - frontend
    environment:
      - ACME_AGREE=true

  # ==================== MONITORING ====================
  
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./grafana/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    networks:
      - backend
      - frontend

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    environment:
      - GF_SECURITY_ADMIN_PASSWORD__FILE=/run/secrets/grafana_admin_password
    secrets:
      - grafana_admin_password
    networks:
      - backend
      - frontend
    labels:
      - "caddy=grafana.localhost"
      - "caddy.reverse_proxy={{upstreams 3000}}"

  # ==================== LOGGING ====================
  
  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: unless-stopped
    volumes:
      - ./loki/loki-config.yml:/etc/loki/local-config.yaml:ro
      - loki_data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - backend

  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: unless-stopped
    volumes:
      - ./loki/promtail-config.yml:/etc/promtail/config.yml:ro
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
    command: -config.file=/etc/promtail/config.yml
    networks:
      - backend

# ==================== NETWORKS ====================
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true

# ==================== VOLUMES ====================
volumes:
  caddy_data:
  caddy_config:
  prometheus_data:
  grafana_data:
  loki_data:

# ==================== SECRETS ====================
secrets:
  grafana_admin_password:
    file: ./secrets/grafana_admin_password.txt
```

---

## Schritt 5: Secrets vorbereiten

```bash
# Secrets-Verzeichnis
mkdir -p /home/steges/secrets

# Grafana Passwort
echo "admin123" > /home/steges/secrets/grafana_admin_password.txt

# Permissions
chmod 600 /home/steges/secrets/*.txt

# Git Ignore
echo "secrets/" >> /home/steges/.gitignore
```

---

## Schritt 6: Erster Start

```bash
cd /home/steges

# Pull Images
docker compose pull

# Starten
docker compose up -d

# Status prüfen
docker compose ps

# Logs
docker compose logs -f
```

---

## Schritt 7: Basis-Container verstehen

### Caddy (Reverse Proxy)

**Funktion:** SSL-Termination, Reverse Proxy zu allen Services

```bash
# Caddyfile erstellen
cat > /home/steges/caddy/Caddyfile << 'EOF'
{
    auto_https off
}

grafana.localhost {
    reverse_proxy grafana:3000
}

prometheus.localhost {
    reverse_proxy prometheus:9090
}
EOF

# Reload
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### Prometheus (Metrics)

**Funktion:** Sammelt Metriken von allen Services

**Zugriff:** http://prometheus.localhost

### Grafana (Dashboards)

**Funktion:** Visualisiert Prometheus-Metriken

**Login:** admin / (Passwort aus secrets)

**Zugriff:** http://grafana.localhost

---

## Schritt 8: Gesundheitscheck

```bash
# Alle Container laufen?
docker compose ps

# Ressourcen-Nutzung
docker stats --no-stream

# Netzwerk-Verbindungen
docker network ls
docker network inspect steges_frontend

# Volume-Status
docker volume ls
```

---

## Troubleshooting

### Problem: "permission denied"

```bash
# Docker-Gruppe prüfen
groups steges

# Socket-Permissions
ls -la /var/run/docker.sock
```

### Problem: "port already in use"

```bash
# Port belegen?
sudo lsof -i :80
sudo lsof -i :443

# Oder andere Ports in docker-compose.yml verwenden
```

### Problem: Container startet nicht

```bash
# Logs prüfen
docker compose logs <service>

# Config validieren
docker compose config

# Einzeln starten für Debug
docker compose up caddy
```

### Problem: Speicher voll

```bash
# Docker-Storage
docker system df

# Cleanup
docker system prune -a
```

---

## Wartung

### Täglich

```bash
# Status
docker compose ps

# Logs auf Fehler prüfen
docker compose logs --tail=50
```

### Wöchentlich

```bash
# Updates prüfen
docker compose pull
docker compose up -d

# Cleanup
docker system prune -f
```

### Monatlich

```bash
# Volume-Backups
docker run --rm -v steges_grafana_data:/data -v /mnt/usb-backup:/backup alpine tar czf /backup/grafana-$(date +%Y%m%d).tar.gz /data
```

---

## Security Hardening

### Rootless (Optional)

```bash
# Rootless Docker
sudo apt install uidmap
dockerd-rootless-setuptool.sh install
```

### Netzwerk-Isolation

```yaml
# Backend-Netzwerk ist internal (kein Internet)
networks:
  backend:
    internal: true
```

### Image-Updates

```bash
# CVE-Scanner
docker scout cves <image>

# Oder Trivy
trivy image <image>
```

---

## Weiterführend

- `docs/infrastructure/docker-compose-stack.md` – Vollständiger Stack
- `docs/setup/pihole-setup.md` – Pi-hole hinzufügen
- `docs/setup/homeassistant-setup.md` – Home Assistant hinzufügen
