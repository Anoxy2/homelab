# OpenClaw – Quick Start Guide

> Schnellstart für macOS, Linux & Windows  
> Stand: April 2026 · Quelle: [openclaw.ai](https://openclaw.ai/)

---

## Download & Installation

### macOS

```bash
# One-liner Installation (installiert Node.js + alles andere)
curl -fsSL https://openclaw.ai/install.sh | bash

# Oder manuell von GitHub Releases
cd /Applications
git clone https://github.com/openclaw/openclaw.git
cd openclaw
npm install
```

→ [Latest Release](https://github.com/openclaw/openclaw/releases/latest)

### Linux (Ubuntu/Debian/Raspberry Pi)

```bash
# One-liner
curl -fsSL https://openclaw.ai/install.sh | bash

# Docker (empfohlen für Server/Pi)
git clone https://github.com/openclaw/openclaw.git
cd openclaw
docker-compose up -d
```

### Windows

```powershell
# PowerShell one-liner
irm https://openclaw.ai/install.ps1 | iex

# Oder manuell
git clone https://github.com/openclaw/openclaw.git
cd openclaw
npm install
```

---

## Erste Schritte

### 1. Konfiguration

```bash
# Config-Verzeichnis erstellen
mkdir -p ~/.config/openclaw

# Config-Datei kopieren
cp config.example.json ~/.config/openclaw/openclaw.json
```

### 2. API-Keys eintragen

```json
// ~/.config/openclaw/openclaw.json
{
  "llm": {
    "provider": "anthropic",
    "apiKey": "sk-ant-api03-..."
  },
  "channels": {
    "telegram": {
      "token": "YOUR_BOT_TOKEN"
    }
  }
}
```

### 3. Starten

```bash
# Direkt
npm start

# Mit Docker
docker-compose up -d

# Status prüfen
docker ps | grep openclaw
```

---

## Erste Nachricht

### Via Telegram

1. Bot-Token von @BotFather holen
2. In Config eintragen
3. Bot starten: `npm start`
4. Im Telegram: `/start` schreiben

### Via Discord

1. Discord Developer Portal → New Application
2. Bot-Token kopieren
3. Config eintragen
4. Bot invite-Link generieren

### Via Terminal

```bash
# Direkter Test
docker exec openclaw openclaw agent --message "Hallo OpenClaw!"
```

---

## Schnelle Aufgaben

### "Was kannst du alles?"

```
Du: Was kannst du alles?
Claw: Ich kann E-Mails schreiben, deinen Kalender verwalten, 
       Webseiten durchsuchen, Dateien lesen/schreiben, 
       Shell-Befehle ausführen...
```

### Erste Skill-Erstellung

```
Du: Create a skill for Todoist integration
Claw: [Erstellt SKILL.md, implementiert API-Calls, 
       testet Integration]
```

### Browser-Automation

```
Du: Suche nach Flügen von Berlin nach Paris nächste Woche
Claw: [Öffnet Browser, sucht Flüge, extrahiert Daten]
```

---

## Konfiguration (detailliert)

### openclaw.json

```json
{
  "gateway": {
    "bind": "lan",
    "port": 18789
  },
  "agents": {
    "defaults": {
      "workspace": "/home/user/agent",
      "heartbeat": {
        "every": "30m"
      },
      "model": {
        "primary": "github-copilot/gpt-4.1"
      }
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "..."
    },
    "discord": {
      "enabled": false,
      "token": "..."
    }
  },
  "hooks": {
    "token": "webhook-secret-token"
  }
}
```

---

## Raspberry Pi Setup

### Cloudflare Tunnel

```bash
# Cloudflare installieren
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64
cp cloudflared-linux-arm64 /usr/local/bin/cloudflared

# Tunnel erstellen
cloudflared tunnel create openclaw

# Config
cloudflared tunnel route dns <tunnel-id> openclaw.yourdomain.com
```

### Docker Compose

```yaml
version: '3.8'
services:
  openclaw:
    image: openclaw/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    ports:
      - "18789:18789"
    volumes:
      - ./data:/data
      - ./agent:/agent
    environment:
      - OPENCLAW_CONFIG=/data/openclaw.json
```

---

## Verifizierung

### Test-Befehle

```bash
# Status check
docker exec openclaw openclaw status

# Agent direkt ansprechen
docker exec openclaw openclaw agent --message "ping" --json

# Webhook testen
curl -X POST http://localhost:18789/hooks/test \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"message": "test"}'
```

---

## Nächste Schritte

### Lernpfad

1. **Tag 1**: Grundsetup, erste Chat-Interaktion
2. **Tag 2**: Ein Skill installieren (z.B. `clawhub install whoop`)
3. **Tag 3**: Eigenen Skill entwickeln lassen
4. **Tag 4**: Webhooks für Automation einrichten
5. **Tag 5**: Heartbeat-Tasks konfigurieren

### Ressourcen

- [Vollständige Dokumentation](https://docs.openclaw.ai/)
- [Discord Community](https://discord.com/invite/clawd)
- [GitHub Discussions](https://github.com/openclaw/openclaw/discussions)
- [ClawHub Skills](https://clawhub.ai)

---

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| Port 18789 belegt | `lsof -i :18789` dann `kill <pid>` |
| API-Key ungültig | Key in Config prüfen, neu generieren |
| Telegram nicht verbunden | Webhook-URL setzen, Bot-Token prüfen |
| Docker startet nicht | `docker logs openclaw` |
| Keine Antwort | LLM-Provider-Quota prüfen |

---

## Tipps für Einsteiger

> *"Me reading about @openclaw: 'this looks complicated' 😅 me 30 mins later: controlling Gmail, Calendar, WordPress, Hetzner from Telegram like a boss."* — @Abhay08

1. **Starte einfach** – Nur ein Kanal (Telegram) aktivieren
2. **Frag nach** – "Was brauchst du für X?"
3. **Lass bauen** – Skills selbst erstellen lassen
4. **Experimentiere** – Es gibt kein "falsch"
5. **Community nutzen** – Discord für Fragen
