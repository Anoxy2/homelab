# OpenClaw – Konfigurations-Referenz (Alle Parameter)

> Vollständige Referenz aller openclaw.json Parameter  
> Stand: April 2026

---

## Übersicht

```json
{
  "agent": {...},           // Agent-Verhalten
  "agents": {...},          // Multi-Agent Config
  "gateway": {...},         // Gateway-Einstellungen
  "channels": {...},        // Chat-Integrationen
  "hooks": {...},           // Webhooks
  "logging": {...},         // Logging
  "skills": {...}           // Skill-Config
}
```

---

## 1. Agent-Config

### Basis

```json
{
  "agent": {
    "model": "github-copilot/gpt-4.1",
    "thinkingLevel": "medium",
    "verbose": false,
    "apiKey": "${API_KEY}"
  }
}
```

| Parameter | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `model` | string | required | Provider/Modell |
| `thinkingLevel` | enum | "medium" | off/minimal/low/medium/high/xhigh |
| `verbose` | boolean | false | Ausführliche Logs |
| `apiKey` | string | null | API-Key (oder Env) |
| `baseUrl` | string | null | Custom Endpoint |
| `timeout` | number | 60000 | Request-Timeout (ms) |

### Fallback

```json
{
  "agent": {
    "fallbackModels": [
      "groq/llama-3.3-70b-versatile",
      "anthropic/claude-3-5-sonnet-20241022"
    ],
    "failover": {
      "onError": true,
      "onTimeout": true,
      "timeout": 30000
    }
  }
}
```

| Parameter | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `fallbackModels` | array | [] | Backup-Modelle |
| `failover.onError` | boolean | true | Bei Error wechseln |
| `failover.onTimeout` | boolean | true | Bei Timeout wechseln |
| `failover.timeout` | number | 30000 | Timeout-Threshold |

### Retry

```json
{
  "agent": {
    "retry": {
      "maxAttempts": 3,
      "backoff": "exponential",
      "initialDelay": 1000,
      "maxDelay": 30000
    }
  }
}
```

| Parameter | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `maxAttempts` | number | 3 | Max Versuche |
| `backoff` | enum | "exponential" | linear/exponential |
| `initialDelay` | number | 1000 | Start-Delay (ms) |
| `maxDelay` | number | 30000 | Max Delay (ms) |

### Caching (Anthropic)

```json
{
  "agent": {
    "promptCaching": {
      "enabled": true,
      "checkpointEvery": 5
    }
  }
}
```

---

## 2. Multi-Agent Config

```json
{
  "agents": {
    "defaults": {
      "workspace": "/home/steges/agent",
      "heartbeat": {
        "enabled": true,
        "every": "30m"
      },
      "sessionPruning": {
        "enabled": true,
        "maxAge": "7d",
        "maxSessions": 10
      },
      "sandbox": {
        "mode": "non-main",
        "allowlist": ["bash", "read", "write"],
        "denylist": ["browser", "cron"]
      }
    },
    "list": [
      {
        "id": "main",
        "name": "Molty",
        "model": "github-copilot/gpt-4.1"
      },
      {
        "id": "coding",
        "name": "Coder",
        "model": "anthropic/claude-3-5-sonnet-20241022"
      }
    ]
  }
}
```

### Defaults

| Parameter | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `workspace` | string | "~/.openclaw/workspace" | Agent-Workspace |
| `heartbeat.enabled` | boolean | true | Heartbeat aktiv |
| `heartbeat.every` | string | "30m" | Intervall (ms/s/m/h/d) |
| `sessionPruning.enabled` | boolean | true | Alte Sessions löschen |
| `sessionPruning.maxAge` | string | "7d" | Max Alter |
| `sessionPruning.maxSessions` | number | 10 | Max Sessions |
| `sandbox.mode` | enum | "none" | none/non-main/all |
| `sandbox.allowlist` | array | [] | Erlaubte Tools |
| `sandbox.denylist` | array | [] | Verbotene Tools |

---

## 3. Gateway-Config

