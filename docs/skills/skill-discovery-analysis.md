# Skill Discovery Analyse — 2026-04-08

Scout hat 48 neue Skills entdeckt (33x clawhub, 15x GitHub-Hubs).
Diese Datei bewertet jeden Kandidaten gegen die 19 lokalen Skills und gibt eine Empfehlung.

---

## Lokale Skills (Referenz)

| Skill | Funktion |
|---|---|
| `ha-control` | HA REST-Zugriff, read-only + Growbox-Whitelist |
| `growbox` | Growbox-Betrieb, Diary, Telegram, Sensor-Snapshots |
| `pi-control` | Pi-Ops: Service-Status, Docker, Systemchecks |
| `heartbeat` | Autonomer Ops-Heartbeat 2x täglich |
| `health` | Skill-Health-Report + Budget-Check |
| `metrics` | Orchestrate-Metriken, Weekly-Report |
| `openclaw-rag` | RAG über Homelab-Wissensbasis |
| `openclaw-ui` | Canvas UI |
| `runbook-maintenance` | Maintenance-Runbooks |
| `scout` | Skill-Discovery |
| `skill-forge` | Lifecycle-Manager |
| `vetting` | Semantisches Vet |
| `canary` | Canary-Evaluation |
| `coding` | Artifact-Generierung |
| `authoring` | Skill-Drafting |
| `doc-keeper` | Doku-Pflege |
| `learn` | Learning-Management |
| `profile` | Usage-Keyword-Profil |
| `core` | Shared Role Contracts |

---

## Bewertungsmatrix

**Empfehlungen:**
- `NACHBAUEN` — Funktionalität lohnt sich, aber extern zu abhängig/zu breit → selbst schreiben, eng auf diesen Stack zugeschnitten
- `ERWEITERN` — Überlappung mit bestehendem Skill, dort Feature einbauen statt neuen Skill
- `BEOBACHTEN` — Interessant, aber noch kein konkreter Bedarf
- `SKIP` — Irrelevant für diesen Stack, andere Plattform, zu generisch

---

## Home Assistant Skills (8 Kandidaten)

Alle überlappen mit dem lokalen `ha-control`. Die Frage ist Tiefe vs. Sicherheit.

| Slug | Was es tut | Bewertung | Begründung |
|---|---|---|---|
| `ha-ultimate` | 25+ Entity-Domains, Safety-Enforcement, Webhooks | **ERWEITERN** | Bester der Gruppe. Domain-Coverage (climate, media, camera) und Webhook-Trigger sind in `ha-control` nicht drin — Features dort einbauen |
| `home-assistant-master` | Read-only Audits, Diagnostics, Automation-Design, Dashboard-Planung | **ERWEITERN** | Audit/Diagnostics-Modus wäre wertvoll in `ha-control`; read-only-Pfad passt zu unserem Safety-Konzept |
| `home-assistant-toolkit` | Vollzugriff via SSH, HACS, Backups | **SKIP** | SSH-basiert, zu breiter Zugriff, widerspricht dem Whitelist-Ansatz von `ha-control` |
| `home-assistant` | Standard REST + Webhooks | **SKIP** | Deckungsgleich mit `ha-control`, keine Mehrwert |
| `home-assistant-agent-secure` | Nur Assist (Conversation) API | **BEOBACHTEN** | Interessanter Ansatz (HA-NLU statt Agent-NLU), aber sehr eingeschränkt |
| `homeassistant-assist` | Wie oben, Assist-API | **SKIP** | Duplikat von `home-assistant-agent-secure` |
| `homeassistant-cli` | hass-cli Tool, Event-Monitoring, History | **BEOBACHTEN** | `hass-cli` als Ergänzung zu REST macht Sinn; prüfen ob Binary verfügbar |
| `mcp-hass` | HA via MCP-Protokoll | **SKIP** | MCP nicht im Stack |
| `home-assistant-bridge-python` | Python-Bridge | **SKIP** | Overhead ohne Mehrwert gegenüber REST |
| `moltbot-ha` | HA via moltbot-ha CLI, Safety-Controls | **SKIP** | Externe CLI-Abhängigkeit, Overhead |

**Fazit HA:** `ha-control` mit Features aus `ha-ultimate` (mehr Entity-Domains, Webhook-Empfang) und `home-assistant-master` (Audit-Modus) erweitern.

---

## Homelab / Server-Management (3 Kandidaten)

Überlappung mit `pi-control` und `heartbeat`.

