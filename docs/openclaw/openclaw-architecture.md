# OpenClaw – Architektur, API & Betrieb

> Erstellt: 2026-04-06 · Umfassend überarbeitet: 2026-04-08 (Gateway-Protokoll, CLI, Chat-Bridge)

---

## Was OpenClaw ist

OpenClaw ist ein **lokal laufender, selbständiger KI-Agent** (Node.js, Port 18789), der über Chat-Kanäle (Telegram, Discord, WhatsApp etc.) bedienbar ist. Er führt eigenständig Aufgaben aus ("AI that actually does things"). Kein Cloud-Silo – Daten bleiben auf dem Pi.

---

## Architektur-Überblick

```
┌─────────────────────────────────────────────────┐
│  Chat-Kanäle (Telegram, Discord, ...)           │
└────────────────────┬────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────┐
│  OpenClaw Gateway (ws://0.0.0.0:18789)          │
│  Node.js · openclaw.mjs                         │
│  Config: infra/openclaw-data/openclaw.json       │
├─────────────────────────────────────────────────┤
│  Agent Runtime                                  │
│  ├─ Context Engine (Compaction, Memory Flush)   │
│  ├─ System Prompt Assembly                      │
│  │   AGENTS.md, SOUL.md, TOOLS.md,              │
│  │   HEARTBEAT.md, MEMORY.md (main only)        │
│  ├─ Session Store (agents/main/sessions/*.jsonl) │
│  └─ Tasks Runner (tasks/runs.sqlite)            │
├─────────────────────────────────────────────────┤
│  Native Memory (memory/main.sqlite)             │
│  Tools: memory_search (Vector+Keyword), memory_get│
├─────────────────────────────────────────────────┤
│  Extensions (~70 Plugins)                       │
│  LLM: anthropic, github-copilot, openai, groq   │
│  Channels: telegram, discord, slack, signal …   │
│  Speech: deepgram, elevenlabs                   │
├─────────────────────────────────────────────────┤
│  Native Skills (~35 Skills)                     │
│  clawflow, coding-agent, skill-creator,          │
│  clawhub, healthcheck, node-connect, …          │
└─────────────────────────────────────────────────┘

Canvas-UI-Chat (ops.lan:8090)
  └── POST openclaw.lan/api/chat
        └── Caddy Route → Chat-Bridge (127.0.0.1:18792)
              └── docker exec openclaw openclaw agent --agent main --json
```

---

## Gateway: Protokoll (WebSocket)

Das Gateway kommuniziert **ausschließlich über WebSocket** (kein REST API), Port 18789.

### Verbindungssequenz

1. **Client verbindet** zu `ws://192.168.2.101:18789`
2. **Server sendet Challenge:**
   ```json
   {"type":"event","event":"connect.challenge","payload":{"nonce":"<uuid>","ts":<ms>}}
   ```
3. **Client antwortet** mit einem signierten Connect-Frame:
   ```json
   {
     "type": "req",
     "id": "conn-001",
     "method": "connect",
     "params": {
       "minProtocol": 3,
       "maxProtocol": 3,
       "client": {"id": "cli", "version": "...", "platform": "linux", "mode": "cli"},
       "role": "operator",
       "scopes": ["operator.read", "operator.write"],
       "auth": {"token": "<operator-token>"},
       "device": {
         "id": "<deviceId>",
         "publicKey": "<base64-raw-Ed25519-pubkey>",
         "signature": "<base64-Ed25519-sig-über-nonce>",
         "signedAt": <timestamp-ms>,
         "nonce": "<nonce-aus-challenge>"
       }
     }
   }
   ```
4. **Server antwortet** mit `{"type":"res","id":"conn-001","ok":true,...}` bei Erfolg
5. **Danach:** Request/Response über `{"type":"req","id":"...","method":"...","params":{...}}`

### Wichtige Felder

