# HANDSHAKE.md

Gemeinsames Protokoll zwischen Claude und OpenClaw. Ziel ist eine stabile Uebergabe von Aufgaben, Rueckmeldungen und Eskalationen ohne separates State-File. Format ist bewusst reines Markdown.

## Gemeinsames Vokabular

### Todo-Zielpfad
Wenn eine Anfrage "mach todo", "todo anlegen" oder "todo aktualisieren" enthaelt, ist der Zielpfad verbindlich:
- `/home/steges/docs/operations/open-work-todo.md`

Zusatzregel:
- Keine neuen Todo-Markdown-Dateien unter `/home/steges/agent/` erstellen.
- `agent/TO-DO.md` ist nur ein Migrationshinweis und keine aktive Todo-Liste.

### Heartbeat
Regelmaessiger, kurzer Health- und Maintenance-Zyklus. Heartbeats duerfen lesen, pruefen, kleine sichere Routinearbeiten ausfuehren und muessen kritische Abweichungen melden.

### Canary
Beobachtungsphase eines neuen oder geaenderten Skills. Canary bedeutet noch nicht produktiv-freigegeben. Verhalten wird validiert, bevor Promote erlaubt ist.

### Incident
Stoerung, Risiko oder Policy-Verletzung mit Handlungsbedarf. Bei aktivem Incident ist Vorsicht wichtiger als Automatisierung.

### Skill
Begrenzte Faehigkeit mit dokumentiertem Zweck, klaren Grenzen, Scripts und Lifecycle.

### Promote
Bewusster Uebergang eines geprueften Skills von Canary oder Staging in den produktiven Einsatz. Promote setzt bestandene Gates und nachvollziehbare Herkunft voraus.

## Nachrichtenformat

Claude uebergibt Aufgaben an OpenClaw in dieser Struktur:

```markdown
## Request
- id: req-YYYYMMDD-HHMMSS-short-slug
- sender: claude
- intent: <classify|inspect|change|promote|rollback|report>
- priority: <p0|p1|p2|p3>
- scope: <service|skill|doc|growbox|infra>
- target: <primary object>
- allowed_actions: <explizit erlaubte Schritte>
- forbidden_actions: <explizit verbotene Schritte>
- success_criteria: <wann gilt die Aufgabe als erledigt>
- evidence_expected: <logs|diff|metrics|links|summary>
- escalation_contact: <claude|steges>

## Context
- relevante Fakten, Dateipfade, Ports, bekannte Risiken

## Notes
- optionale Hinweise, offene Fragen, Zeitfenster
```

Pflichtfelder:
- `id`
- `sender`
- `intent`
- `priority`
- `target`
- `allowed_actions`
- `success_criteria`
- `escalation_contact`

Optionale Felder:
- `scope`
- `forbidden_actions`
- `evidence_expected`
- `Context`
- `Notes`

## Antwortformat

OpenClaw meldet Ergebnisse in dieser Struktur zurueck:

```markdown
## Response
- request_id: <id aus Request>
- responder: openclaw
- status: <completed|partial|blocked|rejected|escalated>
- summary: <eine knappe Ergebniszeile>
- result: <konkretes Ergebnis oder veraenderter Zustand>
- evidence: <wichtigste Nachweise>
- risks: <Rest-Risiken oder None>
- next_steps: <naechster sinnvoller Schritt>
- escalation: <none|claude|steges>
```

Status-Bedeutung:
- `completed`: Aufgabe innerhalb des erlaubten Rahmens erledigt.
- `partial`: Teilziel erledigt, Rest offen.
- `blocked`: Umsetzung an externer Abhaengigkeit oder fehlendem Zugriff gescheitert.
- `rejected`: Anfrage verletzt Policy, Grenzen oder Kontext.
- `escalated`: Mensch oder Claude muss entscheiden.

## Eskalationsregeln

OpenClaw entscheidet nicht selbst, sondern eskaliert an Claude oder steges, wenn mindestens eine Bedingung zutrifft:
- Aktion waere destruktiv oder schwer rueckgaengig.
- Secrets, Passwoerter oder private Schluessel waeren betroffen.
- Ziel ist mehrdeutig oder die Erfolgsbedingung unklar.
- Ein Incident oder Incident-Freeze ist aktiv.
- Ein Skill verletzt Contract, Canary-Regeln oder Provenance-Gates.
- Mehrere plausible Aktionen existieren und der Trade-off ist relevant.
- Externer Effekt ausserhalb des Pi waere noetig.

Standardregel:
- Bei Unsicherheit lieber `blocked` oder `escalated` statt raten.

