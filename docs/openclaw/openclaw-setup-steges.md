# OpenClaw – Steges' Setup Guide (Pi/Docker)

> Spezifische Details für dein Homelab-Setup mit Raspberry Pi + Docker  
> Stand: April 2026 · Basierend auf aktuellen GitHub/Docs-Infos

---

## Dein Aktuelles Setup (Bestandsaufnahme)

### Aus deiner bestehenden Architektur:

| Komponente | Bei dir | Standard OpenClaw |
|------------|---------|-------------------|
| **Host** | Raspberry Pi (192.168.2.101) | Mac/Windows/Linux/Pi |
| **Runtime** | Docker Container | Node 24 direkt oder Docker |
| **Config** | `infra/openclaw-data/openclaw.json` | `~/.openclaw/openclaw.json` |
| **Workspace** | `/home/steges/agent/` | `~/.openclaw/workspace` |
| **Memory** | `infra/openclaw-data/memory/main.sqlite` | `~/.openclaw/memory/main.sqlite` |
| **Port** | 18789 (Gateway) | 18789 (Standard) |
| **CLI** | `docker exec openclaw openclaw ...` | `openclaw ...` (nativ) |

### Deine Custom-Komponenten:

- **Chat-Bridge** (`127.0.0.1:18792`) → HTTP-Bridge für Canvas-UI
- **Skill-Forge** (`~/scripts/skill-forge`) → Dein Custom Skill-Management
- **Heartbeat-System** → systemd-Timer (07:00/19:00) parallel zu nativem Heartbeat

---

## Migration auf modernes OpenClaw (Empfohlen)

### Option 1: Native Installation (Empfohlen für Pi)

**Vorteile:**
- Direkte Node.js-Performance (kein Docker-Overhead)
- Einfacheres Debugging
- Besserer Ressourcenverbrauch auf Pi

```bash
# Node 24 installieren (falls nicht vorhanden)
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt-get install -y nodejs

# OpenClaw global installieren
npm install -g openclaw@latest

# Onboarding (automatisch Daemon installieren)
openclaw onboard --install-daemon

# Gateway manuell starten (für Test)
openclaw gateway --port 18789 --verbose
```

### Option 2: Modernes Docker (Beibehalten)

```yaml
# docker-compose.yml (modern)
version: '3.8'
services:
  openclaw:
    image: openclaw/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    ports:
      - "18789:18789"
      - "8090:8090"  # Canvas UI (optional)
    volumes:
      - openclaw-data:/data
      - ./agent:/agent:ro  # Dein Workspace
    environment:
      - OPENCLAW_CONFIG=/data/openclaw.json
      - OPENCLAW_LOG_LEVEL=info
      # Wichtig für Pi:
      - NODE_OPTIONS=--max-old-space-size=1536
    networks:
      - openclaw-net
    # Pi-Optimierungen
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 512M

  # Deine Chat-Bridge
  chat-bridge:
    image: python:3.11-slim
    container_name: chat-bridge
    restart: unless-stopped
    ports:
      - "127.0.0.1:18792:18792"
    volumes:
      - ./scripts/chat-bridge.py:/app/chat-bridge.py:ro
    command: python /app/chat-bridge.py
    networks:
      - openclaw-net
    depends_on:
      - openclaw

volumes:
  openclaw-data:

networks:
  openclaw-net:
    driver: bridge
```

---

## Konfiguration für deinen Pi

### Minimal openclaw.json (funktioniert sofort)

```json
{
  "agent": {
    "model": "github-copilot/gpt-4.1"
  },
  "gateway": {
    "bind": "192.168.2.101",
    "port": 18789,
    "controlUi": {
      "enabled": true
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "YOUR_BOT_TOKEN"
    }
  }
}
```

### Erweitert (mit allem was du brauchst)

```json
{
  "agent": {
    "model": "github-copilot/gpt-4.1",
    "thinkingLevel": "medium",
    "sandbox": {
      "mode": "non-main"
    }
  },
  "gateway": {
    "bind": "192.168.2.101",
    "port": 18789,
    "controlUi": {
      "enabled": true,
      "root": "/home/steges/agent/skills/openclaw-ui/html"
    },
    "tailscale": {
      "mode": "off"
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/home/steges/agent",
      "heartbeat": {
        "every": "30m"
      }
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "${TELEGRAM_BOT_TOKEN}",
      "dmPolicy": "pairing"
    }
  },
  "hooks": {
    "token": "${OPENCLAW_WEBHOOK_TOKEN}",
    "mappings": [
      {
        "path": "growbox-alert",
        "target": "agent",
        "agent": "main",
        "message": "🚨 Growbox: {{message}}"
      },
      {
        "path": "esp32-offline",
        "target": "agent",
        "agent": "main"
      }
    ]
  }
}
```