| Feld | Wert / Herkunft |
|------|----------------|
| `client.id` | `"cli"` (einziger bekannter gültiger Wert für externe Clients) |
| `client.mode` | `"cli"` (muss zur `id` passen; `"operator"` ist ungültig für mode) |
| `auth.token` | Aus `infra/openclaw-data/identity/device-auth.json` → `tokens.operator.token` |
| `device.id` | Aus `infra/openclaw-data/identity/device.json` → `deviceId` |
| `device.publicKey` | Base64 des raw 32-Byte Ed25519 Public Key (NICHT PEM) |
| `device.signature` | Ed25519-Signatur des Nonce-Strings (UTF-8) mit dem Private Key |
| `device.nonce` | Nonce aus dem Server-Challenge |

> **Nicht** `OPENCLAW_GATEWAY_TOKEN` für den WebSocket verwenden — das ist für Webhook-Authentifizierung, nicht für WebSocket-Verbindungen.

### Verfügbare HTTP-Endpunkte auf Port 18789

| Pfad | Methode | Status |
|------|---------|--------|
| `/` | GET | ✅ SPA (Control UI HTML) |
| `/status` | GET | ✅ SPA (fällt durch zu HTML) |
| `/hooks/<path>` | POST | ✅ Webhook-Trigger (mit Bearer-Token) |
| `/api/chat` | POST | ❌ Existiert nicht nativ |
| `/openai/v1/chat/completions` | POST | ❌ 404 |
| `/api/*` | * | ❌ 404 (kein REST API) |

---

## CLI-Nutzung (Primärer Weg für programmatischen Zugriff)

Der einzig zuverlässige synchrone Weg, mit dem Agent zu kommunizieren:

```bash
# Nachricht an den Haupt-Agenten senden (JSON-Ausgabe)
docker exec openclaw openclaw agent --agent main --message "Deine Nachricht" --json

# Ohne JSON (plain text output)
docker exec openclaw openclaw agent --agent main --message "Deine Nachricht"

# Mit explizitem Thinking-Level
docker exec openclaw openclaw agent --agent main --message "..." --thinking medium --json

# An bestimmte Telegram-Session senden + Antwort zurückliefern
docker exec openclaw openclaw agent --to +49XXXXXXXXXX --message "..." --deliver

# Andere nützliche Befehle:
docker exec openclaw openclaw status            # Kanal-Health + Sessions
docker exec openclaw openclaw --help            # Alle Befehle
docker exec openclaw openclaw agent --help      # Agent-Optionen
docker exec openclaw openclaw agents --help     # Agent-Verwaltung
```

### JSON-Antwortformat

```json
{
  "runId": "...",
  "status": "ok",
  "summary": "completed",
  "result": {
    "payloads": [
      {"text": "Antwort des Agenten", "mediaUrl": null}
    ],
    "meta": {
      "durationMs": 8459,
      "agentMeta": {
        "sessionId": "...",
        "provider": "github-copilot",
        "model": "gpt-4.1",
        "usage": {"input": 18034, "output": 13, "total": 18047}
      }
    }
  }
}
```

Antworttext extrahieren: `result.payloads[0].text`

### Direkter CLI-Befehl vom Host

```bash
# Voraussetzung: User steges muss in der docker-Gruppe sein
docker exec openclaw openclaw agent --agent main --message "Hallo" --json
```

---

## Claude↔OpenClaw Kollaboration (claw-send)

### Architektur der Trennung

Drei Kommunikationskanäle mit strikter Session-Trennung:

| Kanal | Wer | Session | Script |
|-------|-----|---------|--------|
| **Telegram** | steges (User) | Telegram-Session | – |
| **Canvas-Chat** | Browser-UI | chat-Sitzung (HTTP-Bridge) | `chat-bridge.py` |
| **Claude Code** | Claude (diese Instanz) | `claude-ops` (dediziert) | `claw-send.sh` |

Die `claude-ops`-Session ist vollständig isoliert von User-Sessions. Claude-Requests tauchen **nie** in der Telegram-History auf und umgekehrt.

### claw-send.sh — Strukturierter Request-Kanal