```json
{
  "gateway": {
    "bind": "192.168.2.101",
    "port": 18789,
    "controlUi": {
      "enabled": true,
      "root": "/home/steges/agent/skills/openclaw-ui/html"
    },
    "auth": {
      "mode": "token",
      "allowTailscale": true
    },
    "tailscale": {
      "mode": "off",
      "resetOnExit": false
    },
    "webChat": {
      "enabled": true
    }
  }
}
```

### Netzwerk

| Parameter | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `bind` | string | "127.0.0.1" | Bind-Adresse |
| `port` | number | 18789 | Port |
| `host` | string | null | Override Host |

### Control UI

| Parameter | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `enabled` | boolean | true | UI aktiv |
| `root` | string | null | Custom Path |

### Auth

| Parameter | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `mode` | enum | "token" | token/password |
| `allowTailscale` | boolean | true | Tailscale-Auth erlauben |

### Tailscale

| Parameter | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `mode` | enum | "off" | off/serve/funnel |
| `resetOnExit` | boolean | false | Beim Beenden resetten |

**Modes:**
- `off`: Kein Tailscale
- `serve`: Tailnet-only HTTPS
- `funnel`: Public HTTPS (requires `auth.mode: password`)

---

## 4. Channel-Config

### Telegram

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "${TELEGRAM_BOT_TOKEN}",
      "dmPolicy": "pairing",
      "allowFrom": ["2011062206"],
      "groupActivation": "mention",
      "chunkSize": 4000
    }
  }
}
```

| Parameter | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `enabled` | boolean | false | Aktiv |
| `token` | string | required | Bot-Token |
| `dmPolicy` | enum | "pairing" | pairing/open |
| `allowFrom` | array | [] | Erlaubte User-IDs |
| `groupActivation` | enum | "mention" | mention/always |
| `chunkSize` | number | 4000 | Max Message-Size |

### Discord

```json
{
  "channels": {
    "discord": {
      "enabled": true,
      "token": "${DISCORD_BOT_TOKEN}",
      "dmPolicy": "pairing",
      "allowFrom": [],
      "guilds": ["guild-id-1"]
    }
  }
}
```

### WhatsApp (Baileys)

```json
{
  "channels": {
    "whatsapp": {
      "enabled": true,
      "sessionPath": "/data/whatsapp-session",
      "dmPolicy": "pairing"
    }
  }
}
```

### Slack

```json
{
  "channels": {
    "slack": {
      "enabled": true,
      "token": "${SLACK_BOT_TOKEN}",
      "signingSecret": "${SLACK_SIGNING_SECRET}",
      "dmPolicy": "pairing"
    }
  }
}
```

### Signal

```json
{
  "channels": {
    "signal": {
      "enabled": true,
      "cliPath": "/usr/bin/signal-cli",
      "account": "+1234567890"
    }
  }
}
```

### iMessage (BlueBubbles - empfohlen)

```json
{
  "channels": {
    "bluebubbles": {
      "enabled": true,
      "host": "192.168.2.50",
      "port": 3000,
      "password": "${BB_PASSWORD}"
    }
  }
}
```

---

## 5. Webhook-Config

```json
{
  "hooks": {
    "token": "${WEBHOOK_TOKEN}",
    "allowedIPs": ["192.168.2.0/24", "10.0.0.0/8"],
    "mappings": [
      {
        "path": "alert",
        "target": "agent",
        "agent": "main",
        "message": "🚨 {{message}}"
      },
      {
        "path": "homeassistant",
        "target": "webhook",
        "url": "http://homeassistant:8123/api/webhook/openclaw"
      }
    ]
  }
}
```

| Parameter | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `token` | string | required | Auth-Token |
| `allowedIPs` | array | [] | IP-Whitelist |
| `mappings` | array | [] | Hook-Mappings |

### Mapping-Parameter

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `path` | string | URL-Pfad |
| `target` | enum | agent/webhook |
| `agent` | string | Ziel-Agent (bei target=agent) |
| `message` | string | Template mit {{var}} |
| `url` | string | Ziel-URL (bei target=webhook) |

---

## 6. Logging-Config

```json
{
  "logging": {
    "level": "info",
    "format": "json",
    "outputs": [
      {
        "type": "console",
        "colorize": true
      },
      {
        "type": "file",
        "path": "/var/log/openclaw/app.log",
        "maxSize": "100m",
        "maxFiles": 5
      }
    ]
  }
}
```

| Parameter | Typ | Default | Beschreibung |
|-----------|-----|---------|--------------|
| `level` | enum | "info" | error/warn/info/debug/trace |
| `format` | enum | "json" | json/pretty |
| `outputs` | array | [console] | Log-Ziele |

---

## 7. Skill-Config

```json
{
  "skills": {
    "registry": {
      "clawhub": {
        "enabled": true,
        "url": "https://clawhub.com"
      }
    },
    "installGating": {
      "enabled": true,
      "requireApproval": true
    },
    "autoInstall": {
      "enabled": false,
      "trustedAuthors": ["openclaw", "steges"]
    }
  }
}
```

---

## 8. Vollständiges Beispiel

```json
{
  "agent": {
    "model": "github-copilot/gpt-4.1",
    "thinkingLevel": "medium",
    "fallbackModels": ["groq/llama-3.3-70b-versatile"],
    "retry": {
      "maxAttempts": 3,
      "backoff": "exponential"
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/home/steges/agent",
      "heartbeat": {
        "enabled": true,
        "every": "30m"
      },
      "sandbox": {
        "mode": "non-main",
        "allowlist": ["bash", "read", "write", "edit"],
        "denylist": ["browser", "cron"]
      }
    }
  },
  "gateway": {
    "bind": "192.168.2.101",
    "port": 18789,
    "controlUi": {
      "enabled": true,
      "root": "/home/steges/agent/skills/openclaw-ui/html"
    },
    "auth": {
      "mode": "token"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "${TELEGRAM_BOT_TOKEN}",
      "dmPolicy": "pairing",
      "allowFrom": ["2011062206"]
    }
  },
  "hooks": {
    "token": "${WEBHOOK_TOKEN}",
    "mappings": [
      {
        "path": "growbox-alert",
        "target": "agent",
        "agent": "main",
        "message": "🚨 {{message}}"
      }
    ]
  },
  "logging": {
    "level": "info"
  }
}
```

---

## 9. Environment Variables

| Variable | Beschreibung | Beispiel |
|----------|--------------|----------|
| `OPENCLAW_HOME` | Home-Verzeichnis | `/home/steges/.openclaw` |
| `OPENCLAW_STATE_DIR` | State-Override | `/home/steges/infra/openclaw-data` |
| `OPENCLAW_CONFIG_PATH` | Config-Override | `/home/steges/infra/openclaw.json` |
| `OPENCLAW_LOG_LEVEL` | Log-Level | `debug` |
| `NODE_OPTIONS` | Node-Flags | `--max-old-space-size=1536` |

---

## 10. CLI-Config-Commands

```bash
# Config anzeigen
openclaw config get