---

## LLM-Provider für Pi (Kosten & Performance)

### Kosten-Übersicht (pro 1M Tokens)

| Provider | Modell | Input | Output | Speed | Pi-Tauglich |
|----------|--------|-------|--------|-------|-------------|
| **GitHub Copilot** | GPT-4.1 | $0.50 | $1.50 | 🚀 Schnell | ✅ Empfohlen |
| **Anthropic** | Claude 3.5 Sonnet | $3.00 | $15.00 | ⚡ Mittel | ✅ Gut |
| **OpenAI** | GPT-4o | $2.50 | $10.00 | ⚡ Mittel | ✅ Gut |
| **Groq** | Llama 3.3 70B | $0.59 | $0.79 | 🚀🚀 Extrem schnell | ✅ Budget |
| **Local (Ollama)** | Llama 3.1 8B | $0 | $0 | 🐢 Langsam | ✅ Offline |

### Empfohlene Kombination (Failover)

```json
{
  "agent": {
    "model": "github-copilot/gpt-4.1",
    "fallbackModels": [
      "groq/llama-3.3-70b-versatile",
      "anthropic/claude-3-5-sonnet-20241022"
    ]
  }
}
```

### Lokale Modelle auf Pi (Experimentell)

```bash
# Ollama installieren
curl -fsSL https://ollama.com/install.sh | sh

# Kleines Modell für Pi
ollama pull llama3.1:8b

# In OpenClaw config
{
  "agent": {
    "model": "ollama/llama3.1:8b",
    "baseUrl": "http://localhost:11434"
  }
}
```

> ⚠️ **Warnung:** Llama 3.1 8B ist deutlich schwächer als GPT-4.1. Tool-Usage kann unzuverlässig sein.

---

## Ressourcen-Optimierung für Pi

### Memory-Limitierungen

```bash
# Docker-Compose memory limits
deploy:
  resources:
    limits:
      memory: 2G
    reservations:
      memory: 512M

# Node.js memory flag
environment:
  - NODE_OPTIONS=--max-old-space-size=1536
```

### Session-Pruning (wichtig!)

```json
{
  "agents": {
    "defaults": {
      "sessionPruning": {
        "enabled": true,
        "maxAge": "7d",
        "maxSessions": 10
      }
    }
  }
}
```

### SQLite-Optimierung

```bash
# Vacuum für Memory-DB (einmal pro Woche)
docker exec openclaw sqlite3 /data/memory/main.sqlite "VACUUM;"

# In crontab
0 3 * * 0 /home/steges/scripts/vacuum-memory.sh
```

---

## Deine Chat-Bridge migrieren

### Aktuelle Lösung (beibehalten)

Dein `chat-bridge.py` funktioniert weiterhin. Nur der interne Call ändert sich leicht:

```python
# ALT (dein aktueller Code)
subprocess.run([
    "docker", "exec", "openclaw",
    "openclaw", "agent", "--agent", "main",
    "--message", message, "--json"
])

# NEU (moderne CLI)
subprocess.run([
    "docker", "exec", "openclaw",
    "openclaw", "agent", "--message", message, "--json"
])
# --agent main ist jetzt default
```

### Alternative: Native WebSocket

Für bessere Performance direkt über WebSocket:

```python
# Beispiel: WebSocket-Client für OpenClaw
import websockets
import json

async def send_via_websocket(message):
    uri = "ws://192.168.2.101:18789"
    async with websockets.connect(uri) as ws:
        # Auth-Handshake (siehe API-Doku)
        # ... challenge-response ...
        
        await ws.send(json.dumps({
            "type": "req",
            "method": "agent.message",
            "params": {"message": message}
        }))
        response = await ws.recv()
        return json.loads(response)
```

---

## Chat-Befehle (Neu!)

OpenClaw unterstützt jetzt native Chat-Kommandos:

| Befehl | Funktion | Wer kann's |
|--------|----------|------------|
| `/status` | Session-Status + Token-Usage | Alle |
| `/new` oder `/reset` | Session zurücksetzen | Alle |
| `/compact` | Kontext komprimieren | Alle |
| `/think <level>` | Thinking-Level ändern | Alle |
| `/verbose on/off` | Ausführlichkeit togglen | Alle |
| `/usage off/tokens/full` | Usage-Footer steuern | Alle |
| `/restart` | Gateway neustarten | Owner only (Gruppen) |
| `/activation mention/always` | Gruppen-Aktivierung | Owner only |
| `/elevated on/off` | Elevated bash togglen | Owner only |

