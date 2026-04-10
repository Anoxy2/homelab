# OpenClaw – Operations Guide

> Betrieb, Monitoring, Troubleshooting & Wartung  
> Stand: April 2026

---

## Deployment-Optionen

### 1. Docker (Empfohlen)

```yaml
# docker-compose.yml
version: '3.8'
services:
  openclaw:
    image: openclaw/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    ports:
      - "18789:18789"
      - "8090:8090"  # Canvas UI
    volumes:
      - ./data:/data
      - ./agent:/agent
    environment:
      - OPENCLAW_CONFIG=/data/openclaw.json
      - OPENCLAW_LOG_LEVEL=info
    networks:
      - openclaw-network

  # Optional: Cloudflare Tunnel
  tunnel:
    image: cloudflare/cloudflared:latest
    command: tunnel --no-autoupdate run
    environment:
      - TUNNEL_TOKEN=${CF_TUNNEL_TOKEN}
    networks:
      - openclaw-network

networks:
  openclaw-network:
    driver: bridge
```

### 2. Native (Node.js)

```bash
# Installation
git clone https://github.com/openclaw/openclaw.git
cd openclaw
npm ci --production

# Start
npm start

# PM2 für Production
pm2 start openclaw.mjs --name openclaw
pm2 save
pm2 startup
```

### 3. Raspberry Pi

```bash
# Docker-Compose für ARM64
wget https://raw.githubusercontent.com/openclaw/openclaw/main/docker-compose.pi.yml

# Spezielle Anpassungen
echo 'OPENCLAW_MEMORY_LIMIT=512m' >> .env
```

---

## Systemanforderungen

| Umgebung | CPU | RAM | Storage | Netzwerk |
|----------|-----|-----|---------|----------|
| **Minimal** | 2 Cores | 2 GB | 10 GB | 10 Mbps |
| **Empfohlen** | 4 Cores | 4 GB | 20 GB | 100 Mbps |
| **Production** | 8+ Cores | 8+ GB | 50 GB+ | 1 Gbps |
| **Pi 5** | 4 Cores @ 2.4GHz | 8 GB | NVMe SSD | LAN |

---

## Monitoring

### Health Checks

```bash
# Gateway-Status
curl http://localhost:18789/status

# Docker-Health
docker ps | grep openclaw

# System-Resources
docker stats openclaw --no-stream
```

### Logging

```bash
# Container-Logs
docker logs -f openclaw --tail 100

# Journal (systemd)
journalctl -u openclaw -f

# Log-Level setzen
docker exec openclaw openclaw config set log.level debug
```

### Metriken

```bash
# Prometheus-Endpoint (wenn konfiguriert)
curl http://localhost:18789/metrics

# Eigene Metriken
~/scripts/skill-forge metrics
```

### Alerts

```json
// Alert-Konfiguration in openclaw.json
{
  "monitoring": {
    "alerts": {
      "channels": ["telegram"],
      "rules": [
        {
          "name": "high_memory",
          "condition": "memory > 80%",
          "action": "notify"
        }
      ]
    }
  }
}
```

---

## Backup & Recovery

### Automatisches Backup

```bash
#!/bin/bash
# ~/scripts/backup.sh

BACKUP_DIR="/backup/openclaw/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Config
cp ~/.config/openclaw/openclaw.json $BACKUP_DIR/

# Daten
docker exec openclaw tar czf - /data > $BACKUP_DIR/data.tar.gz

# Agent-Workspace
tar czf $BACKUP_DIR/agent.tar.gz ~/agent/

# Upload (optional)
# rclone sync $BACKUP_DIR remote:openclaw-backups
```

### Manuelles Backup

```bash
# Einzelkomponenten
docker exec openclaw sqlite3 /data/memory/main.sqlite ".backup /tmp/memory.backup"
docker cp openclaw:/tmp/memory.backup ./memory-$(date +%Y%m%d).sqlite
```

### Recovery

```bash
# 1. Container stoppen
docker-compose down

# 2. Daten zurückspielen
tar xzf backup-20260410/data.tar.gz -C ./restore/
cp -r restore/data/* ./data/

# 3. Starten
docker-compose up -d

# 4. Verifizierung
docker exec openclaw openclaw status
```

---

## Updates

### Minor Updates

```bash
# Docker Image pull
docker-compose pull
docker-compose up -d

# Verifizierung
docker exec openclaw openclaw --version
```

### Major Updates