| Slug | Was es tut | Bewertung | Begründung |
|---|---|---|---|
| `homeserver` | Docker-Management, Wake-on-LAN, Port-Scanning, Self-hosted Apps installieren | **NACHBAUEN (partiell)** | Docker-Introspection und App-Install-Flows sind in `pi-control` nicht drin — aber WoL und Port-Scan sind irrelevant. Nur die Docker-Teile nachbauen, direkt in `pi-control` |
| `homelab-cluster` | Multi-Node AI Inference, MoE-Routing, Ollama/llama.cpp | **SKIP** | Ollama ist per CLAUDE.md explizit ausgeschlossen (Pi zu langsam) |
| `homelab-ai` | LLM Inference, Image Gen, STT auf Homelab-Cluster | **SKIP** | Gleicher Grund |
| `daily-health-report` | Täglicher Pi-Health-Report: Uptime, RAM, Disk, Temp → publiziert | **ERWEITERN** | `heartbeat` macht bereits Systemchecks — Daily-Report-Format mit Publish-Schritt dort ergänzen |

**Fazit Homelab:** Docker-Introspection in `pi-control`, Daily-Report-Output in `heartbeat`.

---

## Raspberry Pi / Hardware / IoT (6 Kandidaten)

| Slug | Was es tut | Bewertung | Begründung |
|---|---|---|---|
| `raspberry-pi-gpio` | GPIO-Steuerung (LED, Button, Servo) | **NACHBAUEN** | Growbox nutzt ESP32-GPIO über ESPHome, nicht direkt Pi-GPIO — aber direktes GPIO könnte für Growbox-Erweiterungen nützlich sein. Kleiner, Pi-spezifischer Skill |
| `dht11-temp` | DHT11 Temp/Humidity via CLI | **NACHBAUEN (integriert)** | Relevant für Growbox-Sensorik. Nicht als eigenen Skill, sondern in `growbox` als Script-Funktion |
| `led-ctrl` | GPIO via RPC remote | **SKIP** | RPC-Overhead nicht nötig, ESPHome macht das bereits |
| `raspberry-pi-camera-service` | Kamera, Foto, Video, GIF | **BEOBACHTEN** | Interessant für Growbox-Monitoring (Zeitraffer), aber kein Pi-Kamera-Modul vorhanden |
| `raspberry-pi-servo` | Servo-Steuerung | **SKIP** | Kein Servo-Bedarf im Stack |
| `esp32` | ESP32 Pitfalls (WiFi+ADC2, GPIO-Konflikte, FreeRTOS) | **NACHBAUEN** | Sehr spezifisch und wertvoll für ESPHome/Growbox-Entwicklung. Als Referenz-Skill in `growbox` einbauen oder eigenständig |
| `iot` | IoT-Setup, Protokolle, Security, HA-Integration | **SKIP** | Zu generisch |
| `rdk-x5-gpio` / `rdk-x5-tros` | RDK X5 Board (Horizon Robotics) | **SKIP** | Fremde Plattform |

**Fazit Pi/IoT:** GPIO-Skill für Growbox-Erweiterungen nachbauen; ESP32-Pitfalls-Wissen in Growbox-Skill integrieren; DHT11 als Script.

---

## Security / Cyber (3 Kandidaten)

| Slug | Was es tut | Bewertung | Begründung |
|---|---|---|---|
| `cyber-ir-playbook` | Incident Response Timelines aus Event-Logs | **BEOBACHTEN** | Für ein Homelab mit Auth-Logs und Fail2ban interessant, aber kein SIEM vorhanden |
| `cyber-kev-triage` | CVE-Triage nach KEV-Exploitation-Context | **BEOBACHTEN** | Relevant wenn `ai-vulnerability-tracker` eingebaut wird |
| `cyber-owasp-review` | OWASP Top 10 Mapping für App-Findings | **SKIP** | Kein Web-App-Dev im Stack |
| `ai-vulnerability-tracker` | Sucht AI-Vulnerabilities (Prompt Injection etc.) auf GitHub | **NACHBAUEN** | Passt zu Sicherheitsmonitoring. Aber China-Plattform (飞书) rausschmeißen, stattdessen in lokale Doku/HA-Notification pipen |

**Fazit Security:** `ai-vulnerability-tracker` als eigenen kleinen Skill nachbauen (GitHub-Search nach Prompt Injection / OpenClaw CVEs → Notification via HA/Telegram).

---

## Memory / Session (2 Kandidaten)