```bash
# Basis
~/scripts/claw-send.sh --intent inspect --target "docker services"

# Vollständig
~/scripts/claw-send.sh \
  --intent inspect \
  --target "sensor.growbox_temperatur" \
  --priority p0 \
  --scope growbox \
  --allowed "HA state lesen, Thresholds vergleichen" \
  --forbidden "keine Relais schalten, keine Konfig-Änderungen" \
  --success "Ursache und Schweregrad benannt" \
  --context "Thresholds in growbox/THRESHOLDS.md" \

# Raw JSON für maschinelle Weiterverarbeitung
~/scripts/claw-send.sh --intent report --target "service ports" --raw
```

Intents: `inspect` | `change` | `report` | `promote` | `rollback` | `classify`  
Priorities: `p0` (kritisch) → `p3` (niedrig)

### HANDSHAKE-Protokoll

Jeder Request wird als strukturierter Markdown-Block übertragen:

```markdown
## Request
- id: req-20260408-154705-docker-services
- sender: claude
- intent: inspect
- priority: p2
- scope: service
- target: docker services
- allowed_actions: docker ps ausführen, Container-Status lesen
- forbidden_actions: keine Container stoppen, kein prune
- success_criteria: Liste laufender Container mit Status
- escalation_contact: claude

## Context
Kollaborationstest...
```

OpenClaw antwortet im `## Response`-Format (HANDSHAKE.md):

```markdown
## Response
- request_id: req-20260408-154705-docker-services
- responder: openclaw
- status: completed
- summary: <eine knappe Ergebniszeile>
- result: <konkretes Ergebnis>
- evidence: <Nachweise>
- risks: None
- next_steps: none
- escalation: none
```

### Implementierungsdetails

| Datei | Zweck |
|-------|-------|
| `scripts/claw-send.sh` | Request-Formatierung + CLI-Aufruf |
| `agent/AGENTS.md` → "Claude Collaboration" | Instruiert OpenClaw wie HANDSHAKE-Requests behandelt werden |
| `agent/HANDSHAKE.md` → "Technische Übertragung" | Protokoll-Referenz + CLI-Syntax |
| Session-ID | `claude-ops` (fest, persistiert History) |

### Direkter CLI-Aufruf (ohne HANDSHAKE-Format)

Für einfache Abfragen ohne strukturiertes Protokoll:

```bash
docker exec openclaw openclaw agent --agent main --message "Deine Frage" --json
# Antwort: result.payloads[0].text
```

---

## Chat-Bridge (Canvas-UI-Chat → Agent)

### Problem

Die Canvas-UI (`app-chat.js`) ruft `openclawBase + "/api/chat"` auf. Dieser Endpunkt existiert nicht im OpenClaw-Gateway. Das Gateway ist rein WebSocket-basiert mit komplexem PKI-Handshake.

### Lösung

Ein Python-HTTP-Bridge-Service übersetzt REST → CLI:

```
Browser (ops.lan)
  → POST http://openclaw.lan/api/chat
  → Caddy (@chat Matcher auf openclaw.lan)
  → 127.0.0.1:18792 (chat-bridge.service)
  → docker exec openclaw openclaw agent --agent main --message TEXT --json
  → {"reply": "Antwort"}
```

### Service-Details

| Komponente | Pfad |
|-----------|------|
| Python-Bridge | `/home/steges/scripts/chat-bridge.py` |
| systemd-Service | `/home/steges/systemd/chat-bridge.service` → `/etc/systemd/system/` |
| Caddy-Route | `http://openclaw.lan { @chat ... }` in `caddy/Caddyfile` |
| Bind-Adresse | `127.0.0.1:18792` (nur lokal, kein direkter LAN-Zugriff) |

### Service-Verwaltung

```bash
# Status
sudo systemctl status chat-bridge

# Logs
journalctl -u chat-bridge -f

# Neustart
sudo systemctl restart chat-bridge

# Manueller End-to-End-Test
curl -X POST http://127.0.0.1:18792/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Test"}'

# Via Caddy (wie Browser)
curl -X POST http://openclaw.lan/api/chat \
  --resolve "openclaw.lan:80:192.168.2.101" \
  -H "Content-Type: application/json" \
  -d '{"message": "Test"}'
```

