# Skill Build Plan — Best-of-Discovery

Abgeleitet aus `skill-discovery-analysis.md`. Jede Sektion beschreibt **was konkret gebaut wird**,
welches externe Skill die Vorlage war, und wie es sich vom Original unterscheidet.

---

## 1. `ha-control` erweitern

**Vorlage:** `ha-ultimate` (Domain-Coverage, Safety-Tiers, Blocked-List) + `home-assistant-master` (Audit-Modus, Risk-Tiers)

### Was jetzt fehlt

`ha-control` ist Growbox-only: 6 Entities, 3 Services. Kein Audit-Modus, keine Tiers.

### Was hinzukommt

#### 1a. Domain-Whitelist erweitern

Neue lesbare Domains (read-only, kein Write ohne explizite Freigabe):

| Domain | Entitäten | Zweck |
|---|---|---|
| `climate.*` | Thermostat, Heizung | Raumklima neben Growbox |
| `media_player.*` | Alle | Status-Abfrage |
| `sensor.*` (alle) | Alle Sensoren | Allgemeines Monitoring |
| `binary_sensor.*` | Tür/Fenster/Motion | Präsenz, Sicherheit |
| `weather.*` | Außenwetter | Kontext für Growbox |
| `input_boolean.*` | Schalter | Hilfsobjekte |
| `input_number.*` | Zahlenwerte | Hilfsobjekte |
| `scene.*` | Szenen | Auflisten |
| `automation.*` | Automationen | Auflisten/Diagnostics |
| `script.*` | Skripte | Auflisten |

Neue schreibbare Domains (nur mit Safety-Tier ≥ 1):

| Domain | Tier | Confirmation |
|---|---|---|
| `light.*` | 1 (low-risk) | nein |
| `switch.*` | 1 (low-risk) | nein |
| `input_boolean.*` | 1 (low-risk) | nein |
| `scene.*` (activate) | 1 (low-risk) | nein |
| `climate.*` | 2 (sensitive) | ja — "Temperatur auf X°C setzen?" |
| `lock.*` | 2 (critical) | ja + explicit confirm |
| `cover.*` (garage) | 2 (critical) | ja + explicit confirm |
| `alarm_control_panel.*` | 2 (critical) | ja + explicit confirm |

#### 1b. Safety-Tier-System (aus `ha-ultimate`)

```
Tier 0: Read-only — immer erlaubt
Tier 1: Low-risk writes — erlaubt ohne Confirmation
Tier 2: Sensitive writes — User-Confirmation erforderlich
Tier 3: Platform-Actions (restart/update) — BLOCKIERT
```

Neue Datei in `ha-control`: `config/blocked-entities.json`
```json
{ "blocked": [], "notes": "Hard-blocked entities, never callable" }
```

Script `scripts/check-tier.sh <entity_id>` → gibt Tier zurück.

#### 1c. Audit/Diagnostics-Modus (aus `home-assistant-master`)

Neues Subcommand: `scripts/audit.sh`

```bash
scripts/audit.sh states              # Alle Entity-States als JSON
scripts/audit.sh history <entity>    # State-History
scripts/audit.sh logs                # HA-Logbook (letzte 50 Einträge)
scripts/audit.sh automations         # Alle Automationen + Status
scripts/audit.sh integrations        # Integration-Health
scripts/audit.sh health              # HA-Core-Health-Check
```

Alles read-only. Kein Write-Pfad in `audit.sh`.

#### 1d. Entity-Listing (aus `ha-ultimate` `ha.sh list`)

Erweiterung von `get-state.sh`:
```bash
scripts/list-entities.sh all         # Alle Entities
scripts/list-entities.sh light       # Nur lights
scripts/list-entities.sh climate     # Nur climate
scripts/list-entities.sh <domain>    # Beliebige Domain
```

#### 1e. Webhook-Empfang (aus `ha-ultimate`)

SKILL.md-Dokumentation: HA kann Webhooks an OpenClaw senden.
Pattern: HA Automation → `POST http://192.168.2.101:18789/webhook/<id>`
Kein Script nötig — nur Dokumentation im SKILL.md + Beispiel-Automation-YAML.

### Nicht übernehmen

- Node.js `inventory.js` → kein Node.js auf dem Pi
- SSH-basierte Aktionen aus `home-assistant-toolkit`
- MCP-Protokoll aus `mcp-hass`
- Python-Bridge aus `home-assistant-bridge-python`

---