## Uebergabe-Beispiele

### Beispiel 1: Growbox-Alarm untersuchen

```markdown
## Request
- id: req-20260404-173000-growbox-temp
- sender: claude
- intent: inspect
- priority: p0
- scope: growbox
- target: sensor.growbox_temperatur
- allowed_actions: HA state lesen, letzte relevante Logs lesen, Thresholds vergleichen
- forbidden_actions: keine Relais schalten, keine Konfig aendern
- success_criteria: Ursache und aktueller Schweregrad sind benannt
- evidence_expected: summary, links, readings
- escalation_contact: claude

## Context
- Thresholds in /home/steges/growbox/THRESHOLDS.md
- HA unter http://192.168.2.101:8123
```

```markdown
## Response
- request_id: req-20260404-173000-growbox-temp
- responder: openclaw
- status: completed
- summary: Temperatur liegt 2.3 C ueber Warnschwelle, ESP32 ist online
- result: Vermutlich schlechter Luftaustausch, keine Sensor-Ausfaelle sichtbar
- evidence: sensor state 31.3 C, humidity 58%, letzte HA-Logs ohne device offline
- risks: weitere Erwaermung moeglich
- next_steps: Claude soll Nutzer auf manuelle Lueftungspruefung hinweisen
- escalation: claude
```

### Beispiel 2: Skill-Promotion vorbereiten

```markdown
## Request
- id: req-20260404-174500-promote-rag
- sender: claude
- intent: promote
- priority: p1
- scope: skill
- target: openclaw-rag
- allowed_actions: Canary-Status lesen, Provenance pruefen, Promote nur bei gruenen Gates
- forbidden_actions: Gates umgehen, Incident-Freeze ignorieren
- success_criteria: klarer Promote-Entscheid mit Begruendung
- evidence_expected: metrics, gate summary
- escalation_contact: claude
```

```markdown
## Response
- request_id: req-20260404-174500-promote-rag
- responder: openclaw
- status: partial
- summary: Promote noch nicht zulaessig
- result: Canary laeuft erst seit 7h, 24h Mindestzeit nicht erreicht
- evidence: canary_start=2026-04-04T10:41:00Z, policy minimum=24h
- risks: verfruehte Promotion ohne Reifezeit
- next_steps: erneut nach Ablauf des Fensters pruefen
- escalation: none
```

### Beispiel 3: RAG-Query ausfuehren

```markdown
## Request
- id: req-20260404-180000-rag-ports
- sender: claude
- intent: report
- priority: p2
- scope: doc
- target: service ports
- allowed_actions: nur RAG-Retrieval aus freigegebenen Quellen
- forbidden_actions: Web-Suche, freie Spekulation
- success_criteria: Antwort mit Quellenhinweisen
- evidence_expected: retrieval hits
- escalation_contact: claude
```

```markdown
## Response
- request_id: req-20260404-180000-rag-ports
- responder: openclaw
- status: completed
- summary: Relevante Portliste gefunden
- result: Pi-hole 8080, HA 8123, ESPHome 6052, Portainer 9000, OpenClaw 18789
- evidence: docs/core/services-and-ports.md, CLAUDE.md, retrieval top-5 hits
- risks: None
- next_steps: none
- escalation: none
```

### Beispiel 4: Incident-Eskalation bei unklarem Write

```markdown
## Request
- id: req-20260404-181500-fix-openclaw-config
- sender: claude
- intent: change
- priority: p1
- scope: infra
- target: infra/openclaw-data/openclaw.json
- allowed_actions: Problem analysieren, safe fix vorschlagen
- forbidden_actions: blindes Rewrite, mehrere konkurrierende Files loeschen
- success_criteria: sichere Handlungsempfehlung oder Fix
- escalation_contact: steges
```

```markdown
## Response
- request_id: req-20260404-181500-fix-openclaw-config
- responder: openclaw
- status: escalated
- summary: Mehrere konkurrierende Backup-Dateien, sicherer Write-Pfad unklar
- result: Kein automatischer Eingriff ausgefuehrt
- evidence: openclaw.json plus mehrere .bak-Dateien, aktueller Besitzerkonflikt moeglich
- risks: Konfigurationsverlust bei falschem Merge
- next_steps: Claude oder steges soll gewuenschten Source-of-Truth bestaetigen
- escalation: steges
```

## Technische Uebertragung (Claude→OpenClaw)

Claude sendet Requests ueber den dedizierten Kanal:

```bash
# Einfache Anfrage
~/scripts/claw-send.sh --intent inspect --target "docker services"

# Vollstaendig (alle Felder)
~/scripts/claw-send.sh \
  --intent inspect \
  --target "sensor.growbox_temperatur" \
  --priority p0 \
  --scope growbox \
  --allowed "HA state lesen, Thresholds vergleichen" \
  --forbidden "keine Relais schalten" \
  --success "Ursache und Schweregrad benannt" \
  --context "Thresholds in /home/steges/growbox/THRESHOLDS.md"

# Vollstaendiger JSON-Output (fuer maschinelle Weiterverarbeitung)
~/scripts/claw-send.sh --intent report --target "..." --raw
```

**Session-Trennung:** Alle Claude-Requests laufen ueber `--session-id claude-ops`.
Das bedeutet: Claude-Konversationen und User/Telegram-Chats haben getrennte Histories.
Kein Cross-Bleed zwischen den Kanaelen.

**Wichtig fuer OpenClaw:** Requests ueber `claude-ops`-Session immer mit HANDSHAKE-Format beantworten (exakte Feldnamen, siehe Antwortformat oben).

## Web-Suche (SearXNG)

Lokaler SearXNG-Proxy unter http://search.lan / 192.168.2.101:8085.
Kein API-Key, kein Tracking, mehrere Engines parallel (Google, DDG, Bing, GitHub, SO, …).

### Wann nutzen

- Aktuelle Infos zu CVEs, Changelogs, Doku
- Fehlersuche wenn RAG keine Treffer liefert
- Software-Versionen, Kompatibilitätsfragen

### Aufrufe

```bash
# Suche mit top-5-Ausgabe
~/scripts/skills web-search search "<query>"

# Anzahl und Engine steuern
~/scripts/skills web-search search "CVE-2024-1234" --limit 3 --engines google,duckduckgo

# Maschineller JSON-Output
~/scripts/skills web-search search "<query>" --json

# Erreichbarkeit prüfen
~/scripts/skills web-search check
```

### Grenzen

- Nur Snippets, kein Seiten-Scraping
- Externe Engines können bei Überlast Rate-Limits setzen → andere Engine wählen
- Ergebnisse sind nicht verifiziert — eigenständig bewerten

## Log-Zugriff (Loki)

Container-Logs werden von Promtail gesammelt und in Loki gespeichert.
OpenClaw fragt Logs **immer live via log-query Skill** ab — niemals aus RAG.

### Wann Logs abrufen

- Bei Incident-Untersuchung eines Services
- Wenn `health-check.sh` einen Fehler meldet
- Wenn ein Heartbeat eine Anomalie feststellt
- Wenn ein Nutzer nach Logs fragt

### Aufruf-Muster

```bash
# Letzte Logs eines Services
~/scripts/skills log-query query --service <container-name> --lines 50 --since 1h

# Gefiltert nach Pattern
~/scripts/skills log-query query --service pihole --since 2h --grep "blocked"

# Alle verfügbaren Container
~/scripts/skills log-query query --services

# LogQL direkt (z. B. Error-Suche über mehrere Services)
~/scripts/skills log-query query --query '{container=~"openclaw|caddy"} |= "error"' --lines 30
```

### Grenzen

- Loki-Retention: 30 Tage
- Nur lesend
- Wenn Loki nicht erreichbar: `blocked` melden

### RAG-Abgrenzung

RAG enthält **keine Logs**. RAG ist für Dokumentation, Configs und Wissensbasis.
Logs sind flüchtig und rauschbehaftet — RAG würde dadurch überladen und degradiert.
Trennung: RAG = Wissen, Loki = Ereignisse.

## Arbeitsregeln

Wenn Claude und OpenClaw unterschiedliche Abstraktionen verwenden, gilt dieses Dokument als gemeinsame Uebersetzungsschicht. Im Zweifel gewinnt die restriktivere Interpretation.

### Skill-Manager vs. direkte Skill-Aufrufe

- **Fachliche Nutzung eines Skills** (coding, vetting, canary evaluate, authoring): direkt ueber `~/scripts/skills ...`
- **Skill-Lifecycle und Governance** (install, update, rollback, policy, audit, blacklist, orchestrate, incident, provenance): ueber `~/scripts/skill-forge ...`

Skill-Manager und dessen Wrapper werden **nicht** als generischer Einstiegspunkt genutzt. Wer einen Skill fachlich aufrufen will, geht immer den direkten Weg. Vollstaendige Entscheidungsregel: `docs/skills/skill-forge-governance.md` Abschnitt "Architektur-Grenzen".