### API-Format

**Request:**
```json
POST /api/chat
{"message": "Deine Frage"}
```

**Response:**
```json
{"reply": "Antwort des Agenten"}
```

Timeout: 120 Sekunden. CORS-Headers sind gesetzt (`Access-Control-Allow-Origin: *`).

---

## Webhook-System

OpenClaw hat ein konfigurierbares Webhook-System für externe Trigger:

```bash
# Growbox-Alert triggern
curl -X POST http://192.168.2.101:18789/hooks/growbox-alert \
  -H "Authorization: Bearer $OPENCLAW_WEBHOOK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Temp kritisch", "entity_id": "sensor.temp", "state": "32.5"}'

# ESP32-Offline-Alert
curl -X POST http://192.168.2.101:18789/hooks/esp32-offline \
  -H "Authorization: Bearer $OPENCLAW_WEBHOOK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "sensor.growbox", "last_state": "31.2"}'
```

Auth: `Authorization: Bearer $OPENCLAW_WEBHOOK_TOKEN` (aus `.env`)  
Mappings konfiguriert in `infra/openclaw-data/openclaw.json` → `hooks.mappings[]`.

---

## Native Skills (relevant)

| Skill | Zweck |
|-------|-------|
| **`coding-agent`** | Delegiert Coding-Tasks an `claude --permission-mode bypassPermissions --print` (Claude Code CLI), Codex, oder Pi. Hintergrund-Ausführung möglich. |
| **`skill-creator`** | Erstellt, verbessert, auditiert SKILL.md-Dateien. Triggert bei "create a skill", "improve this skill", "audit the skill" etc. |
| **`clawflow`** | Multi-step Background-Job-Orchestration. Hält Flow-Identity, Waiting-State, Output-Bag. Für Jobs die länger als ein Prompt dauern. |
| **`clawhub`** | Skill-Publish/Install von ClawHub (Community-Plattform). |
| **`healthcheck`** | Security & Risk-Assessment. |
| **`canvas`** | Canvas-UI-Interaktion. |

---

## Memory-System (3 Schichten)

| Schicht | Datei/Pfad | Zweck |
|---------|-----------|-------|
| **Agent-Workspace** | `agent/MEMORY.md` | Kuratiertes Langzeit-Gedächtnis. Nur in Main-Session geladen. |
| **Daily Notes** | `agent/memory/YYYY-MM-DD.md` | Rohes Tageslog. Letzte 2 Tage beim Start geladen. |
| **Native SQLite** | `infra/openclaw-data/memory/main.sqlite` | Durchsuchbar via `memory_search` (Hybrid: Vector + Keyword). Automatisch persistiert. |
| **Operational** | `agent/skills/skill-forge/.learnings/LEARNINGS.md` | Skill-Manager-Operational-Learning aus Audit/Action-Log. |

**Wichtig:** Native SQLite-Memory und Workspace-Markdown-Memory sind getrennte Stores. `memory_search` durchsucht nur den SQLite-Store.

---

## Context Injection (jeder Turn)

OpenClaw injiziert automatisch in jeden Turn:
- `AGENTS.md` – Verhaltensinstruktionen
- `SOUL.md` – Identität
- `TOOLS.md` – Tool-Übersicht
- `IDENTITY.md` – Selbstbild
- `USER.md` – User-Profil
- `HEARTBEAT.md` – Heartbeat-Checkliste (wenn vorhanden)
- `BOOTSTRAP.md` – Einmal-Instruktionen (wird nach Ausführung gelöscht)

---

## Heartbeat-System

**Zwei koexistierende Heartbeat-Systeme:**

| System | Trigger | Zweck |
|--------|---------|-------|
| **OpenClaw native** | Alle 30min (konfigurierbar in `openclaw.json`) | Schickt `HEARTBEAT.md` an Agent → Checks, proaktive Arbeit |
| **systemd-Timer** | 07:00 + 19:00 Europe/Berlin | Skill-Orchestration, Growbox, Metrics, Doc-Keeper |

