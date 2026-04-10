# OpenClaw Kommunikation

_Wie steges mit OpenClaw kommuniziert und umgekehrt. Zuletzt aktualisiert: 2026-04-09._

---

## Kanäle

### 1. Telegram (primär für steges → Claw)

steges schreibt Nachrichten an den Telegram-Bot.
OpenClaw antwortet strukturiert und sendet autonome Benachrichtigungen.

- **Chat-ID:** 2011062206
- **Anzeigename:** Nanobot (nur Anzeigename — System bleibt OpenClaw)
- **Benachrichtigungen:** zusammengefasst (nicht bei jeder Einzelaktion)

### 2. HTTP-Gateway (Port 18789)

OpenClaw-Gateway empfängt REST-Anfragen und leitet sie ans Skill-System weiter.
URL: `http://192.168.2.101:18789`

```bash
# Direkter HTTP-Request (intern)
curl -X POST http://192.168.2.101:18789/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "was läuft gerade?", "session_id": "test"}'
```

### 3. Claude Code / SSH (für Entwicklung)

steges arbeitet direkt per SSH + VS Code auf dem Pi.
Claude Code läuft als interaktiver Agent in dieser Umgebung.

### 4. Canvas UI (Port 8090)

Browser-basiertes UI für OpenClaw-Bedienung.
Single-Source: `agent/skills/openclaw-ui/html/index.html`
Symlink: `infra/openclaw-data/canvas/index.html` → gleiche Datei

---

## Claude → OpenClaw: claw-send.sh

Claude übergibt Aufgaben an OpenClaw über `~/scripts/claw-send.sh` mit HANDSHAKE-Format.

```bash
# Einfache Anfrage
~/scripts/claw-send.sh --intent inspect --target "docker services"

# Vollständig
~/scripts/claw-send.sh \
  --intent inspect \
  --target "sensor.growbox_temperatur" \
  --priority p0 \
  --scope growbox \
  --allowed "HA state lesen, Thresholds vergleichen" \
  --forbidden "keine Relais schalten" \
  --success "Ursache und Schweregrad benannt" \
  --context "Thresholds in /home/steges/growbox/THRESHOLDS.md"
```

**Session-Trennung:** Claude-Requests laufen über `--session-id claude-ops`.
Keine Cross-Contamination mit Telegram-Chats.

---

## HANDSHAKE-Protokoll (agent/HANDSHAKE.md)

Gemeinsame Sprache zwischen Claude und OpenClaw für strukturierte Übergaben.

**Request-Format (Claude → OpenClaw):**
```markdown
## Request
- id: req-YYYYMMDD-HHMMSS-slug
- sender: claude
- intent: inspect | change | report | promote | rollback
- priority: p0 | p1 | p2 | p3
- target: <Hauptobjekt>
- allowed_actions: <erlaubte Schritte>
- success_criteria: <wann gilt es als erledigt>
- escalation_contact: claude | steges
```

**Response-Format (OpenClaw → Claude):**
```markdown
## Response
- request_id: <id>
- responder: openclaw
- status: completed | partial | blocked | rejected | escalated
- summary: <eine Zeile>
- result: <konkretes Ergebnis>
- evidence: <Nachweise>
- risks: <Rest-Risiken oder None>
- next_steps: <nächster sinnvoller Schritt>
```

---

## OpenClaw → steges: Telegram-Benachrichtigungen

OpenClaw sendet nicht bei jeder Aktion, sondern:
- **Täglich:** Heartbeat-Summary (Systemstatus, Growbox, offene Issues)
- **Bei Incidents:** sofort, P0/P1
- **Bei Skill-Promote:** kurze Meldung
- **Bei Warnungen:** zusammengefasst im nächsten Heartbeat

Ziel: kein Notification-Flood, aber keine stillen Failures.

---

## Eskalationsregeln

OpenClaw eskaliert an Claude oder steges wenn:
- Aktion wäre destruktiv oder schwer reversibel
- Secrets/Credentials betroffen
- Ziel mehrdeutig
- Incident-Freeze aktiv
- Mehrere gleichwertige Optionen mit relevanten Trade-offs

Standard: lieber `blocked` oder `escalated` als raten.