| Slug | Was es tut | Bewertung | Begründung |
|---|---|---|---|
| `triple-layer-memory` | 3-Layer Memory: Working/Session/Long-Term, cross-session Retrieval | **BEOBACHTEN** | Architekturell interessant. `openclaw-rag` übernimmt bereits Long-Term. Prüfen ob Middle-Layer (Session-Zusammenfassungen) fehlt |
| `session-rotate-80` | Neue Session bei 80% Context-Usage, ohne Mem0 | **NACHBAUEN** | Einfach, nützlich, kein externer Service nötig. Passt direkt in `heartbeat` oder als Mini-Skill |

**Fazit Memory:** Session-Rotate-Logik in `heartbeat` einbauen; `triple-layer-memory` Architektur als Inspiration für RAG-Ausbau lesen.

---

## Automation / Workflow (5 Kandidaten)

Alle überlappen mit dem was n8n + `heartbeat` + `runbook-maintenance` bereits tun.

| Slug | Was es tut | Bewertung | Begründung |
|---|---|---|---|
| `agentic-workflow-automation` | Workflow-Blueprints generieren | **SKIP** | Zu abstrakt, kein direkter Stack-Bezug |
| `automation-workflows` / `-0-1-0` | n8n/Zapier/Make Workflows | **SKIP** | Stack nutzt n8n direkt; Skill wäre Wrapper ohne Mehrwert |
| `automation-tool` / `automation-workflow-builder` | Generisch | **SKIP** | Zu generisch |
| `docs-pipeline-automation` | Google Sheets → Docs Pipeline | **SKIP** | Kein Google-Stack |
| `google-workspace-automation` | Google Workspace | **SKIP** | Kein Google-Stack |

---

## Dev / Tooling (4 Kandidaten)

| Slug | Was es tut | Bewertung | Begründung |
|---|---|---|---|
| `agentic-mcp-server-builder` | MCP-Server scaffolden | **BEOBACHTEN** | Falls MCP in den Stack kommt |
| `obsidian-cli-skills` | Obsidian Vault via CLI | **SKIP** | Kein Obsidian im Stack |
| `ml-experiment-tracker` | ML Experiment Tracking | **SKIP** | Kein ML-Dev im Stack |
| `dl-transformer-finetune` | Transformer Fine-tuning | **SKIP** | Pi ist kein Training-System |

---

## Sonstige / Irrelevant (Rest)

`0protocol`, `carsxe`, `wechat-automation`, `wechat-layout-publish`, `ai-ceo-automation`, `productivity-automation-kit`, `afrexai-business-automation`, `ai-automation-workflow`, `raspberry` (zu vage) — alle **SKIP**.

---

## Zusammenfassung: Aktionsplan

### Sofort in bestehende Skills erweitern

| Was | Ziel-Skill | Feature |
|---|---|---|
| Mehr HA-Entity-Domains (climate, media, camera) | `ha-control` | Aus `ha-ultimate` ableiten |
| HA Audit/Diagnostics-Modus (read-only) | `ha-control` | Aus `home-assistant-master` |
| Webhook-Empfang von HA | `ha-control` | Aus `ha-ultimate` |
| Docker-Introspection (container inspect, logs, stats) | `pi-control` | Aus `homeserver` |
| Daily Health Report mit Publish-Schritt | `heartbeat` | Aus `daily-health-report` |
| Session-Rotate bei 80% Context | `heartbeat` | Aus `session-rotate-80` |
| ESP32-Pitfalls-Referenz | `growbox` | Aus `esp32` |

### Neu nachbauen (klein, eigenständig)

| Skill | Basis-Inspiration | Warum eigenständig |
|---|---|---|
| `vuln-watch` | `ai-vulnerability-tracker` (ohne WeChat/飞书) | CVE/Prompt-Injection-Watch → HA-Notification; externe Plattform raus |

### Beobachten (kein Handlungsbedarf jetzt)

- `triple-layer-memory` — Inspiration für RAG-Ausbau
- `cyber-ir-playbook` / `cyber-kev-triage` — wenn Logging-Stack reifer ist
- `homeassistant-cli` — wenn `hass-cli` auf arm64 verfügbar
- `raspberry-pi-camera-service` — wenn Kamera-Modul angeschlossen

### Blacklist-Kandidaten

`carsxe`, `0protocol`, `wechat-automation`, `wechat-layout-publish`, `ai-ceo-automation`, `rdk-x5-gpio`, `rdk-x5-tros`, `led-ctrl` (RPC-Overhead), `homelab-cluster`, `homelab-ai`, `home-assistant-toolkit` (SSH-Vollzugriff).
