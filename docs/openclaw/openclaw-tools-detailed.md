# OpenClaw – Tools & Capabilities (Technische Details)

> Vollständige Liste aller nativen Tools mit Parametern und Beispielen  
> Stand: April 2026

---

## Tool-Kategorien

| Kategorie | Tools | Use-Case |
|-----------|-------|----------|
| **Agent** | `agent.*` | Agent-Steuerung, Sessions |
| **Browser** | `browser.*` | Web-Automation |
| **Canvas** | `canvas.*` | Visuelle UI-Interaktion |
| **Cron** | `cron.*` | Zeitgesteuerte Tasks |
| **Discord** | `discord.*` | Discord-Integration |
| **Gateway** | `gateway.*` | Gateway-Management |
| **Node** | `node.*` | Geräte-Steuerung |
| **Process** | `process.*` | Prozess-Management |
| **Read/Write** | `read`, `write`, `edit` | Datei-Operationen |
| **Shell** | `bash`, `/elevated` | System-Zugriff |
| **Sessions** | `sessions_*` | Agent-zu-Agent |

---

## 1. Agent Tools

### agent.list

**Zweck:** Verfügbare Agenten auflisten

```json
{
  "tool": "agent.list",
  "params": {}
}
```

**Response:**
```json
{
  "agents": [
    {"id": "main", "status": "ready"},
    {"id": "coding", "status": "busy"}
  ]
}
```

---

### agent.message

**Zweck:** Nachricht an Agent senden

```json
{
  "tool": "agent.message",
  "params": {
    "agent": "main",
    "message": "Status check",
    "sessionId": "claude-ops",
    "thinkingLevel": "medium",
    "verbose": false
  }
}
```

---

## 2. Browser Tools (Chrome CDP)

### browser.open

**Zweck:** Browser-Instanz öffnen

```json
{
  "tool": "browser.open",
  "params": {
    "url": "https://example.com",
    "headless": false,
    "profile": "default"
  }
}
```

**Parameter:**
| Name | Typ | Default | Beschreibung |
|------|-----|---------|--------------|
| `url` | string | (required) | Start-URL |
| `headless` | boolean | true | Headless-Modus |
| `profile` | string | "default" | Chrome-Profile |
| `viewport` | object | {1280x720} | Fenstergröße |

---

### browser.navigate

**Zweck:** Zu URL navigieren

```json
{
  "tool": "browser.navigate",
  "params": {
    "url": "https://openclaw.ai"
  }
}
```

---

### browser.click

**Zweck:** Element anklicken

```json
{
  "tool": "browser.click",
  "params": {
    "selector": "button.submit",
    "waitFor": "navigation"
  }
}
```

---

### browser.type

**Zweck:** Text eingeben

```json
{
  "tool": "browser.type",
  "params": {
    "selector": "input#email",
    "text": "user@example.com",
    "clearFirst": true
  }
}
```

---

### browser.screenshot

**Zweck:** Screenshot erstellen

```json
{
  "tool": "browser.screenshot",
  "params": {
    "selector": "body",
    "fullPage": true,
    "savePath": "/tmp/screenshot.png"
  }
}
```

---

### browser.extract

**Zweck:** Daten extrahieren

```json
{
  "tool": "browser.extract",
  "params": {
    "selector": ".price",
    "attribute": "textContent",
    "multiple": true
  }
}
```

---

### browser.close

**Zweck:** Browser schließen

```json
{
  "tool": "browser.close",
  "params": {}
}
```

---

## 3. Canvas Tools (A2UI)

### canvas.push

**Zweck:** UI-Element rendern

```json
{
  "tool": "canvas.push",
  "params": {
    "type": "form",
    "content": {
      "title": "User Input",
      "fields": [
        {"name": "email", "type": "email"}
      ]
    }
  }
}
```

---

### canvas.reset

**Zweck:** Canvas leeren

```json
{
  "tool": "canvas.reset",
  "params": {}
}
```

---

### canvas.eval

**Zweck:** JavaScript im Canvas ausführen

```json
{
  "tool": "canvas.eval",
  "params": {
    "code": "document.getElementById('chart').update()"
  }
}
```

---

## 4. Cron Tools

### cron.schedule

**Zweck:** Job planen

```json
{
  "tool": "cron.schedule",
  "params": {
    "name": "daily-backup",
    "schedule": "0 3 * * *",
    "message": "Führe Backup aus"
  }
}
```

**Cron-Syntax:**
```
* * * * *
│ │ │ │ └── Wochentag (0-7)
│ │ │ └──── Monat (1-12)
│ │ └────── Tag (1-31)
│ └──────── Stunde (0-23)
└────────── Minute (0-59)
```

---

### cron.list

**Zweck:** Jobs auflisten

```json
{
  "tool": "cron.list",
  "params": {}
}
```

---

### cron.remove

**Zweck:** Job entfernen

```json
{
  "tool": "cron.remove",
  "params": {
    "name": "daily-backup"
  }
}
```

---

## 5. Datei-Tools

### read

**Zweck:** Datei lesen

```json
{
  "tool": "read",
  "params": {
    "path": "/home/steges/agent/MEMORY.md",
    "limit": 100,
    "offset": 0
  }
}
```

---

### write

**Zweck:** Datei schreiben

```json
{
  "tool": "write",
  "params": {
    "path": "/home/steges/agent/notes.txt",
    "content": "Neue Notiz",
    "append": false
  }
}
```

---

### edit

**Zweck:** Datei bearbeiten (diff-basiert)