# Wert setzen
openclaw config set agent.model "groq/llama-3.3-70b-versatile"

# Wert löschen
openclaw config delete channels.discord

# Validieren
openclaw config validate

# Export
openclaw config export > backup-config.json

# Import
openclaw config import backup-config.json
```

---

## 11. Docker-spezifische Config

```yaml
# docker-compose.yml environment
environment:
  - OPENCLAW_CONFIG=/data/openclaw.json
  - OPENCLAW_STATE_DIR=/data
  - OPENCLAW_LOG_LEVEL=info
  - NODE_OPTIONS=--max-old-space-size=1536
  - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
  - WEBHOOK_TOKEN=${WEBHOOK_TOKEN}
```

---

## 12. Config-Validierung

```bash
# Nativ
openclaw config validate

# In Docker
docker exec openclaw openclaw config validate

# Mit Schema-Check
docker exec openclaw openclaw doctor
```

---

## 13. Troubleshooting Config

### "Invalid config"

```bash
# Schema-Validierung
docker exec openclaw openclaw config validate --verbose

# Fehlerhaften Key finden
docker exec openclaw openclaw doctor | grep -i config
```

### "Config not found"

```bash
# Suchpfade anzeigen
docker exec openclaw openclaw config paths

# Manuelles Laden
docker exec openclaw openclaw gateway --config /data/openclaw.json
```

### Secrets nicht geladen

```bash
# Env-Check
docker exec openclaw env | grep TOKEN

# In compose:
# .env-Datei muss im gleichen Verzeichnis wie docker-compose.yml sein
```