Beide können koexistieren. Der native Heartbeat ist für reaktive Checks (Docker-Status, Sensoren). Der systemd-Timer für strukturierte Lifecycle-Arbeit.

---

## Konfiguration (`openclaw.json`)

```
infra/openclaw-data/openclaw.json
```

Wichtige Felder:
- `gateway.bind: "lan"` → bindet an LAN-IP (192.168.2.101), **nicht** localhost
- `agents.defaults.workspace: "/home/steges/agent"` → Workspace-Verzeichnis
- `agents.defaults.heartbeat.every: "30m"` → Heartbeat-Intervall
- `agents.defaults.model.primary: "github-copilot/gpt-4.1"` → Default-Modell
- `channels.telegram.*` → Telegram-Bot-Config + Custom Commands
- `hooks.token` → Webhook-Auth-Token (`$OPENCLAW_WEBHOOK_TOKEN`)

---

## Identitäts-Dateien

| Datei | Inhalt |
|-------|--------|
| `infra/openclaw-data/identity/device.json` | Device-ID, Ed25519 Public/Private Key (für WebSocket-Auth) |
| `infra/openclaw-data/identity/device-auth.json` | Operator-Token + Scopes (für WebSocket-Auth) |

> **Nicht committen!** Diese Dateien enthalten private Schlüssel und Tokens.

---

## Datenpfade (Pi)

| Pfad | Inhalt |
|------|--------|
| `/home/steges/agent/` | Workspace: AGENTS.md, SOUL.md, memory/, skills/ |
| `/home/steges/infra/openclaw-data/` | Container-Volume: Sessions, Memory-DB, Config |
| `/home/steges/infra/openclaw-data/memory/main.sqlite` | Native Memory-Datenbank |
| `/home/steges/infra/openclaw-data/agents/main/sessions/` | Session-Transcripts (JSONL) |
| `/home/steges/infra/openclaw-data/tasks/runs.sqlite` | Nativer Task-Runner |
| `/home/steges/infra/openclaw-data/action-log.jsonl` | Gemeinsamer Audit-Trail |
| `/home/steges/infra/openclaw-data/rag/` | RAG-Index (SQLite+FTS5) |

---

## Unser Custom-Layer (Shell-Dispatcher)

Alles in `agent/skills/*/scripts/*.sh` ist **custom** – nicht Teil von OpenClaw selbst:
- `skill-forge` (orchestrate, canary, promote, rollback) – komplett custom
- `coding` (Planner→Coder→Reviewer, Artifact-Templates) – custom, NICHT = `coding-agent`
- `heartbeat`, `metrics`, `learn`, `growbox`, `scout` – alle custom Shell/Python
- Einstiegspunkt: `~/scripts/skills <domain>` → jeweiliger Dispatcher

**Wichtige Unterscheidung:**
- Unser `coding`-Skill → generiert Code-Artifact-Templates (kein Live-Execution)
- OpenClaw's `coding-agent` → spawnt `claude --permission-mode bypassPermissions` → echte Ausführung

---

## ClawHub (Skill-Publishing)

Community-Plattform für Skills. Installation via `openclaw plugins install <name>`. Skills werden zuerst in ClawHub/npm gesucht, dann lokal. VirusTotal-Integration für Security-Scanning von Community-Skills.

---

## Bekannte Limitierungen im Homelab-Setup

- `coding-agent` braucht `claude` CLI installiert → `npm i -g @anthropic-ai/claude-code`
- Gateway bindet nur an LAN-IP, nicht `localhost` → Webhook-Calls von Host via `192.168.2.101:18789`
- ClawFlow ist TypeScript-intern → nicht direkt aus Shell-Dispatcher aufrufbar
- WebSocket-Auth erfordert vollständige PKI-Signatur (Ed25519, v3-Payload) → komplex für externe Clients; CLI via `docker exec` ist der bevorzugte Weg
- Canvas-Chat nutzt `/api/chat` Bridge (chat-bridge.service) → Timeout 120s; bei langen Agent-Antworten ggf. erhöhen