> **Wichtig:** In Gruppen sind Owner-Only-Befehle auf den Chat-Owner beschränkt.

---

## DM-Sicherheit (Pairing)

### Standard-Policy (empfohlen)

```json
{
  "channels": {
    "telegram": {
      "dmPolicy": "pairing",
      "allowFrom": []
    }
  }
}
```

**Ablauf:**
1. Unbekannter User schreibt Bot
2. Bot sendet Pairing-Code
3. Du führst aus: `openclaw pairing approve telegram <code>`
4. User ist auf Allowlist

### Für deinen Setup (bereits bekannte User)

```json
{
  "channels": {
    "telegram": {
      "dmPolicy": "open",
      "allowFrom": ["2011062206"]  // Deine Telegram-ID
    }
  }
}
```

---

## Monitoring & Debugging

### Neu: `openclaw doctor`

```bash
# System-Check (nativ)
openclaw doctor

# In Docker
docker exec openclaw openclaw doctor
```

Prüft:
- ✅ Config-Validität
- ✅ Gateway-Status
- ✅ Channel-Verbindungen
- ✅ Model-Auth
- ✅ Security-Einstellungen

### Logging

```bash
# Echtzeit-Logs
docker logs -f openclaw --tail 100

# Mit Filter
docker logs openclaw 2>&1 | grep -i error

# Log-Level ändern
# in openclaw.json:
{
  "logging": {
    "level": "debug"  // error, warn, info, debug
  }
}
```

### Health-Checks

```bash
# Gateway-Status
curl http://192.168.2.101:18789/status

# CLI-Status
docker exec openclaw openclaw gateway status

# Agent-Test
docker exec openclaw openclaw agent --message "ping"
```

---

## Update-Strategie

### Automatisch (empfohlen für Pi)

```bash
# Cronjob für wöchentliche Updates
# crontab -e
0 4 * * 0 cd /home/steges/infra && docker-compose pull && docker-compose up -d
```

### Manuell mit Test

```bash
# 1. Backup
~/scripts/backup.sh

# 2. Update
docker-compose pull
docker-compose up -d

# 3. Verifizierung
docker exec openclaw openclaw doctor
~/agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh

# 4. Rollback (bei Fehler)
docker-compose down
docker-compose up -d --build
```

---

## Umgebungsvariablen

| Variable | Zweck | Beispiel |
|----------|-------|----------|
| `OPENCLAW_HOME` | Home-Verzeichnis | `/home/steges/.openclaw` |
| `OPENCLAW_STATE_DIR` | State-Override | `/home/steges/infra/openclaw-data` |
| `OPENCLAW_CONFIG_PATH` | Config-Override | `/home/steges/infra/openclaw-data/openclaw.json` |
| `NODE_OPTIONS` | Node-Flags | `--max-old-space-size=1536` |
| `OPENCLAW_LOG_LEVEL` | Logging | `info` / `debug` |

---

## Troubleshooting deines Setups

### Problem: Gateway startet nicht

```bash
# Port prüfen
sudo lsof -i :18789

# Berechtigungen
docker exec openclaw ls -la /data/

# Config validieren
docker exec openclaw openclaw doctor
```

### Problem: Langsame Antworten

```bash
# Model-Wechsel testen
docker exec openclaw openclaw agent \
  --message "test" \
  --model groq/llama-3.3-70b-versatile

# Memory-Check
docker stats openclaw --no-stream
```

### Problem: Telegram nicht verbunden

```bash
# Webhook prüfen
curl https://api.telegram.org/bot<TOKEN>/getWebhookInfo

# Logs
docker logs openclaw | grep -i telegram
```

---

## Migration: To-Do-Liste

- [ ] Backup aktueller Config erstellen
- [ ] Neue `docker-compose.yml` erstellen
- [ ] `openclaw.json` auf neues Format migrieren
- [ ] Chat-Bridge anpassen (CLI-Parameter)
- [ ] Test: `openclaw doctor`
- [ ] Test: Telegram-Message
- [ ] Test: Webhook-Trigger
- [ ] Test: RAG-Skill
- [ ] Alte Container löschen (nach 1 Woche)

---

## Links

- [GitHub](https://github.com/openclaw/openclaw)
- [Offizielle Docs](https://docs.openclaw.ai/)
- [Configuration Reference](https://docs.openclaw.ai/gateway/configuration)
- [Docker Install](https://docs.openclaw.ai/install/docker)
- [Deine Architektur-Doku](openclaw-architecture.md)