```bash
# 1. Backup erstellen
~/scripts/backup.sh

# 2. Canary-Test (wenn verfügbar)
~/scripts/skill-forge canary start openclaw-core 24

# 3. Update durchführen
docker-compose pull
docker-compose up -d

# 4. Smoke Tests
~/agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh
```

### Rollback

```bash
# Vorherige Version
docker-compose pull openclaw:previous-tag
docker-compose up -d
```

---

## Troubleshooting

### Verbindungsprobleme

```bash
# Port-Belegung prüfen
sudo lsof -i :18789

# Firewall-Regeln
sudo ufw status
sudo iptables -L | grep 18789

# Netzwerk-Test
curl -v http://localhost:18789/status
ping openclaw.lan
```

### Performance-Probleme

```bash
# CPU/Top-Check
docker stats openclaw --no-stream

# Memory-Leak-Verdacht
docker exec openclaw ps aux --sort=-%mem

# Langsame Responses
# → Log-Level auf debug, dann timing prüfen
```

### API-Fehler

| Fehler | Ursache | Lösung |
|--------|---------|--------|
| `ECONNREFUSED` | Gateway nicht gestartet | Container prüfen |
| `ETIMEDOUT` | Netzwerk-Timeout | Firewall/Routing prüfen |
| `403 Forbidden` | Auth-Fehler | Token erneuern |
| `500 Internal` | Skill-Fehler | Logs analysieren |

### LLM-Provider-Probleme

```bash
# API-Key-Test
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -d '{"model": "claude-3-5-sonnet", "messages": []}'

# Quota-Check
docker exec openclaw openclaw agent --message "test quota" --json
```

---

## Wartung

### Täglich

- Logs auf Errors prüfen
- Backup-Status verifizieren
- Memory-Nutzung überwachen

### Wöchentlich

- Updates prüfen
- Disk-Space checken
- Session-Größen reviewen

### Monatlich

- Vollständiger Backup-Restore-Test
- Performance-Baseline aktualisieren
- Security-Updates einspielen

### Quartalsweise

- Disaster-Recovery-Übung
- Config-Review
- Dependency-Update

---

## Security-Hardening

### Container

```dockerfile
# Non-root User
USER 1000:1000

# Read-only Root
read_only: true

# Capabilities drop
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE
```

### Netzwerk

```yaml
# Docker-Compose Netzwerk-Isolierung
networks:
  internal:
    internal: true  # Kein externer Zugriff
  external:
    driver: bridge
```

### Secrets

```bash
# Keine Secrets in Env
# Stattdessen: Docker Secrets oder 1Password

echo "api-key" | docker secret create openclaw_api_key -
```

---

## Scaling

### Horizontales Scaling

```yaml
# docker-compose.scale.yml
version: '3.8'
services:
  openclaw-1:
    image: openclaw/openclaw:latest
    ports:
      - "18789:18789"
  
  openclaw-2:
    image: openclaw/openclaw:latest
    ports:
      - "18790:18789"
  
  nginx:
    image: nginx:alpine
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    ports:
      - "80:80"
```

### Load Balancing

```nginx
# nginx.conf
upstream openclaw {
    least_conn;
    server openclaw-1:18789;
    server openclaw-2:18789;
}

server {
    location / {
        proxy_pass http://openclaw;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

## Runbooks

### Gateway startet nicht

```bash
# 1. Logs checken
docker logs openclaw --tail 50

# 2. Config validieren
docker exec openclaw openclaw config validate

# 3. Port freigeben
sudo lsof -ti:18789 | xargs kill -9

# 4. Neustart
docker-compose restart
```

### Memory-Überlauf

```bash
# 1. Sessions bereinigen
docker exec openclaw find /data/sessions -mtime +7 -delete

# 2. Memory vacuum
docker exec openclaw sqlite3 /data/memory/main.sqlite "VACUUM;"

# 3. Container-Restart
docker-compose restart openclaw
```

### LLM-Provider down

```bash
# 1. Fallback-Provider aktivieren
# In openclaw.json: secondary model konfigurieren

# 2. Circuit breaker prüfen
docker exec openclaw openclaw health

# 3. Manuelles Testing
curl https://api.anthropic.com/v1/health
```

---

## Dokumentation

| Ressource | URL |
|-----------|-----|
| Offizielle Docs | https://docs.openclaw.ai/ |
| GitHub | https://github.com/openclaw/openclaw |
| Discord Ops | #ops Kanal |