```json
{
  "tool": "edit",
  "params": {
    "path": "/home/steges/agent/config.json",
    "oldString": '"debug": false',
    "newString": '"debug": true'
  }
}
```

---

## 6. Shell Tools

### bash

**Zweck:** Shell-Befehl ausführen

```json
{
  "tool": "bash",
  "params": {
    "command": "docker ps",
    "timeout": 30000,
    "cwd": "/home/steges"
  }
}
```

**Parameter:**
| Name | Typ | Default | Beschreibung |
|------|-----|---------|--------------|
| `command` | string | (required) | Befehl |
| `timeout` | number | 60000 | Timeout (ms) |
| `cwd` | string | workspace | Arbeitsverzeichnis |
| `env` | object | {} | Umgebungsvariablen |

---

### /elevated

**Zweck:** Elevated-Zugriff togglen (Chat-Befehl)

```
/elevated on   # Aktivieren
/elevated off  # Deaktivieren
```

---

## 7. Node Tools (Geräte)

### node.list

**Zweck:** Verbundene Nodes auflisten

```json
{
  "tool": "node.list",
  "params": {}
}
```

---

### node.describe

**Zweck:** Node-Capabilities abfragen

```json
{
  "tool": "node.describe",
  "params": {
    "nodeId": "macos-node-1"
  }
}
```

---

### node.invoke

**Zweck:** Node-Action ausführen

```json
{
  "tool": "node.invoke",
  "params": {
    "nodeId": "macos-node-1",
    "action": "system.run",
    "params": {
      "command": "say 'Hello'"
    }
  }
}
```

---

### camera.snap

**Zweck:** Foto aufnehmen (via Node)

```json
{
  "tool": "camera.snap",
  "params": {
    "nodeId": "ios-node-1"
  }
}
```

---

### screen.record

**Zweck:** Bildschirm aufnehmen

```json
{
  "tool": "screen.record",
  "params": {
    "nodeId": "android-node-1",
    "duration": 30
  }
}
```

---

### location.get

**Zweck:** Standort abrufen

```json
{
  "tool": "location.get",
  "params": {
    "nodeId": "ios-node-1"
  }
}
```

---

## 8. Session Tools (Agent-zu-Agent)

### sessions_list

**Zweck:** Aktive Sessions auflisten

```json
{
  "tool": "sessions_list",
  "params": {}
}
```

---

### sessions_history

**Zweck:** Session-History abrufen

```json
{
  "tool": "sessions_history",
  "params": {
    "sessionId": "claude-ops",
    "limit": 50
  }
}
```

---

### sessions_send

**Zweck:** Nachricht an andere Session

```json
{
  "tool": "sessions_send",
  "params": {
    "sessionId": "main",
    "message": "Bitte analysiere Logs",
    "replyBack": true,
    "announceStep": true
  }
}
```

---

## 9. Process Tools

### process.spawn

**Zweck:** Prozess starten (Background)

```json
{
  "tool": "process.spawn",
  "params": {
    "command": "python server.py",
    "cwd": "/home/steges/project",
    "env": {"PORT": "8080"}
  }
}
```

---

### process.list

**Zweck:** Laufende Prozesse auflisten

```json
{
  "tool": "process.list",
  "params": {}
}
```

---

### process.kill

**Zweck:** Prozess beenden

```json
{
  "tool": "process.kill",
  "params": {
    "pid": 12345,
    "signal": "SIGTERM"
  }
}
```

---

## 10. Discord Tools

### discord.send

**Zweck:** Discord-Nachricht senden

```json
{
  "tool": "discord.send",
  "params": {
    "channel": "#general",
    "message": "Status update"
  }
}
```

---

## Tool-Sandboxing

### Standard-Allowlist

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "allowlist": [
          "bash",
          "process",
          "read",
          "write",
          "edit",
          "sessions_list",
          "sessions_history",
          "sessions_send",
          "sessions_spawn"
        ],
        "denylist": [
          "browser",
          "canvas",
          "nodes",
          "cron",
          "discord",
          "gateway"
        ]
      }
    }
  }
}
```

### Sandbox-Modi

| Modus | Beschreibung | Use-Case |
|-------|--------------|----------|
| `none` | Keine Sandbox | Vertrauenswürdige Umgebung |
| `non-main` | Non-main Sessions in Docker | Gruppen-Chats |
| `all` | Alle Sessions in Docker | Public/Shared |

---

## Tool-Nutzung in Skills

### Beispiel: Custom Skill

```markdown
# my-skill/SKILL.md

## Tools

### fetchData

Description: Daten von API holen

Parameters:
- url: string (required)
- method: string (optional) - GET, POST, etc.

Handler:
```javascript
export default async function handler(params, context) {
  const { bash } = context.tools;
  
  const result = await bash({
    command: `curl -s ${params.url}`,
    timeout: 10000
  });
  
  return {
    data: JSON.parse(result.stdout)
  };
}
```
```

---

## Troubleshooting Tools

### Tool nicht verfügbar

```bash
# Verfügbare Tools listen
docker exec openclaw openclaw tools list

# Tool-Info
docker exec openclaw openclaw tools info browser.open
```

### Sandbox-Fehler

```bash
# Sandbox-Status prüfen
docker exec openclaw openclaw agent --message "/sandbox status"

# Elevated togglen
docker exec openclaw openclaw agent --message "/elevated on"
```

### Timeout-Fehler

```json
{
  "tool": "bash",
  "params": {
    "command": "long-running-task",
    "timeout": 300000  // 5 Minuten
  }
}
```