## 2. `pi-control` erweitern

**Vorlage:** `homeserver` (Docker-Introspection, Stats, TUI)

### Was jetzt fehlt

`docker-compose.sh` kann nur `ps`, `restart`, `logs`. Kein `inspect`, kein `stats`, keine Container-Details.

### Was hinzukommt

Erweiterung `scripts/docker-compose.sh`:

```bash
docker-compose.sh stats              # CPU/RAM aller Container (docker stats --no-stream)
docker-compose.sh inspect <service>  # Container-Details: Ports, Volumes, Env-Keys (ohne Values)
docker-compose.sh top <service>      # Laufende Prozesse im Container
docker-compose.sh images             # Alle Images + Größe
```

Erweiterung `scripts/metrics.sh`:

```bash
metrics.sh load                      # Load-Average 1/5/15min
metrics.sh swap                      # Swap-Nutzung
metrics.sh network                   # TX/RX der letzten 60s (ifstat oder /proc/net/dev)
metrics.sh all                       # Alles auf einmal: temp + ram + load + disk + swap
```

Neues Script `scripts/status-full.sh`:
- Ruft `docker-compose.sh stats` + `metrics.sh all` + `disk.sh df` auf
- Formatiert als kompakter Block für Telegram `/status` (erweiterter Report)

### Nicht übernehmen

- `homebutler` CLI (externe Abhängigkeit)
- Wake-on-LAN (kein Bedarf)
- Port-Scanning (`homeserver`-Feature, zu breiter Zugriff)
- Web-Dashboard (Portainer ist bereits drin)
- Multi-Server SSH

---

## 3. `heartbeat` erweitern

**Vorlagen:** `daily-health-report` (Report-Format + Publish) + `session-rotate-80` (Context-Guard)

### 3a. Daily Health Snapshot (aus `daily-health-report`)

Was `daily-health-report` hat, was `heartbeat` noch nicht publisht:
- Strukturiertes Format: Uptime / RAM / Swap / Load / Disk / NVMe-Temp
- Als eigenständige Telegram-Nachricht (nicht im Heartbeat-Report versteckt)
- Log-Eintrag pro Run

**Umsetzung:** Neues Script `scripts/daily-health.sh` in `pi-control` (da es System-Metriken nutzt).
`heartbeat` ruft `daily-health.sh` täglich im 07:00-Lauf auf und sendet Output als Telegram-Nachricht.

Format (inspiriert von `daily-health-report`):
```
📊 pilab Daily Health — 2026-04-08 07:00
Uptime:  12d 4h 23m
RAM:     2.1 GB / 8.0 GB (26%)
Swap:    0 MB / 512 MB (0%)
Load:    0.42 / 0.38 / 0.31
Disk:    48 GB / 232 GB (21%)
NVMe:    38°C
```

### 3b. Context Guard / Session-Rotate (aus `session-rotate-80`)

Das Original nutzt einen Python-Script `context_guard.py` der `[ROTATE_NEEDED]` emittiert.
Unser Stack nutzt kein Mem0, also passt das direkt.

**Umsetzung:** `scripts/context-guard.py` in `heartbeat`:
```python
# Schwellwert: 80% des Context-Fensters
# Input: aktuelle Token-Nutzung aus OpenClaw Runtime
# Output: [ROTATE_NEEDED] oder [ROTATE_NOT_NEEDED]
```

Integration in `heartbeat`: vor dem nächsten Task-Block Context prüfen.
Bei `[ROTATE_NEEDED]` → Handoff-Summary schreiben und `[NEW_SESSION]` triggern.

---

## 4. `growbox` erweitern

**Vorlage:** `esp32` (GPIO-Restriktionen, WiFi-Pitfalls, FreeRTOS, OTA)

### Was hinzukommt

Neuer Abschnitt im Growbox-Skill: **ESP32/ESPHome-Referenz**

Kein neues Script — nur Wissen als Referenz-Sektion in `growbox/SKILL.md`:

```markdown
## ESP32 / ESPHome Referenz

### GPIO-Restriktionen (kritisch)
- GPIO 6-11: NICHT verwenden — direkt mit Flash verbunden → Crash
- GPIO 34-39: Nur Input, kein Output
- GPIO 0, 2, 12, 15: Strapping-Pins → Bootverhalten beachten
- ADC2 (GPIO 0,2,4,12-15,25-27): Nicht nutzbar wenn WiFi aktiv → ADC1 nutzen

### WiFi-Fallstricke
- `WiFi.mode()` VOR `WiFi.begin()` aufrufen
- Event-basiert mit `WiFi.onEvent()` statt `WiFi.status()` pollen
- Static IP statt DHCP: 2-5s schneller beim Connect

### OTA Updates
- Zwei OTA-Partitionen nötig — Partition-Schema prüfen
- `ESP.getFreeSketchSpace()` vor OTA prüfen
- `ArduinoOTA` blockiert während Update — nicht in time-critical Code

### Power / Brown-Out
- WiFi TX: bis 300mA Peaks — Netzteil muss das abkönnen
- Deep Sleep: nur RTC-GPIOs für Wakeup (GPIO 0,2,4,12-15,25-27,32-39)

### LEDC statt analogWrite
- Kein natives `analogWrite()` → LEDC nutzen:
  `ledcSetup(ch, freq, res)` → `ledcAttachPin(pin, ch)` → `ledcWrite(ch, val)`
```

---

## 5. `vuln-watch` — neuer Skill

**Vorlage:** `ai-vulnerability-tracker` (Kern-Idee: GitHub-Search nach AI-CVEs)
**Radikale Vereinfachung:** WeChat/飞书 raus, GitHub-API direkt, Ausgabe → Telegram + HA-Notification

### Zweck

Sucht wöchentlich auf GitHub nach neuen Issues/PRs/Commits zu:
- `prompt injection`
- `prompt jailbreak`
- `LLM vulnerability`
- `jailbreak CVE`
- `openclaw security` (eigener Stack)

Dedupliziert nach URL, schreibt neue Funde in `docs/monitoring/vuln-log.md` und sendet Top-5 via Telegram.

### Struktur

```
agent/skills/vuln-watch/
├── SKILL.md
└── scripts/
    └── vuln-search.sh     # GitHub-Search → Dedup → Output
```

### Script-Logik (`vuln-search.sh`)

```bash
# GitHub Search API: code, issues, commits
# Zeitraum: letzte 7 Tage (created:>YYYY-MM-DD)
# Quellen: github.com/search?q=<term>&type=issues&sort=created&order=desc
# Dedup: URL-Set aus vuln-log.md gegen neue Ergebnisse prüfen
# Output: neue Funde als Markdown-Tabelle
# Anhängen an: ~/docs/monitoring/vuln-log.md
# Telegram: Top 5 neue Funde
```

### Integration in `heartbeat`

Wöchentlich (Montags 07:00): `~/scripts/skills vuln-watch --weekly`

### Scope-Grenzen

- Nur GitHub-Search-API (kein Scraping)
- Read-only auf alle externen Quellen
- Schreibt nur in `docs/monitoring/vuln-log.md`
- Kein API-Key nötig (GitHub unauthenticated: 10 req/min, reicht für 5 Queries/Woche)

---

## Umsetzungsreihenfolge

| Prio | Was | Aufwand | Mehrwert |
|---|---|---|---|
| 1 | `pi-control`: `stats` + `inspect` + `metrics.sh all` | klein | sofort nützlich bei `/status` |
| 2 | `heartbeat`: Daily Health Snapshot | klein | täglicher Überblick |
| 3 | `ha-control`: Domain-Whitelist + `list-entities.sh` | mittel | HA-Nutzbarkeit stark erweitert |
| 4 | `ha-control`: Safety-Tiers + `audit.sh` | mittel | Sicherheit + Diagnostics |
| 5 | `growbox`: ESP32-Referenz | winzig | sofort als Doku-Erweiterung |
| 6 | `heartbeat`: Context Guard | klein | autonomes Session-Management |
| 7 | `vuln-watch`: neuer Skill | mittel | Security-Monitoring |
| 8 | `ha-control`: Webhook-Doku | winzig | HA → OpenClaw Events |

---

## Was wir NICHT bauen

| Kandidat | Warum nicht |
|---|---|
| `gpio-growbox` | SHT-Sensoren laufen auf ESP32, nicht Pi-GPIO direkt |
| `homelab-cluster` / `homelab-ai` | Kein Ollama/LLM-Inference auf dem Pi |
| `home-assistant-toolkit` | SSH-Vollzugriff widerspricht Whitelist-Ansatz |
| `triple-layer-memory` (jetzt) | RAG bereits vorhanden; Session-Rotate deckt den Akutbedarf |
| `wechat-*` / `rdk-*` / `carsxe` | Falsche Plattform |
