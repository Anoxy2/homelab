# OpenClaw – API Referenz

> Vollständige API-Dokumentation für Gateway, CLI und Webhooks  
> Stand: April 2026 · Quelle: [docs.openclaw.ai](https://docs.openclaw.ai/)

---

## Gateway API (WebSocket)

### Endpunkte (Port 18789)

| Pfad | Methode | Zweck |
|------|---------|-------|
| `/` | GET | SPA Control UI (HTML) |
| `/status` | GET | Status-Weiterleitung (HTML) |
| `/hooks/<path>` | POST | Webhook-Trigger (mit Bearer-Token) |
| `ws://host:18789` | WebSocket | Primärer Kommunikationskanal |

> **Hinweis:** Kein REST-API auf `/api/*` – Kommunikation läuft ausschließlich über WebSocket.

---

## WebSocket Protokoll

### Verbindungssequenz

#### 1. Challenge Request

Server sendet nach Verbindungsaufbau:

```json
{
  "type": "event",
  "event": "connect.challenge",
  "payload": {
    "nonce": "<uuid>",
    "ts": 1712345678901
  }
}
```

#### 2. Connect Response

Client antwortet mit signiertem Frame:

```json
{
  "type": "req",
  "id": "conn-001",
  "method": "connect",
  "params": {
    "minProtocol": 3,
    "maxProtocol": 3,
    "client": {
      "id": "cli",
      "version": "1.0.0",
      "platform": "linux",
      "mode": "cli"
    },
    "role": "operator",
    "scopes": ["operator.read", "operator.write"],
    "auth": {
      "token": "<operator-token>"
    },
    "device": {
      "id": "<deviceId>",
      "publicKey": "<base64-raw-Ed25519-pubkey>",
      "signature": "<base64-Ed25519-sig>",
      "signedAt": 1712345678901,
      "nonce": "<nonce-aus-challenge>"
    }
  }
}
```

#### 3. Success Response

```json
{
  "type": "res",
  "id": "conn-001",
  "ok": true,
  "result": {
    "protocol": 3,
    "sessionId": "sess-abc123",
    "agentId": "main"
  }
}
```

### Message Frame Format

#### Request

```json
{
  "type": "req",
  "id": "req-001",
  "method": "agent.message",
  "params": {
    "agent": "main",
    "message": "Was ist der Status?",
    "sessionId": "claude-ops"
  }
}
```

#### Response

```json
{
  "type": "res",
  "id": "req-001",
  "ok": true,
  "result": {
    "runId": "run-xyz789",
    "status": "ok",
    "summary": "completed",
    "result": {
      "payloads": [
        {
          "text": "Alle Systeme laufen normal.",
          "mediaUrl": null
        }
      ],
      "meta": {
        "durationMs": 2345,
        "agentMeta": {
          "sessionId": "sess-abc123",
          "provider": "github-copilot",
          "model": "gpt-4.1",
          "usage": {
            "input": 1500,
            "output": 45,
            "total": 1545
          }
        }
      }
    }
  }
}
```

---

## CLI API

### Basis-Befehle

```bash
# Agent ansprechen (JSON-Output)
openclaw agent --agent <name> --message "<text>" --json

# Agent ansprechen (Plain text)
openclaw agent --agent <name> --message "<text>"

# An bestimmte Session senden
openclaw agent --to <session-id> --message "<text>" --deliver

# Mit Thinking-Level
openclaw agent --agent <name> --message "<text>" --thinking medium --json
```

### Agent-Verwaltung

```bash
# Alle Agenten listen
openclaw agents list

# Agenten-Details
openclaw agents info <name>

# Agent erstellen
openclaw agents create <name> --template <template>

# Agent löschen
openclaw agents delete <name>
```

### System-Befehle

```bash
# Status-Übersicht
openclaw status

# Konfiguration anzeigen
openclaw config

# Plugins listen
openclaw plugins list

# Skills installieren
openclaw plugins install <name>

# Skill deinstallieren
openclaw plugins uninstall <name>
```

### Docker-Integration

```bash
# Via Docker exec
docker exec openclaw openclaw agent --agent main --message "Hallo"

# Mit Umgebungsvariablen
docker exec -e OPENCLAW_DEBUG=1 openclaw openclaw status
```

---

## Webhook API

### Konfiguration

Webhooks werden in `openclaw.json` konfiguriert:

```json
{
  "hooks": {
    "token": "secure-webhook-token",
    "mappings": [
      {
        "path": "growbox-alert",
        "target": "agent",
        "agent": "main",
        "message": "🚨 Growbox Alert: {{message}}"
      }
    ]
  }
}
```

### Trigger Webhook

```bash
curl -X POST http://192.168.2.101:18789/hooks/<path> \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Benutzerdefinierte Nachricht",
    "entity_id": "sensor.temperatur",
    "state": "28.5"
  }'
```

### Response Format

```json
{
  "ok": true,
  "hookId": "hook-001",
  "triggered": "2026-04-10T12:00:00Z",
  "runId": "run-abc123"
}
```

### Fehler-Handling

| Status | Bedeutung |
|--------|-----------|
| `200 OK` | Webhook erfolgreich verarbeitet |
| `401 Unauthorized` | Ungültiger oder fehlender Token |
| `404 Not Found` | Webhook-Pfad nicht konfiguriert |
| `429 Too Many Requests` | Rate-Limit überschritten |
| `500 Server Error` | Interner Fehler |

---

## Chat-Bridge API (HTTP)

### Endpunkt

```
POST http://openclaw.lan/api/chat
```

### Request

```json
{
  "message": "Deine Nachricht an den Agenten",
  "sessionId": "optional-session-id",
  "context": {
    "source": "canvas-ui"
  }
}
```

### Response

```json
{
  "reply": "Antwort des Agenten",
  "runId": "run-abc123",
  "durationMs": 3456
}
```

### cURL Beispiel

```bash
curl -X POST http://openclaw.lan/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Was ist die Temperatur?"}'
```

---

## Native Skills API

### Skill-Ausführung

```bash
# Direkter Aufruf
openclaw skill run <skill-name> --input '<json-input>'

# Mit Datei
openclaw skill run <skill-name> --input-file ./input.json
```

### Skill-Entwicklung

#### SKILL.md Format

```markdown
# Skill Name

## Description
Kurze Beschreibung des Skills.

## Tools

### toolName

Description: Was das Tool macht

Parameters:
- param1: string (required) - Beschreibung
- param2: number (optional) - Beschreibung

Handler:
```javascript
export default async function handler(params, context) {
  // Implementation
  return { result: "success" };
}
```

## Installation
```bash
npm install @openclaw/skill-name
```
```

---

## Memory API

### Search

```bash
# Volltextsuche
openclaw memory search "query" --limit 10

# Semantische Suche
openclaw memory search "query" --semantic --threshold 0.7

# Hybrid (Keyword + Vector)
openclaw memory search "query" --hybrid
```

### CRUD Operationen

```bash
# Speichern
openclaw memory set <key> <value>

# Lesen
openclaw memory get <key>

# Löschen
openclaw memory delete <key>

# Liste
openclaw memory list --prefix "user."
```

---

## Fehler-Codes

| Code | Bedeutung | Lösung |
|------|-----------|--------|
| `AUTH_INVALID_TOKEN` | Ungültiger Token | Token erneuern |
| `AUTH_INVALID_SIGNATURE` | Signatur-Fehler | Device-Keys prüfen |
| `AGENT_NOT_FOUND` | Agent existiert nicht | Agent-Namen prüfen |
| `SESSION_EXPIRED` | Session abgelaufen | Neue Session starten |
| `RATE_LIMITED` | Zu viele Requests | Warten und retry |
| `LLM_TIMEOUT` | LLM antwortet nicht | Provider-Status prüfen |
| `TOOL_ERROR` | Tool-Ausführung fehlgeschlagen | Logs prüfen |

---

## Rate Limiting

| Endpunkt | Limit | Window |
|----------|-------|--------|
| WebSocket (Message) | 100/min | 1 Minute |
| Webhooks | 10/min | 1 Minute |
| Chat-Bridge | 60/min | 1 Minute |
| Memory Search | 300/hour | 1 Stunde |

---

## SDKs & Libraries

### Offizielle

| Sprache | Paket | URL |
|---------|-------|-----|
| **JavaScript/Node** | `@openclaw/sdk` | npm |
| **Python** | `openclaw-sdk` | PyPI |
| **Go** | `github.com/openclaw/go-sdk` | GitHub |

### Community

| Sprache | Maintainer | Status |
|---------|------------|--------|
| **Rust** | Community | Beta |
| **Ruby** | Community | Alpha |

---

## API-Versionierung

| Version | Status | Deprecation |
|-----------|--------|-------------|
| **v3** | Aktuell | – |
| **v2** | Legacy | 2026-06-01 |
| **v1** | Deprecated | Nicht mehr unterstützt |

---

## Changelog

### 2026-04-10
- WebSocket Protocol v3 stabil
- VirusTotal Integration für Skills

### 2026-04-01
- Chat-Bridge API released
- Rate Limiting verbessert
