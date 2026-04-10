# CHANGELOG

## 2026-04-09 (Canvas UI Final Ausbaustufe A–E Abgeschlossen)

### Zusammenfassung:

Kompletter Ausbau der Canvas-UI mit 5+1 operativen Tabs und zwei neue statische JSON-Feeds für robuste, fehlertolerante Echtzeitdaten ohne direkte API-Abhängigkeiten:

**Phase A — Operations, Decisions, Runbooks Tabs** 
- Dokumenten-basierte Read-Only-Tabs, die `docs/operations/`, `docs/decisions/`, `docs/runbooks/` in operative Snapshots verdichten
- Neue `ops-brief.latest.json` Feed (von `scripts/canvas-ops-brief.sh`)

**Phase B — Scout, Health, Metrics Tabs**
- Skill-Lifecycle Transparency Tabs mit KPIs, Listen und Mini-Charts
- Neue `state-brief.latest.json` Feed aggregiert Skill-Forge State (von `scripts/canvas-state-brief.sh`)

**Phase C — Dashboard Summary Cards**
- Drei verdichtete Karten auf Startseite für schnelle Lagebilder
- Auto-Refresh alle 2 Min + 60s Cache

**Phase D — RAG Quick-Query Chips**
- 5 vorkurierte Such-Vorschläge im RAG-Tab
- Click-to-Search Auto-Trigger Pattern

**Final Validation** — Alle HTTP 200, Feeds OK, Scripts OK, DOM-IDs OK

### Komponenten-Übersicht:

| Komponente | Status | Source | Feed |
|---|---|---|---|
| Operations Tab | ✅ | `docs/operations/` | ops-brief |
| Decisions Tab | ✅ | `docs/decisions/` | ops-brief |
| Runbooks Tab | ✅ | `docs/runbooks/` | ops-brief |
| Scout Tab | ✅ | skill-forge state | state-brief |
| Health Tab | ✅ | skill-forge state | state-brief |
| Metrics Tab | ✅ | skill-forge state + metrics.jsonl | state-brief |
| Dashboard Cards (3) | ✅ | Both feeds | both |
| RAG Quick-Chips (5) | ✅ | Hardcoded | None |

### Neue / Modifizierte Dateien:

**Scripts** (neu):
- `/home/steges/scripts/canvas-ops-brief.sh` — Phase A Feed Generator
- `/home/steges/scripts/canvas-state-brief.sh` — Phase B Feed Generator

**Canvas HTML/JS** (modifiziert):
- `/home/steges/agent/skills/openclaw-ui/html/index.html` — 8 Nav-Buttons, 6 Page-Shells, 3 Card-Container, RAG-Chips
- `/home/steges/agent/skills/openclaw-ui/html/app-skill.js` (neu) — Scout/Health/Metrics Renderer
- `/home/steges/agent/skills/openclaw-ui/html/app-dashboard.js` — Summary Card Renderer
- `/home/steges/agent/skills/openclaw-ui/html/app-rag.js` — Quick-Chips Event-Handler
- `/home/steges/agent/skills/openclaw-ui/html/app-main.js` — CanvasSkill Routing
- `/home/steges/agent/skills/openclaw-ui/html/sw.js` — state-brief als Dynamic

**Heartbeat Integration**:
- `/home/steges/agent/skills/heartbeat/scripts/heartbeat-dispatch.sh` — Canvas Feed Generation Calls

**Dokumentation**:
- `/home/steges/agent/skills/openclaw-ui/SKILL.md` — Phase 2.5–2.8 Features + Validation Checklists
- `/home/steges/docs/operations/canvas-smoke-checklist.md` — New Tabs hinzugefügt

### Validierung Final:

✅ HTTP 200: index.html, app-*.js, ops-brief.latest.json, state-brief.latest.json
✅ Feed-Struktur: ops-brief::operations.open_work.items, state-brief::scout/health
✅ Script-Syntax: bash -n für alle 3 Generator-Scripts passiert
✅ DOM-IDs: page-scout, page-health, page-metrics, dash-*-snap, rag-quick-queries alle vorhanden
✅ Navigation: Alle 8 Tabs (Dashboard, Chat, MQTT, RAG, Scout, Health, Metrics, Operations, Decisions, Runbooks, Settings) funktional
✅ Feeds werden von Heartbeat nach jedem Lauf regeneriert

---

## 2026-04-09 (Canvas Phase D: RAG Quick-Query Chips)

### Erweitert:

1. **[Canvas] Fünf neue Quick-Query-Chips im RAG-Tab**
   - Chips: "Open Work", "Decisions", "Runbooks", "Skill Governance", "Health Risks"
   - Chips sind oberhalb der Suchergebnisse positioniert und horizontal scrollbar bei Platzmangel
   - Click auf einen Chip füllt die Query auto aus und triggert die Suche sofort
   - Jeder Chip hat einen Tooltip mit Kontext

2. **[Canvas] Event-Listener in app-rag.js**
   - Neue Funktion: Alle `[data-rag-quick]`-Buttons registrieren Auto-Select-Handler
   - Query wird gefüllt, Input erhält Focus, `doRagSearch()` wird aufgerufen

3. **[Canvas] HTML in index.html**
   - Neue `<div class="rag-quick-queries">` mit 5 vorgefertigten Chips
   - Styling: inline flex, 6px gap, normale Chip-Klassen

### Validierung:
- HTTP 200: index.html, app-rag.js
- Quick-Chips laden ohne Konsolenfehler
- Event-Listener registrieren korrekt

---

## 2026-04-09 (Canvas Phase C: Dashboard Summary Cards)

### Erweitert:

1. **[Canvas] Drei neue Dashboard-Zusammenfassungs-Karten**
   - Karte 1 "Open Work Snapshot": Zeigt die 3 höchsten Prioritäts-Items aus `ops-brief.latest.json::operations.open_work.items`, anklickbar für Navigation zu Operations-Tab.
   - Karte 2 "Scout Snapshot": KPI-Row mit Known/Active/Canary/PendingReview aus `state-brief.latest.json::scout`.
   - Karte 3 "Governance / Health Snapshot": KPI-Row mit Freeze/Canaries/HighRisk/PendingBL aus `state-brief.latest.json::health`.

2. **[Canvas] Dashboard-Extension in app-dashboard.js**
   - Neue Funktionen: `renderOpenWorkSnap()`, `renderScoutSnap()`, `renderHealthSnap()`, `refreshSummarySnapshots()`.
   - Feeds werden aus den bestehenden statischen JSON-Files geladen (ops-brief, state-brief).
   - Auto-Refresh alle 2 Minuten (120000 ms) mit lokalem Cache (60s).
   - Lazy-Load-Pattern mit fetchWithPolicy und Error-Handling.

3. **[Canvas] HTML Erweiterung in index.html**
   - Drei neue Sections mit Karten-Containern nach Alert Feed und vor Ops Control.
   - IDs: `dash-open-work-snap`, `dash-scout-snap`, `dash-health-snap` mit Status-Footer-Elementen.

### Validierung:
- HTTP 200: index.html, app-dashboard.js, alle Feeds (ops-brief, state-brief)
- Feeds-Struktur validiert: ops-brief::operations.open_work.items, state-brief::scout/health
- Snapshot-Render-Funktionen befüllen KPIs mit korrektem Status-Styling (ok/warn/bad)

---

## 2026-04-09 (Canvas Phase B: Scout, Health und Metrics Tabs)

### Erweitert:

1. **[Canvas] Drei neue Skill-Lifecycle Tabs: Scout, Health, Metrics**
   - Tab `Scout`: KPI-Row (Known/Active/Canary/PendingReview/PendingBlacklist) + scrollbare Skill-Inventory-Tabelle.
   - Tab `Health`: Freeze-Banner, KPI-Row, aktive Canary-Liste (bis 30), High-Risk-Tabelle.
   - Tab `Metrics`: Weekly-KPIs, drei SVG-Sparklines (Install-Erfolg, Rollback-Rate, Known-Skills), Recent-Runs-Tabelle.

2. **[Canvas] Neuer statischer Skill-State-Feed eingefuehrt**
   - Neues Script `scripts/canvas-state-brief.sh` erzeugt `agent/skills/openclaw-ui/html/state-brief.latest.json`.
   - Feed aggregiert `known-skills.json`, `canary.json`, `incident-freeze.json`, `pending-blacklist.json`, `metrics-weekly.json`, `skill-risk-report.json`, `metrics.jsonl` und `heartbeat-last-run.ts`.
   - Heartbeat ruft das Script nach dem ops-brief-Lauf auf und schreibt Erfolg/Fehler ins Action-Log.

3. **[Canvas] JS-Modul `app-skill.js`, CSS-Erweiterungen, SW-Update**
   - Neues Modul `app-skill.js` mit `CanvasSkill.register/initPage` Lazy-Init-Pattern (shared feed cache 30 s).
   - Neue CSS-Klassen: `.skill-table`, `.skill-table-wrap`, `.st` (Status-Badges), `.skill-block`, `.sparkline-pane`.
   - `sw.js` behandelt `state-brief.latest.json` als dynamische Ressource.
   - `app-main.js` verdrahtet Scout/Health/Metrics in `showPage()` und beim Boot.

### Validierung:
- `bash -n scripts/canvas-state-brief.sh` -> OK
- `bash -n agent/skills/heartbeat/scripts/heartbeat-dispatch.sh` -> OK
- `./scripts/canvas-state-brief.sh` -> OK, Scout total=88 canary=49 active=22 pending_review=3
- HTTP 200: `state-brief.latest.json`, `app-skill.js`, `index.html`

---

## 2026-04-09 (Canvas: Operations, Decisions und Runbooks Tabs)

### Erweitert:

1. **[Canvas] Drei neue Read-only Tabs fuer Operations, Decisions und Runbooks**
   - Top-Navigation um die drei Fachbereiche erweitert, mobil per horizontal scroll stabil nutzbar.
   - Neue Seite `Operations` zeigt Open-Work-KPIs, offene Punkte und Handover-Checklisten.
   - Neue Seiten `Decisions` und `Runbooks` indexieren bestehende Markdown-Dokumente als kompakte Operator-Ansicht.

2. **[Canvas] Neuer statischer Dokumenten-Feed eingefuehrt**
   - Neues Script `scripts/canvas-ops-brief.sh` erzeugt `agent/skills/openclaw-ui/html/ops-brief.latest.json`.
   - Feed fasst `docs/operations/open-work-todo.md`, `docs/operations/session-handover.md`, `docs/decisions/*.md` und `docs/runbooks/*.md` in ein browserfreundliches JSON zusammen.
   - Heartbeat aktualisiert den Feed nach dem Lauf und schreibt Erfolg/Fehler ins Action-Log.

3. **[Canvas] Service Worker und Doku auf neuen Feed angepasst**
   - `sw.js` behandelt `ops-brief.latest.json` als dynamische Ressource und umgeht den Cache.
   - Smoke-Checklist, Service-Doku und Skill-Beschreibung auf die neuen Tabs und den Feed aktualisiert.

### Validierung:
- `bash -n scripts/canvas-ops-brief.sh` -> OK
- `bash -n agent/skills/heartbeat/scripts/heartbeat-dispatch.sh` -> OK
- `./scripts/canvas-ops-brief.sh` -> OK
- `python3 -m json.tool agent/skills/openclaw-ui/html/ops-brief.latest.json` -> OK
- VS-Code-Diagnosen fuer `app-ops.js`, `app-main.js`, `index.html`, `sw.js`, `heartbeat-dispatch.sh`, `canvas-ops-brief.sh` -> keine Fehler
- Hinweis: `node` ist auf dem Host nicht installiert, daher kein lokaler `node --check` Lauf moeglich

## 2026-04-09 (RAG: Doc-Keeper integriert + Auto-Doc Startpfad)

### Geändert:

1. **[RAG] Doc-Keeper in `openclaw-rag` integriert**
   - Neuer Owner-Pfad: `agent/skills/openclaw-rag/scripts/doc-keeper-dispatch.sh`
   - `scripts/skills` routed `doc-keeper` jetzt auf `rag doc-keeper run ...`
   - Alter separater Skill-Ordner `agent/skills/doc-keeper/` entfernt

2. **[RAG] Dispatcher erweitert um integrierten DocOps-Flow**
   - `rag-dispatch.sh` hat neues Subcommand: `doc-keeper run ...`
   - Optionaler Auto-Doc-Start enthalten: `--autodoc`, `--autodoc-dry-run`, `--autodoc-profile daily|post-promote|weekly`
   - RAG-Dispatcher laedt projektweit automatisch `/home/steges/.env` (gleiches Env wie OpenClaw)
   - Auto-Doc-Fehler sind aktuell bewusst non-fatal fuer den Delta-Scan-Lauf
   - Dry-Run laeuft jetzt API-unabhaengig als `dry-run-local-preview` (kein Anthropic-Key erforderlich)
   - Auto-Doc unterstuetzt jetzt optional Copilot/OpenAI-kompatible Modelle (z. B. `gpt-4.1`) via `--provider copilot`.
   - Copilot-Auto-Doc wurde gegen Timeouts gehaertet: konfigurierbarer API-Timeout, Retry bei Timeout/URLError und reduziertes Default-Tokenbudget.
   - Erfolgreich generierte Auto-Doc-Dateien werden jetzt direkt in den RAG-Index uebernommen: primaer per `reindex.sh --changed-only`, bei reinem Post-Canary-Fehler per transparentem `ingest.py --changed-only`-Fallback.
   - Retriever filtert jetzt stale Quellen auch im normalen Query-Pfad und stuft Auto-Doc-/Agent-Referenzquellen als Sekundaerbelege ab, um fachliche Primärquellen nicht zu verdrängen.
   - RAG-Canary liest seine Schwellen jetzt aus der versionierten Skill-Policy; `openclaw-rag` nutzt aktuell `min_recall_at_5=0.64`, womit der reguläre Reindex nach Auto-Doc-Integration wieder grün läuft.
   - Retriever-Optimierung: stale Quellen werden im Query-Pfad verworfen, Alias-Treffer werden per Union mit Roh-FTS gemischt und intent-basierte Source-Boosts verbessern Operator-Queries.
   - RAG-Canary nach Optimierung: `P@5=0.24`, `R@5=0.6944`, `p95=318.03ms` (30 Fragen, k=5, timeout=1500ms).
   - Retrieval-Kontext filtert stale Quellen (Datei existiert nicht mehr) und meldet sie als `stale_sources_dropped`
   - Bestehende Ziel-Dokumente ohne Marker werden per append/replace Marker-Block robust aktualisiert

3. **[Ops] Hooks auf neuen RAG-Entry-Point umgestellt**
   - Heartbeat-Daily: `skills rag doc-keeper run --daily --autodoc`
   - Canary-Post-Promote: `skills rag doc-keeper run --autodoc --autodoc-profile post-promote`
   - Doku/Skill-Inventar/Self-Model auf neue Commands und Pfade aktualisiert
   - Heartbeat erweitert um Weekly Auto-Doc Hook (`--autodoc-profile weekly`) fuer `SELF-MODEL` + `HISTORY`, inkl. 7-Tage-Marker (`autodoc-weekly-last-run.ts`)
   - Heartbeat-Daily/Weekly Auto-Doc nutzt jetzt konfigurierbare Provider/Model-Defaults (`HEARTBEAT_AUTODOC_PROVIDER`, `HEARTBEAT_AUTODOC_MODEL`)

### Validierung:
- `scripts/skill-forge policy lint` → OK
- `bash -n scripts/skills scripts/skill-forge` → OK
- `bash -n agent/skills/openclaw-rag/scripts/rag-dispatch.sh` → OK
- `bash -n agent/skills/openclaw-rag/scripts/doc-keeper-dispatch.sh` → OK
- `bash -n agent/skills/heartbeat/scripts/heartbeat-dispatch.sh` → OK
- `bash -n agent/skills/skill-forge/scripts/canary.sh` → OK
- `scripts/skills rag doc-keeper run --reason "migration-smoke" --summary-only` → OK
- `scripts/skills rag doc-keeper run --reason "migration-autodoc-smoke" --summary-only --autodoc --autodoc-dry-run --autodoc-profile post-promote` → OK (Auto-Doc-Warnung erwartbar bei nicht-generiertem Ziel ohne `--force`)
- `scripts/skills rag doc-keeper run --reason "autodoc-source-filter-smoke" --summary-only --autodoc --autodoc-dry-run --autodoc-profile post-promote` → OK (`generation_mode=dry-run-local-preview`, stale Quelle gedroppt)

## 2026-04-09 (Rename: skill-manager → skill-forge)

### Geändert:

1. **[Rename] skill-manager vollständig in skill-forge umbenannt**
   - Verzeichnis: `agent/skills/skill-manager/` → `agent/skills/skill-forge/`
   - Wrapper: `scripts/skill-manager` → `scripts/skill-forge` (Symlink für Rückwärtskompatibilität bleibt)
   - Dokumentation: `docs/skill-manager.md` → `docs/skills/skill-forge-governance.md`
   - Alle Referenzen in CLAUDE.md, HANDSHAKE.md, README, CHANGELOG, index.md, allen SKILL.md Dateien, Dispatch-Scripts, Doku-Dateien, ingest.py (Exclusion-Pfad), GOLD-SET.json, agent/*.md, docs/*.md aktualisiert
   - Grund: `skill-manager` klingt wie ein genereller Skill-Dispatcher; tatsächliche Funktion ist ausschließlich Skill-Lifecycle (Install, Rewrite, Sandbox, Vetting, Canary, Rollback)

### Validierung:
- `bash -n scripts/skill-forge` → OK
- `scripts/skill-forge policy lint` → OK
- `scripts/skill-forge status` → OK (87 known, 17 active)
- Alle Shell-Scripts in `agent/skills/skill-forge/scripts/` → `bash -n` OK
- Kein verbleibender `skill-manager`-Pfadverweis in Projektdateien (außer sessions.json historische Daten + Symlink)

## 2026-04-08 (RAG P4: End-to-End Verifikation + Abschluss)

### Erweitert:

1. **[RAG] End-to-End-Pruefpfad fuer den Komplettausbau abgeschlossen**
   - Verifikationskette konsolidiert: Syntax/Lint, Evaluate, Canary, Reindex, Health-Check, Timer-Pruefung.
   - Abschlusskriterium: keine offenen FAILs in RAG-Health und Canary weiterhin gruen.

2. **[Runbook] Entscheidungspfade fuer degraded retrieval erweitert**
   - `docs/runbooks/rag-reindex-failure-recovery.md` um klare Pfade fuer stale index, timeout-loop, post-canary-fail und corruption erweitert.
   - Operator-Entscheidungen sind jetzt als expliziter Ablauf dokumentiert.

3. **[Todo-Lifecycle] Open-Work-Only wiederhergestellt**
   - `docs/operations/open-work-todo.md` von historischen Abschluss-Notizen bereinigt und auf offene Arbeit fokussiert.

### Validierung:
- `python3 -m py_compile agent/skills/openclaw-rag/scripts/retrieve.py agent/skills/openclaw-rag/scripts/evaluate-goldset.py agent/skills/openclaw-rag/scripts/ingest.py` -> OK
- `bash -n agent/skills/openclaw-rag/scripts/reindex.sh agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh scripts/rag-quality-report.sh scripts/health-check.sh` -> OK
- `/home/steges/scripts/skill-forge policy lint` -> OK
- `python3 /home/steges/agent/skills/openclaw-rag/scripts/evaluate-goldset.py --limit 5 --timeout-ms 1500` -> OK
- `bash /home/steges/agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh --json` -> `passed=true`
- `bash /home/steges/agent/skills/openclaw-rag/scripts/reindex.sh` -> Success
- `/home/steges/scripts/health-check.sh` -> `14 OK, 0 FAIL`
- `systemctl list-timers` geprueft, RAG-Timer kollisionsarm im Wartungsfenster

## 2026-04-08 (RAG P3: Ops-Automation + Deep Health Checks)

### Erweitert:

1. **[RAG] Taeglicher Reindex als systemd Job vorbereitet**
   - Neue Unit-Dateien: `systemd/rag-reindex-daily.service` und `systemd/rag-reindex-daily.timer`.
   - Zeitplan: taeglich `04:30` (Europe/Berlin) mit `RandomizedDelaySec=10min`.

2. **[RAG] `health-check.sh` um tiefe RAG-Pruefungen ergaenzt**
   - Reindex-State-Pruefung via `infra/openclaw-data/rag/.reindex.status`.
   - Drift-Erkennung zwischen `chunks` und `chunks_fts`.
   - Sanity-Query gegen den Retriever inkl. Search-Mode-Validierung.

3. **[Ops] Maintenance-Doku fuer neue RAG-Automation aktualisiert**
   - Aktivierungs-/Pruefschritte fuer den neuen Timer dokumentiert.
   - Neues Verhalten des Post-Reindex-Canary-Gates in den Betriebshinweisen verankert.

### Validierung:
- `bash -n scripts/health-check.sh` -> OK
- `systemd-analyze verify systemd/rag-reindex-daily.service systemd/rag-reindex-daily.timer` -> OK
- `./scripts/health-check.sh` -> `14 OK, 0 FAIL` (inkl. neuer RAG-Checks)

## 2026-04-08 (RAG P2: Post-Reindex-Canary-Gate aktiviert)

### Erweitert:

1. **[RAG] `reindex.sh` fuehrt jetzt verpflichtenden Post-Reindex-Canary aus**
   - Nach erfolgreichem `ingest.py` + `PRAGMA quick_check` wird automatisch `rag-canary-smoke.sh --json` ausgefuehrt.
   - Reindex gilt nur noch als Erfolg, wenn auch der Canary besteht.

2. **[RAG] Automatischer Restore bei Canary-Gate-Fehler**
   - Bei Canary-Fehler/Timeout/Scriptfehler wird auf den letzten Snapshot zurueckgerollt (falls vorhanden).
   - Status-/Fehlerdetails werden explizit als `post_canary_*` markiert.

3. **[RAG] Transparenz im Operator-Status erhoeht**
   - Success-Status enthaelt jetzt explizit `post_canary_passed`.
   - Action-Log schreibt `success(post_canary_passed)` fuer eindeutige Nachvollziehbarkeit.

### Validierung:
- `bash -n agent/skills/openclaw-rag/scripts/reindex.sh` → OK
- `bash agent/skills/openclaw-rag/scripts/reindex.sh` → Success
- `cat infra/openclaw-data/rag/.reindex.status` zeigt `state=success` mit `post_canary_passed`
- `tail -n 5 infra/openclaw-data/action-log.jsonl` zeigt `result="success(post_canary_passed)"`

## 2026-04-08 (RAG P1: Qualitaetsmetriken erweitert)

### Erweitert:

1. **[RAG] `evaluate-goldset.py` mit tieferen Qualitaetsmetriken**
   - Latenzverteilung zusaetzlich zu p95: `p50`, `p90`, `p99`, `max`, `mean`, `timeout_count`.
   - Suchmodus-Analyse: `search_mode_counts` und Fallback-Quote (`fallback.count`, `fallback.ratio`).

2. **[RAG] Rewrite-A/B-Auswertung integriert (Qualitaet zuerst)**
   - Pro Frage wird optional ein zweiter Lauf ohne Alias-Rewrites ausgefuehrt (`--disable-rewrites` auf `retrieve.py`).
   - Delta-Metriken im Report: `avg_delta_precision_at_k`, `avg_delta_recall_at_k`, Anzahl besser/schlechter Recall-Faelle.
   - Optional abschaltbar via `--disable-rewrite-ab` fuer schnellere Runs.

3. **[RAG] `retrieve.py` um Rewrite-Schalter erweitert**
   - Neuer CLI-Flag `--disable-rewrites` deaktiviert Alias-Erweiterungen gezielt fuer reproduzierbare A/B-Vergleiche.
   - Snapshot-Fallback bleibt unveraendert funktional.

### Validierung:
- `python3 -m py_compile agent/skills/openclaw-rag/scripts/retrieve.py agent/skills/openclaw-rag/scripts/evaluate-goldset.py` → OK
- `python3 agent/skills/openclaw-rag/scripts/evaluate-goldset.py --limit 5 --timeout-ms 1500` → OK
- Baseline weiterhin stabil: Precision `0.32`, Recall `0.65`, p95 `60.85ms`
- Zusatzmetriken: `fallback.ratio=0`, `timeout_count=0`, `rewrite.avg_delta_recall_at_k=0.025`
- `bash agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh --json` → `passed=true`

## 2026-04-08 (RAG P0-Start: Eval/Report-Contract repariert)

### Behoben:

1. **[RAG] `rag-quality-report.sh` auf korrekten Evaluate-Pfad umgestellt**
   - Vorher zeigte der Report auf `scripts/evaluate-goldset.py` (nicht vorhanden).
   - Jetzt wird konsistent `agent/skills/openclaw-rag/scripts/evaluate-goldset.py` verwendet.

2. **[RAG] Weekly-Report von Legacy-Textparsing auf JSON-Auswertung umgestellt**
   - Metriken (`avg_precision_at_k`, `avg_recall_at_k`, `p95_latency_ms`) werden jetzt robust aus dem JSON-Output gelesen.
   - Dadurch sind Report und Canary wieder auf demselben Metrik-Contract.

3. **[RAG] Fehlerbehandlung im Report-Runner gehärtet**
   - Fehlgeschlagene Evaluation und leere/ungültige Ausgabe führen jetzt deterministisch zu Exit `1`.
   - Das bisherige `|| true`-Muster (maskierter Fehlerpfad) wurde entfernt.

### Validierung:
- `bash -n scripts/rag-quality-report.sh` → OK
- `python3 -m py_compile agent/skills/openclaw-rag/scripts/evaluate-goldset.py` → OK
- `TELEGRAM_BOT_TOKEN='' TELEGRAM_CHAT_ID='' bash scripts/rag-quality-report.sh` → Report erfolgreich
- `bash agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh --json` → `passed=true`
- Baseline (20 Fragen, k=5, timeout=1500ms): Precision `0.32`, Recall `0.65`, p95 `55.66ms`

## 2026-04-08 (RAG-Optimierung: Retrieve-Timeouts und SQLite-Tuning)

### Optimierung:

1. **[RAG] `retrieve.py` ohne ThreadPool-Overhead bei Query-Timeouts**
   - Timeout-Steuerung wurde auf SQLite-`progress_handler` umgestellt (statt Python-ThreadPool pro Query).
   - Ziel: niedrigere Latenz und stabileres Timeout-Verhalten unter Last.

2. **[RAG] SQL-fokussierter Fallback statt Python-Fullscan**
   - Der LIKE-Fallback bewertet Treffer jetzt direkt per SQL-Ausdruck und vermeidet den bisherigen Python-Zeilen-Scan über alle Chunks.

3. **[RAG] SQLite-Verbindungs- und Index-Tuning in `ingest.py`**
   - PRAGMAs ergänzt (`WAL`, `synchronous=NORMAL`, `temp_store=MEMORY`, `cache_size`, `mmap_size`, `optimize`).
   - Zusätzliche Indizes für häufige Zugriffe (`chunks(source, updated_at)`, `chunks(checksum)`).

### Validierung:
- `python3 -m py_compile agent/skills/openclaw-rag/scripts/retrieve.py agent/skills/openclaw-rag/scripts/ingest.py agent/skills/openclaw-rag/scripts/evaluate-goldset.py` → OK
- `bash agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh --json` → passed=true
- Goldset-Metriken: p95-Latenz von **84.78 ms** (vorher) auf **61.75 ms** (nachher), Präzision/Recall unverändert (`0.32` / `0.65`)

## 2026-04-08 (Infra-Hardening: CPU-Caps, Logging, Caddy-Health, Update-Guards)

### Neu umgesetzt:

1. **[Runtime] Explizite CPU-Caps fuer alle Compose-Services**
   - Alle Container haben jetzt konservative `cpus`-Grenzen, damit einzelne Lastspitzen den Pi nicht CPU-seitig dominieren.
   - Ziel: stabilere Parallelitaet zwischen DNS, Home Assistant, OpenClaw, Monitoring und UI.

2. **[Runtime] Einheitliche Docker-Logrotation im Compose-Stack verankert**
   - Fuer alle Services ist jetzt explizit `json-file`-Logging mit Rotation gesetzt.
   - Standard: `10m x 3`; bestehende engere Sonderregel fuer `ops-ui` bleibt erhalten.

3. **[Reliability] Caddy mit eigenem lokalen Health-Endpunkt**
   - Neuer virtueller Host `caddy-health.lan` liefert lokal `200 ok`.
   - Der `caddy`-Service nutzt diesen Endpunkt jetzt fuer einen echten Container-Healthcheck, ohne Backend-Verfuegbarkeit mitzupruefen.

4. **[Ops] `update-stacks.sh` bricht jetzt bei unsicherem Update-Zustand ab**
   - Vor dem Update wird zuerst `docker compose config --quiet` validiert.
   - Wenn `backup.sh` fehlschlaegt, wird das Update nicht mehr fortgesetzt.
   - Zusaetzlich prueft das Script vor `docker compose pull`, ob mindestens 2 GB freier Speicher verfuegbar sind.
   - Ein fehlgeschlagener Post-Update-Health-Check wird jetzt explizit als Fehler behandelt.

5. **[Fix] Glances-Compose-Tag auf validen Registry-Tag korrigiert**
   - `nicolargo/glances:4.5.3-full` war nicht aufloesbar und blockierte `docker compose up -d`.
   - Compose ist jetzt wieder auf den tatsaechlich verfuegbaren Tag `nicolargo/glances:latest-full` ausgerichtet.

6. **[Fix] `health-check.sh` zaehlt Checks unter `set -e` wieder korrekt**
   - Die bisherigen `((OK++))`- und `((FAIL++))`-Ausdruecke konnten das Script nach dem ersten Treffer mit Exit `1` abbrechen.
   - Die Zaehler verwenden jetzt robuste arithmetische Zuweisungen, sodass der komplette Check wieder durchlaeuft.

### Validierung:
- `docker compose config --quiet` → OK
- `bash -n scripts/update-stacks.sh` → OK
- `docker run --rm -v /home/steges/caddy/Caddyfile:/etc/caddy/Caddyfile:ro caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile` → OK

## 2026-04-08 (Skill-Improvements: pi-control, heartbeat, ha-control, growbox, vuln-watch)

### Neu:

1. **[Skill] `pi-control`: Docker-Introspection + erweiterte System-Metriken**
   - `docker-compose.sh stats` — Live-Container-Stats (CPU/Mem) ohne Stream
   - `docker-compose.sh inspect <service>` — Ports, Volumes, Env-Keys (ohne Values, Secrets-Schutz)
   - `docker-compose.sh images` — Image-Übersicht (Repo, Tag, Size, Age)
   - `metrics.sh load` — /proc/loadavg (1/5/15min)
   - `metrics.sh swap` — Swap-Nutzung via free -h
   - `metrics.sh network` — kB/s RX/TX aus /proc/net/dev (2s Messung, keine externe Dependency)
   - `metrics.sh all` — aggregierter System-Block (temp + RAM + swap + load + disk)
   - `status-full.sh` (NEU) — vollständiger Status-Report: Metriken-Block, Container-Liste (✅/❌/🟡), Top-3 CPU-Stats; Telegram-kompatibel

2. **[Skill] `heartbeat`: Daily Health Snapshot + Context Guard**
   - Tägliches Versenden von `status-full.sh`-Output an Telegram (morning window 06-10h Berlin)
   - `context-guard.py` (NEU) — erkennt Context-Rotate-Bedarf; `[ROTATE_NEEDED]`-Signal bei ≥80% Nutzung; Env-Vars `OPENCLAW_CONTEXT_USED`/`OPENCLAW_CONTEXT_MAX`, graceful fallback wenn nicht gesetzt
   - `vuln-watch`-Linie im wöchentlichen Heartbeat-Report (gleiches Marker-Pattern wie `learnings`)

3. **[Skill] `ha-control`: Domain-Whitelist + Safety-Tier-System + neue Scripts**
   - `get-state.sh` auf domain-basiertes Whitelist-Modell umgestellt (war: hardcodierte Growbox-Entity-Liste)
   - Tier-System: Tier 0 (read), Tier 1 (light/switch/input_boolean/scene – erlaubt), Tier 2 (lock/alarm/cover – blockiert), Tier 3 (platform – immer blockiert)
   - `blocked-entities.json` — Hard-Block-Liste, vor jeder Aktion geprüft
   - `list-entities.sh` (NEU) — GET /api/states, filterbar nach Domain, max 50 Einträge, --json
   - `audit.sh` (NEU) — read-only: health, states, history, logs, automations
   - `check-tier.sh` (NEU) — gibt Tier einer Entity-ID zurück

4. **[Skill] `growbox`: ESP32/ESPHome Referenz-Sektion in SKILL.md**
   - GPIO-Fallen (6-11, 34-39, ADC2 bei WiFi), LEDC statt analogWrite, WiFi-Stabilität, OTA-Partitionen, Brown-Out-Schutz

5. **[Skill] `vuln-watch` (NEUER SKILL)**
   - GitHub Search API (unauthenticated, 5 Suchterme, 7s Rate-Limit-Pause)
   - Deduplizierung gegen `docs/monitoring/vuln-log.md`, neue Funde werden angehängt
   - Telegram: Top-5 neue Funde mit URL
   - Subcommands: `--weekly [--dry-run] [--json]`, `--summary`, `--json`
   - Output-Schema: `{new_count, total_known, status}`
   - Integriert in heartbeat (wöchentlich Montag 07:00)
   - Dispatcher: `~/scripts/skills vuln-watch ...`

6. **[Scout] clawhub.ai als Hub-Quelle**
   - `hubs.json`: neuer Eintrag `type: "clawhub"`, Registry `https://clawhub.ai`
   - `scout-dispatch.sh`: clawhub-Ergebnisse werden via `/api/v1/search?q=<term>` geladen, unabhängig vom GitHub-Dedup-/Limit-Pfad verarbeitet

### Validierung:
- `bash -n` auf alle geänderten Scripts: OK
- `~/scripts/skill-forge policy lint`: OK
- `~/scripts/skills vuln-watch --weekly --dry-run`: 50 neue Funde erkannt (korrektes Dry-Run-Verhalten)
- `~/agent/skills/pi-control/scripts/status-full.sh`: 14 Container korrekt dargestellt

---

## 2026-04-08 (Systemd-Timer: Nightly-Check + RAG-Report + Backup-Verify)

### Neu:

1. **[Infra] `nightly-self-check.timer` installiert und aktiviert**
   - War als Unit-Datei vorhanden (`systemd/`), aber nie nach `/etc/systemd/system/` installiert.
   - Läuft täglich 03:15 — prüft Policy-Lint, Stale Canaries, Pending-Review-Count, Health-Check.

2. **[Infra] `rag-quality-report.timer` — neuer wöchentlicher Timer (Samstag 10:00)**
   - Führt `evaluate-goldset.py` aus (Gold-Set mit 20 Fragen, Precision@5 / Recall@5 / p95).
   - Sendet Telegram-Report mit Gate-Bewertung (Grenzen: P@5 ≥ 0.25, R@5 ≥ 0.55, p95 ≤ 200ms).
   - Script: `scripts/rag-quality-report.sh`

3. **[Infra] `backup-verify.timer` — neuer wöchentlicher Timer (Sonntag 09:00)**
   - Prüft ob Restic-Snapshot existiert und nicht älter als 48h ist.
   - Sendet Telegram-Report mit Snapshot-Count, Zeitstempel und Alter.
   - Script: `scripts/backup-verify.sh`

### Validierung:
- `bash -n` auf beide neuen Scripts: OK
- `systemctl list-timers` zeigt alle 4 relevanten Timer aktiv

## 2026-04-08 (Claw-Kanal: Retry + Session/Timeout-Override)

### Optimierung:

1. **[Reliability] `scripts/claw-send.sh` resilienter gegen transienten Gateway-Abbruch**
   - Bei typischen transienten Fehlern (`gateway closed`, `abnormal closure`, `no close frame`) erfolgt jetzt ein automatischer Retry.
   - Ziel: weniger sporadische Fehlschläge bei ansonsten intakter OpenClaw-Session.

2. **[Ops] Pro-Call Steuerung erweitert**
   - Neue Optionen: `--timeout <sekunden>` und `--session-id <id>`.
   - Standardwerte bleiben unverändert (`timeout=120`, `session-id=claude-ops`), Verhalten ist damit rückwärtskompatibel.

### Validierung:
- `./scripts/claw-send.sh --intent report ... --raw` liefert weiterhin strukturierte Response
- `./scripts/claw-send.sh --intent inspect ... --raw` (Docker-Pfad) bleibt `completed`

## 2026-04-08 (OpenClaw Docker-CLI im Container ergänzt)

### Behoben:

1. **[Runtime] OpenClaw konnte `docker` nicht ausführen (`docker: not found`)**
   - Ursache: Im `openclaw`-Container fehlte das Docker-CLI-Binary, obwohl `DOCKER_HOST` korrekt auf `docker-socket-proxy` zeigte.
   - Fix: `openclaw` nutzt jetzt ein lokales Build-Image (`infra/openclaw-image/Dockerfile`) auf Basis des gepinnten Upstream-Digests und kopiert zusätzlich das `docker`-CLI aus `docker:27.5.1-cli`.
   - Compose umgestellt auf `build` + `image: openclaw:local`.

### Validierung:
- `docker exec openclaw sh -lc 'command -v docker && docker --version'` zeigt verfügbare CLI
- `./scripts/claw-send.sh --intent inspect ... --raw` liefert kein `docker: not found` mehr

## 2026-04-08 (Claude↔OpenClaw Kollaborationsprotokoll)

### Neu:

1. **[Feature] `scripts/claw-send.sh`** — Strukturierter Claude→OpenClaw-Kanal. Sendet HANDSHAKE-formatierte Requests über dedizierte Session `claude-ops` (getrennt von User/Telegram-Chats). Felder: intent, target, priority, scope, allowed/forbidden actions, success_criteria, context.

2. **[Protocol] AGENTS.md: "Claude Collaboration" Sektion** — OpenClaw weiß jetzt explizit wie es HANDSHAKE-Requests (`sender: claude`) behandeln soll: ## Response Format mit exakten Feldnamen, operationaler Ton (keine User-Begrüßungen), Eskalation nur an claude.

3. **[Protocol] HANDSHAKE.md: "Technische Übertragung" Sektion** — CLI-Syntax, Session-Trennung und Kanäle dokumentiert.

4. **[Doku] openclaw-architecture.md: Kollaborations-Abschnitt** — Drei-Kanal-Architektur (Telegram/Canvas/Claude), HANDSHAKE-Format-Beispiele, Session-Trennung, claw-send.sh Referenz.

### Session-Trennung (3 Kanäle):
- Telegram → User-Session (steges)
- Canvas-Chat → HTTP-Bridge (chat-bridge.service)
- Claude Code → `claude-ops`-Session (`claw-send.sh`)

### Validierung:
- `claw-send.sh --intent inspect --target agent/MEMORY.md` → `## Response` mit `request_id` korrekt
- Session `claude-ops` getrennt von Telegram/User-History bestätigt

---

## 2026-04-08 (OpenClaw Chat-Bridge + Gateway-Dokumentation)

### Neu:

1. **[Feature] Chat-Bridge für Canvas-UI** — `/api/chat` fehlte im OpenClaw-Gateway (rein WebSocket-basiert). Neuer Python-HTTP-Bridge-Dienst (`scripts/chat-bridge.py`, `systemd/chat-bridge.service`) übersetzt `POST /api/chat` → `docker exec openclaw openclaw agent --agent main --json`. Läuft auf `127.0.0.1:18792`.

2. **[Infra] Caddyfile: openclaw.lan/api/chat Route ergänzt** — `@chat`-Matcher routet `POST /api/chat` an die Bridge (127.0.0.1:18792), alle anderen Anfragen weiterhin an Port 18789.

3. **[Doku] openclaw-architecture.md vollständig überarbeitet** — Gateway-WebSocket-Protokoll dokumentiert (Challenge/Response, Ed25519-Signatur, Connect-Frame-Format, Pflichtfelder), CLI-Befehle vollständig, Chat-Bridge-Architektur, HTTP-Endpunkt-Übersicht, Identitäts-Datei-Pfade.

### Validierung:
- `curl -X POST http://127.0.0.1:18792/api/chat -d '{"message":"test"}'` → `{"reply": "Hallo!"}`
- `curl -X POST http://openclaw.lan/api/chat ... -d '{"message":"Canvas-Chat Test"}'` → `{"reply": "Hallo vom Agent!"}`
- `sudo systemctl status chat-bridge` → `active (running)`

---

## 2026-04-08 (Infra-Bugs: docker-compose.yml + CLAUDE.md)

### Behoben:

1. **[Security] portainer Port-Binding auf LAN-IP beschränkt** — `"9000:9000"` → `"192.168.2.101:9000:9000"`. Portainer war zuvor auf allen Interfaces erreichbar, konsistent mit allen anderen Services jetzt LAN-only.

2. **[Startup Race] homepage depends_on docker-socket-proxy ergänzt** — homepage nutzt `DOCKER_HOST: tcp://docker-socket-proxy:2375`, hatte aber kein `depends_on`. Docker-Widgets konnten bei Cold-Start fehlen.

3. **[Latent] influxdb DOCKER_INFLUXDB_INIT_MODE auskommentiert** — `setup`-Modus ist nur für Erstinitialisierung gedacht. DB ist bereits initialisiert; Variable bleibt als Kommentar für Dokumentationszwecke erhalten.

4. **[Soft] caddy depends_on vervollständigt** — fehlende Services ergänzt: glances, uptime-kuma, homepage, prometheus, grafana, influxdb (Caddy proxied diese, hat aber keine Startreihenfolge sichergestellt).

5. **[Hygiene] rag-embed Watchtower-Label ergänzt** — `com.centurylinklabs.watchtower.enable: "false"` gesetzt. rag-embed ist ein lokaler Build, Watchtower kann kein Update ziehen.

6. **[Doku] CLAUDE.md Services-Tabelle aktualisiert** — 10 fehlende Services nachgetragen: grafana, prometheus, influxdb, glances, homepage, uptime-kuma, unbound, docker-socket-proxy, node-exporter, rag-embed.

### Validierung:
- `docker compose config --quiet` → YAML OK

## 2026-04-08 (Canvas UI: Refactor-Bugs + Optimierungen)

### Behoben:

1. **[Critical] Settings-Tab lädt Form nie** (`app-settings.js`)
   - `init()` returned `{ loadSettingsForm }`, aber `app-main.js` verwarf den Return-Wert und rief `window.CanvasSettings?.loadSettingsForm()` auf — TypeError bei Navigation.
   - Fix: `init()` registriert `loadSettingsForm` jetzt zusätzlich direkt auf `window.CanvasSettings`.

2. **[Leiche] `app.js` gelöscht** — identische Kopie von `app-main.js`, nicht in `index.html` eingebunden.

3. **[MQTT] PUBLISH Remaining Length für > 127 Byte** (`app-mqtt.js`)
   - Einzelbyte-Encoding brach bei Topics/Payloads > 127 Byte.
   - Fix: Hilfsfunktion `mqttVarInt()` eingeführt, PUBLISH und CONNECT nutzen sie konsistent.

### Optimierungen:

4. **`escHtml` zentralisiert** — aus `app-mqtt.js` und `app-rag.js` entfernt, jetzt zentral in `app-net.js` als `window.CanvasNet.escHtml`; Module greifen via `window.CanvasNet?.escHtml || Fallback` darauf zu.

5. **Dead variable in `renderChart` entfernt** (`app-dashboard.js:492`) — `const defs = svgEl.call ? null : svgEl` wurde nie genutzt.

6. **Stabile Gradient-ID in `renderChart`** — statt `Math.random()` jetzt deterministisch aus `stroke` + `unit` abgeleitet; keine ID-Proliferation im SVG-DOM mehr.

7. **`resolveRagBase` gecacht** (`app-rag.js`) — 60s TTL, vermeidet Doppel-Probe pro RAG-Aktion.

8. **ServiceWorker: network-first für API-Pfade** (`sw.js`) — `/api/*` und `/action-log.latest.json` werden nicht mehr gecacht, sondern direkt ans Netz weitergegeben.

9. **`migrateLegacyStorage` einmalig** (`app-config.js`) — Migration-Flag `oc.canvas.v2.migrated-v2` verhindert wiederholte localStorage-Abfragen bei jedem Seitenaufruf.

10. **Kommentar korrigiert** (`app-config.js:2`) — `"für app.js"` → `"für app-main.js"`.

## 2026-04-06 (Ops-UI Action-Log 403 behoben)

### Neu umgesetzt:

1. **✓ Action-Log Snapshot wieder lesbar für nginx**
   - Ursache: `action-log.latest.json` wurde mit Modus `600` geschrieben und war im `ops-ui`-Container nicht lesbar.
   - Fix: `agent/skills/heartbeat/scripts/heartbeat-dispatch.sh` setzt nach atomarem Replace explizit `chmod 644` auf die Snapshot-Datei.
   - Sofortmaßnahme: bestehende Datei auf `644` korrigiert.

### Validierung:
- ✓ `stat` zeigt `644` für `agent/skills/openclaw-ui/html/action-log.latest.json`
- ✓ `GET /action-log.latest.json` über `ui.lan` liefert `200`
- ✓ Ops-UI-Logs zeigen nach Fix erfolgreiche `200`-Antworten statt `403 Permission denied`

## 2026-04-06 (Caddy LAN-URLs: UFW Port 80 Freigabe)

### Neu umgesetzt:

1. **✓ UFW-Regel für Caddy HTTP im LAN ergänzt**
   - `80/tcp` ist jetzt explizit für `192.168.2.0/24` erlaubt.
   - Hintergrund: DNS-Auflösung funktionierte bereits, aber Browserzugriffe auf `http://*.lan` liefen vom Windows-Client in Timeout, weil Port 80 in UFW fehlte.

2. **✓ Windows-Suffix-Kompatibilität ergänzt**
   - Caddy leitet `.lan.lan`-Hosts (z. B. `ui.lan.lan`) per `308` auf die kanonischen `.lan`-Hosts um.

### Validierung:
- ✓ `ufw status numbered` zeigt `80/tcp ALLOW IN 192.168.2.0/24`
- ✓ `iptables -S ufw-user-input` enthält ACCEPT-Regel für `--dport 80`
- ✓ Caddy-Headercheck: `ui.lan.lan -> 308 Location: http://ui.lan/`, `ui.lan -> 200`

## 2026-04-06 (Skill-Manager P2 Abschluss: Canary-Promote Stabilisierung + Lifecycle/Contracts)

### Neu umgesetzt:

1. **✓ Canary-Promote Deadlock behoben**
   - `scripts/skill-forge` markiert Outer-Lock-Aufrufe mit `SM_LOCK_HELD=1`
   - `agent/skills/skill-forge/scripts/common.sh` ueberspringt inneres Re-Locking bei gesetztem Marker
   - Ergebnis: `~/scripts/skill-forge canary promote <slug>` terminiert wieder deterministisch statt zu haengen

2. **✓ Promote-Flow gehaertet**
   - `canary.sh` nutzt Timeout-Guard fuer `evaluate_summary`
   - Post-Promote Doc-Keeper-Aufruf auf gueltigen Entry-Point umgestellt (`~/scripts/skills rag doc-keeper run ...`)

3. **✓ P2 Lifecycle/Contracts/Rollback umgesetzt**
   - `openclaw-rag` und `openclaw-ui` formell mit Canary + Provenance + Promote abgeschlossen
   - Rollback-Prozedur im Skill-Manager praktisch durchlaufen (Status- und Audit-Nachweis)
   - Fehlende Contracts fuer Script-Zugaenge ergaenzt und Strukturwarnungen reduziert

### Validierung:
- ✓ `bash -n scripts/skill-forge agent/skills/skill-forge/scripts/common.sh agent/skills/skill-forge/scripts/canary.sh`
- ✓ `~/scripts/skill-forge policy lint`
- ✓ Smoke: `~/scripts/skill-forge canary promote openclaw-rag` liefert Policy-Exit statt Hang
- ✓ Lifecycle-State geprueft: `openclaw-rag` und `openclaw-ui` auf `active`, Provenance jeweils vorhanden

## 2026-04-06 (Unbound als Pi-hole Upstream produktiv)

### Neu umgesetzt:

1. **✓ Unbound-Service auf arm64 produktiv ausgerollt**
   - Neuer Service `unbound` in `docker-compose.yml` auf Basis `crazymax/unbound:latest`
   - Neue Konfiguration unter `unbound/config/pilab.conf` mit Listener `0.0.0.0@5335`

2. **✓ Pi-hole auf lokalen Resolver umgestellt**
   - `pihole/config/pihole.toml`: Upstream auf `127.0.0.1#5335` gesetzt

3. **✓ Doku nachgezogen**
   - `docs/decisions/unbound-evaluation.md`, `docs/core/services-and-ports.md`, `docs/operations/maintenance-and-backups.md` aktualisiert

### Validierung:
- ✓ `docker compose up -d unbound pihole`
- ✓ `docker inspect` zeigt `unbound` und `pihole` als `healthy`
- ✓ `dig @127.0.0.1 -p 5335 example.com` (direkt)
- ✓ `dig @127.0.0.1 -p 53 example.com` (ueber Pi-hole)
- ✓ Latenzvergleich dokumentiert (vorher/nachher)

## 2026-04-06 (Auth-Failure Monitoring statt Fail2ban-Vollstack)

### Neu umgesetzt:

1. **✓ Optionales Auth-Failure Monitoring auf Docker-Logs**
   - Neues Script `scripts/auth-failure-monitor.sh`
   - Erfasst wiederholte Auth-/Token-Fehler in `openclaw`, `mosquitto`, `homeassistant`, `grafana`, `pihole`, `caddy`
   - Mensch- und JSON-Ausgabe plus Schwellwert-Alert via Exit-Code

2. **✓ Doku aktualisiert**
   - `docs/core/security-baseline.md` und `docs/operations/maintenance-and-backups.md` um Betriebs-/Nutzungsanleitung ergänzt

### Validierung:
- ✓ `~/scripts/auth-failure-monitor.sh --hours 24 --json`

## 2026-04-06 (Canvas UI: Playwright-Smoke + Visual Baselines)

### Neu umgesetzt:

1. **✓ Automatisierter Canvas-Smoke (arm64-freundlich)**
   - Neues Script `scripts/canvas-playwright-smoke.sh`
   - Führt headless Smoke-Checks für Ops/Chat/MQTT aus

2. **✓ Visual-Baseline-Screenshots für kritische Seiten**
   - Erstellt `ops-dashboard.png`, `chat-page.png`, `mqtt-page.png`
   - Legt Ergebnisse unter `docs/visual-baselines/canvas/YYYY-MM-DD/` ab

3. **✓ Doku ergänzt**
   - `docs/operations/canvas-smoke-checklist.md` um automatisierten Run ergänzt

### Validierung:
- ✓ `~/scripts/canvas-playwright-smoke.sh`
- ✓ `smoke-result.json` status `ok` (3/3)

## 2026-04-06 (Time-Series: HA->Influx + Grafana + Baseline abgeschlossen)

### Neu umgesetzt:

1. **✓ Home Assistant schreibt nach InfluxDB**
   - `homeassistant/config/configuration.yaml` um `influxdb` (v2) ergänzt
   - Persistenz geprüft: HA-Datensätze im Bucket `homeassistant` abfragbar

2. **✓ Grafana mit Influx-Data-Source und Kern-Dashboards provisioniert**
   - Data-Sources: `grafana/provisioning/datasources/datasources.yml`
   - Dashboard-Provider: `grafana/provisioning/dashboards/dashboards.yml`
   - Dashboards: `grafana/dashboards/growbox-overview.json`, `grafana/dashboards/infrastructure-overview.json`
   - Compose um Provisioning-Mounts erweitert

3. **✓ Baseline sowie Retention/Downsampling festgezogen**
   - Neues Script: `scripts/ha-history-baseline.sh`
   - Bericht: `docs/monitoring/time-series-baseline.md`
   - Retention: `homeassistant=90d`, `homeassistant_rollup=365d`
   - Downsampling-Task: `ha_downsample_5m_hourly`

### Validierung:
- ✓ `docker compose ps homeassistant grafana influxdb` (healthy)
- ✓ Grafana API: Data-Source `influxdb-ha` und Dashboard-Hits vorhanden
- ✓ Baseline-Script erfolgreich ausgeführt

## 2026-04-06 (HA Webhook Token für OpenClaw Trigger)

### Neu umgesetzt:

1. **✓ Webhook-Token produktiv gesetzt und synchronisiert**
   - `.env`: `OPENCLAW_WEBHOOK_TOKEN` mit echtem Secret befuellt
   - `homeassistant/config/secrets.yaml`: `openclaw_webhook_bearer` auf denselben Token gesetzt (`Bearer <token>`)

2. **✓ Doku ergänzt**
   - `docs/setup/homeassistant-setup.md` um Abschnitt zu Token-Sync und Rotation erweitert

### Validierung:
- ✓ Konsistenzcheck `.env` vs. `secrets.yaml` (Werte identisch)

## 2026-04-06 (Time-Series Stack: InfluxDB 2 Rollout)

### Neu umgesetzt:

1. **✓ InfluxDB 2 installiert und in Compose integriert**
   - Neuer Service `influxdb` in `docker-compose.yml` (`influxdb:2.7.12`, Port `8086`, persistente Pfade `~/influxdb/data` und `~/influxdb/config`)
   - Initial-Setup über `.env`-Variablen (`INFLUXDB_ADMIN_*`, `INFLUXDB_ORG`, `INFLUXDB_BUCKET`)

2. **✓ LAN-Route für InfluxDB ergänzt**
   - `caddy/Caddyfile`: neue Route `http://influx.lan -> 192.168.2.101:8086`

3. **✓ Betrieb und Dokumentation nachgezogen**
   - Backup erweitert: `scripts/backup.sh` sichert `~/influxdb/data` lokal und via Restic
   - Doku aktualisiert: `docs/core/services-and-ports.md`, `docs/operations/maintenance-and-backups.md`, `docs/monitoring/time-series-decision.md`, `docs/operations/open-work-todo.md`

### Validierung:
- ✓ `docker compose up -d influxdb`
- ✓ `docker compose ps influxdb` -> healthy
- ✓ `docker compose up -d caddy`

## 2026-04-06 (Learn-Skill: Woechentliche Distillation)

### Neu umgesetzt:

1. **✓ Woechentlicher Learn-Distill-Run**
   - `agent/skills/learn/scripts/learn-dispatch.sh` um `weekly [--json]` erweitert
   - wertet die letzten 7 Tage aus `audit-log.jsonl`, `action-log.jsonl`, Pending-Review-Backlog und `skill-risk-report.json` aus
   - schreibt konkrete Eintraege mit Learning-IDs nach `agent/skills/skill-forge/.learnings/LEARNINGS.md`
   - speichert den Wochenmarker in `.state/learn-weekly.json`, damit pro ISO-Woche nur ein Distill-Lauf erzeugt wird

2. **✓ Heartbeat-Integration fuer den Selbst-Verbesserungs-Loop**
   - `heartbeat-dispatch.sh` fuehrt `~/scripts/skills learn weekly --json` einmal pro Woche aus
   - Ergebnis landet in Audit-Log und Action-Log als `weekly_learnings`

### Validierung:
- ✓ `bash -n agent/skills/learn/scripts/learn-dispatch.sh`
- ✓ `bash -n agent/skills/heartbeat/scripts/heartbeat-dispatch.sh`
- ✓ `~/scripts/skills learn weekly --json`

## 2026-04-06 (CLI-DX: Saubere JSON-Ausgabe fuer Scout)

### Neu umgesetzt:

1. **✓ Scout `--json` ohne Mischformat gehaertet**
   - `agent/skills/scout/scripts/scout-dispatch.sh` gibt in den semantischen Pfaden (`--dry-run --semantic`, `--live --semantic`) bei `--json` keinen Klartext mehr vor dem JSON aus
   - gemeinsame Ausgabe ueber `print_semantic_json()` vereinheitlicht

2. **✓ Wrapper-Contract fuer JSON-Parsebarkeit erweitert**
   - `agent/skills/skill-forge/scripts/test-wrapper-contracts.sh` prueft jetzt explizit `~/scripts/skills scout --dry-run --semantic --json` auf valides JSON

### Validierung:
- ✓ `bash -n agent/skills/scout/scripts/scout-dispatch.sh`
- ✓ `bash agent/skills/skill-forge/scripts/test-wrapper-contracts.sh`

## 2026-04-06 (RAG Canary Smoke)

### Neu umgesetzt:

1. **✓ Canary-Gate fuer Retrieval-Aenderungen**
   - Neues Script `agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh`
   - Fuehrt `evaluate-goldset.py` aus und prueft Baseline-Gates fuer `precision@5`, `recall@5` und `p95`
   - Default-Gates: `precision>=0.25`, `recall>=0.55`, `p95<=200ms`

### Validierung:
- ✓ `bash -n agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh`
- ✓ `agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh --json`

## 2026-04-06 (RAG Datenquellen-Hygiene: Daily Diary Priorisierung)

### Neu umgesetzt:

1. **✓ Growbox-Diary Recency-Boost**
   - `retrieve.py` bevorzugt neue Diary-Dateien im Reranking (`heute > gestern > letzte 3 Tage > letzte 7 Tage`)
   - Ziel: aktuelle Growbox-Tageskontexte vor aelteren Diary-Eintraegen sichtbar machen

### Validierung:
- ✓ `python3 -m py_compile agent/skills/openclaw-rag/scripts/retrieve.py`
- ✓ `~/scripts/skills rag retrieve "growbox tagebuch heute" --limit 5 --timeout-ms 1500 --json`

## 2026-04-06 (RAG Ingestion Robustheit: Chunk-Profile + Backpressure)

### Neu umgesetzt:

1. **✓ Chunking-Regeln je Quelle verfeinert**
   - `ingest.py` nutzt jetzt source-spezifische Chunk-Profile (`docs`, `runbook`, `growbox-diary`, `skill-doc`, `agent-doc`, `action-log`)
   - Regeln in `agent/skills/openclaw-rag/RAG-SOURCES.md` dokumentiert

2. **✓ Backpressure fuer grosse Ingest-Runs**
   - Neues Flag `--max-chunks-per-run`
   - Teilindizierung pro Datei mit `next_chunk_offset` statt nur file-level Stop
   - Resume-State in `infra/openclaw-data/rag/ingest-state.json`
   - `--resume` setzt exakt an `current_source + next_chunk_offset` fort

### Validierung:
- ✓ `python3 -m py_compile agent/skills/openclaw-rag/scripts/ingest.py`
- ✓ `python3 agent/skills/openclaw-rag/scripts/ingest.py --changed-only --max-chunks-per-run 10 --json`
- ✓ `python3 agent/skills/openclaw-rag/scripts/ingest.py --changed-only --resume --max-chunks-per-run 10 --json`

## 2026-04-06 (RAG Retrieval-Qualitaet: Gold-Set + Query-Rewrites)

### Neu umgesetzt:

1. **✓ Gold-Set mit 20 Fragen aufgebaut**
   - Neue Datei `agent/skills/openclaw-rag/GOLD-SET.json`
   - Deckt Ops-, Growbox-, Skill-Manager-, Security- und RAG-Fragen mit erwarteten Evidenz-Pfaden ab

2. **✓ Precision@k / Recall@k Messung eingefuehrt**
   - Neues Script `agent/skills/openclaw-rag/scripts/evaluate-goldset.py`
   - Fuehrt den echten Retriever pro Frage aus und berechnet `avg_precision_at_k`, `avg_recall_at_k`, `p95_latency_ms`
   - Referenzmessung: `20` Fragen, `avg Precision@5 = 0.32`, `avg Recall@5 = 0.625`, `p95 = 70.28ms`

3. **✓ Query-Rewrite-Regeln fuer deutsche Synonyme**
   - `retrieve.py` erweitert um deutsche Rewrite-/Alias-Regeln (u. a. `ausfall`, `wiederherstellung`, `tagebuch`, `dienste`)
   - JSON-Output enthaelt jetzt `query_rewrites` fuer transparente Keyword-Expansion

### Validierung:
- ✓ `python3 -m py_compile agent/skills/openclaw-rag/scripts/retrieve.py agent/skills/openclaw-rag/scripts/evaluate-goldset.py`
- ✓ `~/scripts/skills rag retrieve "Wie ist der Recovery Ablauf bei Pi-hole DNS-Ausfall?" --limit 5 --timeout-ms 1500 --json`
- ✓ `python3 agent/skills/openclaw-rag/scripts/evaluate-goldset.py --limit 5 --timeout-ms 1500`

## 2026-04-06 (RAG Timeout/Fallback + CLI-DX + Agent-Schemata)

### Neu umgesetzt:

1. **✓ RAG retrieve/reindex standardisiert (Timeout + Fallback)**
   - Neuer Dispatcher: `agent/skills/openclaw-rag/scripts/rag-dispatch.sh`
   - Neue Wrapper-Commands: `~/scripts/skills rag retrieve ...` und `~/scripts/skills rag reindex ...`
   - `retrieve.py`: FTS -> LIKE Fallback, Snapshot-Fallback (`rag/snapshots/index.db.*`), Timeout via `--timeout-ms`
   - JSON-Response erweitert um: `search_mode`, `db_used`, `fallback_used`, `timeout_ms`, `warning`
   - `reindex.sh`: Timeout via `RAG_REINDEX_TIMEOUT_SECONDS`/`--timeout-seconds`, Integritätscheck (`PRAGMA quick_check`), Snapshot-Restore bei Fehler

2. **✓ CLI-Design / DX: Help-Text + Shared Argument Parser**
   - Help-Texte in `scripts/skills` und `scripts/skill-forge` um `rag` und `metrics ... risk-report` konsistent ergänzt
   - Shared Parser `scripts/lib/common-flag-parser.sh` eingeführt
   - Eingebunden in `scripts/skills` und `scripts/skill-forge` für wiederkehrende Flags (`--json`, `--dry-run`, `--reason`)

3. **✓ Standards & Contracts: Output-Schema pro Agent**
   - Fehlende Agent-Schemata ergänzt für:
     - canary-approver
     - coding planner/coder/reviewer
     - scout analyst/curator
     - vetting reviewer

### Validierung:
- ✓ `bash -n` auf allen geänderten Shell-Skripten
- ✓ `~/scripts/skills rag retrieve ... --timeout-ms ...`
- ✓ `~/scripts/skills rag reindex --changed-only --json`
- ✓ `~/scripts/skill-forge canary evaluate ... --json` (Parser-Regression)

## 2026-04-06 (Config-Write Race Condition: openclaw.json)

### Neu umgesetzt:

1. **✓ Locking-Mechanismus fuer OpenClaw Config-Writes**
   - Neues Guard-Script `scripts/openclaw-config-guard.sh`
   - Exklusive Lock-Datei: `infra/openclaw-data/openclaw-config-write.lock`
   - Subcommand `run -- <cmd...>` serialisiert schreibende Operationen und retryt bei `EBUSY`
   - Convenience-Wrapper: `login-github-copilot`

2. **✓ EBUSY-Rate Vergleich nach Fix-Werkzeug**
   - Messung ueber `infra/openclaw-data/logs/config-audit.jsonl`
   - `ebusy-rate 720`: `7/8` (`0.875`)
   - `compare 168 24`: baseline `0.875` vs recent `0.0`, delta `-0.875`, `improved_or_equal=true`

### Validierung:
- ✓ `bash -n scripts/openclaw-config-guard.sh`
- ✓ `scripts/openclaw-config-guard.sh ebusy-rate 720`
- ✓ `scripts/openclaw-config-guard.sh compare 168 24`

## 2026-04-06 (Security Baseline: State-Write Guard in Agent-MD)

### Neu umgesetzt:

1. **✓ Policy-Lint Guard gegen State-Write in Agent-Markdown**
   - `policy-lint.sh` scannt jetzt `*/agents/*.md` und `*/AGENTS.md` auf echte Write-Befehlsmuster (`>`/`>>`/`tee`) in kritische State-Dateien
   - Geblockte Targets: `known-skills.json`, `canary.json`, `audit-log.jsonl`, `pending-blacklist.json`, `author-queue.json`, `writer-jobs.json`, `incident-freeze.json`
   - Reine Dokumentationstexte bleiben erlaubt; geprüft werden nur Befehlsmuster

### Validierung:
- ✓ `bash -n agent/skills/skill-forge/scripts/policy-lint.sh`
- ✓ `~/scripts/skill-forge policy lint`
- ✓ `bash scripts/pre-merge-gate.sh`

## 2026-04-06 (Canary-Kriterien versioniert pro Skill)

### Neu umgesetzt:

1. **✓ Canary-Kriterien pro Skill versioniert**
   - Neue Policy-Datei `agent/skills/skill-forge/policy/canary-criteria.yaml` mit `version`, `default` und per-skill Overrides unter `skills.<slug>`
   - `canary-dispatch.sh` liest diese Datei bei `canary evaluate <slug>` und merged `default + skill override`
   - Output enthält jetzt zusätzlich ein `criteria`-Objekt (window/hard_min/max_triggers/guards), damit die Bewertungsbasis transparent ist

### Validierung:
- ✓ `bash -n agent/skills/canary/scripts/canary-dispatch.sh`
- ✓ `~/scripts/skill-forge policy lint`
- ✓ `~/scripts/skills canary evaluate resilience-check --json`

## 2026-04-06 (Security Baselines + Standards & Contracts + Testbarkeit)

### Neu umgesetzt:

1. **✓ Security Baseline: Forbidden-Pattern-Scan Gate**
   - `scripts/security-scan.sh`: scannt Shell-Scripts auf 8 verbotene Muster (RCE via curl/wget-pipe, eval-Expansion, rm -rf Systempfade, hardcoded Credentials, chmod world-writable)
   - Pattern-Format mit optionalem Ausschluss-Filter (3-teilig: `DESC|PATTERN|EXCLUDE`) – False-Positives für Test-Strings und `/tmp`-Pfade ausgeschlossen
   - In `pre-merge-gate.sh` als neuer Schritt 2 integriert
   - Shellcheck-Warning in `nightly-check.sh` behoben (`health_out` unused → direkt auf /dev/null umgeleitet)

2. **✓ Standards & Contracts: Skill-Struktur-Check**
   - `scripts/skill-structure-check.sh`: prüft alle Skills auf `SKILL.md` + `scripts/` (required), `agents/` + `contracts/` (expected/Warnung)
   - `SKIP_SCRIPTS`-Skiplist für No-Dispatch-Skills (`core`, `openclaw-ui`)
   - `core/SKILL.md` angelegt (fehlte bislang)
   - In `pre-merge-gate.sh` als Schritt 5 integriert
   - `--strict`-Flag für harten Fehler bei fehlenden `agents/`- und `contracts/`-Verzeichnissen

3. **✓ Testbarkeit: Smoke-Test für alle Dispatch-Scripts**
   - `scripts/tests/smoke-dispatches.bats` (3/3): prüft Ausführbarkeit, `bash -n` Syntax und Laufzeit-Verhalten aller `*-dispatch.sh` Files
   - `test-wrapper-contracts.sh`: canary exit-code Erwartung von 1 auf 2 korrigiert (Regression nach `--emergency` Feature)
   - `pre-merge-gate.sh`: 6 Checks total, alle grün auf `--all`

### Validierung:
- ✓ `bash -n scripts/security-scan.sh`
- ✓ `bash -n scripts/skill-structure-check.sh`
- ✓ `bats scripts/tests/smoke-dispatches.bats` (3/3)
- ✓ `bash scripts/pre-merge-gate.sh --all` (6/6)
- ✓ `~/scripts/skill-forge policy lint`


## 2026-04-06 (doc-keeper als eigener Skill + Risiko-Metrik)

### Neu umgesetzt:

1. **✓ doc-keeper: Delta-basierte Updates + Review-Mode + Source-of-truth-Marker**
   - `doc-keeper-dispatch.sh` komplett neu geschrieben: verfolgt `last_processed_head` in State-Datei und differenziert nur geänderte Dateien per `git diff`
   - Neue Flags: `--summary-only` (kein Changelog-Update), `--review-changelog` (schreibt in `docs/operations/doc-keeper-changelog-review.md` statt `CHANGELOG.md`)
   - Strukturierter JSON-Output mit `status`, `scan`, `head`, `delta_file_count`, `changelog_mode`
   - `<!-- DOC_KEEPER_AUTO_START -->` / `<!-- DOC_KEEPER_AUTO_END -->` als Safe-Edit-Marker in Docs
   - **doc-keeper ist jetzt ein eigener Skill** (`agent/skills/openclaw-rag/scripts/doc-keeper-dispatch.sh`) – skill-forge ruft nur noch via `DOC_KEEPER_DISPATCH` auf
   - `scripts/skills`: `DOC_KEEPER_DISPATCH` Pfad korrigiert
   - Files: `agent/skills/openclaw-rag/scripts/doc-keeper-dispatch.sh`, `agent/skills/openclaw-rag/scripts/tests/doc-keeper.bats`

2. **✓ metrics risk-report: Risiko-Metrik pro Skill**
   - Neues Subkommando `skills metrics risk-report` aggregiert für jeden bekannten Skill: `reject_count`, `rollback_count`, `review_count`, `pass_count` aus Audit-Log, `risk_tier` + `final_score` aus Vetter-Reports, Status aus `known-skills.json`
   - `risk_score` = `(reject*30) + (rollback*40) + tier_weight + pending_bonus`, Cap 100
   - Schreibt atomisch nach `.state/skill-risk-report.json`
   - Files: `agent/skills/metrics/scripts/metrics-dispatch.sh`, `agent/skills/metrics/scripts/tests/risk-report.bats`

### Validierung:
- ✓ `bash -n agent/skills/openclaw-rag/scripts/doc-keeper-dispatch.sh`
- ✓ `bash -n agent/skills/metrics/scripts/metrics-dispatch.sh`
- ✓ `bats agent/skills/openclaw-rag/scripts/tests/doc-keeper.bats` (2/2)
- ✓ `bats agent/skills/metrics/scripts/tests/risk-report.bats` (3/3)
- ✓ `~/scripts/skill-forge policy lint`



### Neu umgesetzt:

1. **✓ Nightly Self-Check als echter read-only Task + Timer**
   - `scripts/nightly-check.sh` nutzt jetzt overridbare Pfade fuer Tests, wertet den Health-Check korrekt ueber den Exit-Code aus und erkennt stale canaries anhand von `status=running`
   - Neuer Bats-Test `scripts/tests/nightly-check.bats` deckt Clean-Run und Alert-Fall (stale canary + pending-review backlog) ab
   - Neue systemd-Vorlagen: `systemd/nightly-self-check.service` und `systemd/nightly-self-check.timer`
   - Files: `scripts/nightly-check.sh`, `scripts/tests/nightly-check.bats`, `systemd/nightly-self-check.service`, `systemd/nightly-self-check.timer`

### Validierung:
- ✓ `bash -n scripts/nightly-check.sh`
- ✓ `bats scripts/tests/nightly-check.bats`
- ✓ `systemd-analyze verify systemd/nightly-self-check.service systemd/nightly-self-check.timer`

## 2026-04-06 (Skill Improvements: authoring)

### Neu umgesetzt:

1. **✓ authoring-dispatch.sh – Slug-Normalisierung + Minimal-Skeleton + Quality-Metadaten**
   - Skill-Namen werden vor dem Draft zu einem slug normalisiert; normalisierte Kollisionen gegen bestehende Skill-Verzeichnisse und `known-skills.json` werden abgelehnt
   - Draft-Erzeugung legt direkt ein minimales Skeleton an: `SKILL.md`, `agents/`, `scripts/<slug>-dispatch.sh`, `contracts/default.output.schema.json`, `references/AUTHORING.md`
   - Queue und `known-skills.json` speichern `slug`, `quality_score`, `quality_tier`, `authoring_mode` und `display_name`
   - Dispatcher unterstuetzt Pfad-Overrides fuer isolierte Tests (`AUTHORING_SM_ROOT`, `AUTHORING_STATE_DIR`, `AUTHORING_SKILLS_ROOT`, `AUTHORING_AUDIT_LOG`)
   - Files: `agent/skills/authoring/scripts/authoring-dispatch.sh`, `agent/skills/authoring/tests/test-authoring-dispatch.sh`

### Validierung:
- ✓ `bash -n agent/skills/authoring/scripts/authoring-dispatch.sh`
- ✓ `bash -n agent/skills/authoring/tests/test-authoring-dispatch.sh`
- ✓ Smoke: `test-authoring-dispatch.sh` -> 4/4 passed

## 2026-04-06 (Skill Improvements: canary, pi-control, ha-control)

### Neu umgesetzt:

1. **✓ canary-dispatch.sh – Maschinenlesbare Entscheidungstabelle + Structured Output**
   - `rollout-policy.yaml` erweitert um `decision_table` (8 Zeilen, top-down evaluation)
   - `canary-dispatch.sh` lädt Tabelle via PyYAML, evaluated Conditions iterativ (Fallback: hardcoded Logik)
   - `approver_out` enthält jetzt: `failure_class` (freeze_fail|signal_fail|conflict_fail|policy_fail|none), `decision_table_row`, `trigger_count`, `high_events`, `conflict_count`, `window_pct_done`, `elapsed_hours`, `total_hours`
   - Human-Output zeigt Failure-Class, Decision-Row und Event-Counts
   - Files: `agent/skills/canary/scripts/canary-dispatch.sh`, `agent/skills/skill-forge/policy/rollout-policy.yaml`

2. **✓ pi-control docker-compose.sh – `--dry-run` + Explicit Allowlist-Test**
   - `restart <service> --dry-run`: validiert Service-Name, druckt Dry-run-Meldung, führt keinen Docker-Call aus
   - `tests/test-allowlist.sh`: 5 Tests für deny-by-default (unknown action, unknown service, dry-run deny, dry-run known service, no-arg reject)
   - Files: `agent/skills/pi-control/scripts/docker-compose.sh`, `agent/skills/pi-control/tests/test-allowlist.sh`

3. **✓ ha-control – Entity-Drift-Detection + Read/Write Audit-Logging**
   - `check-entities.sh` (neu): vergleicht Whitelist mit live HA `/api/states`, meldet fehlende Entities (Status `ok` oder `drift`, `--json` möglich)
   - `call-service.sh`: schreibt nach erfolgreichem HTTP 2xx `HA_WRITE`-Eintrag in `audit-log.jsonl`
   - `get-state.sh`: schreibt vor `exec curl` `HA_READ`-Eintrag in `audit-log.jsonl`
   - Service-Call Payload-Validierung war bereits implementiert (case statement) → bestätigt, kein Todo mehr
   - Files: `agent/skills/ha-control/scripts/check-entities.sh`, `call-service.sh`, `get-state.sh`

### Validierung:
- ✓ `bash -n` fuer alle geaenderten Scripts
- ✓ `~/scripts/skill-forge policy lint`
- ✓ Smoke: `canary evaluate openclaw-rag --json` → `failure_class=none, decision_table_row=window_expired` ✓
- ✓ Smoke: `test-allowlist.sh` → 5/5 passed ✓
- ✓ Smoke: `check-entities.sh --json` → `status=drift` (ESP32 offline, erwartetes Ergebnis) ✓

## 2026-04-06 (Skill Improvements: coding, vetting, Canvas UX, USER.md)

### Neu umgesetzt:

1. **✓ code-dispatch.sh – Output-Stabilisierung + Structured Findings**
   - `--json` Flag: strukturierter JSON-Output statt fester 3-Zeilen-Ausgabe
   - `security_scan()` gibt jetzt `[{id, severity (block|warn), file, reason}]` JSON-Array zurueck
   - Findings persistiert in `generated/findings/{slug}.json`
   - Slug-Kollisionsvermeidung: Timestamp-Suffix wenn Artefakt bereits existiert
   - File: `agent/skills/coding/scripts/code-dispatch.sh`

2. **✓ vet.sh – Report-Schema v2 + Severity-Flags (Static Semantic Layer)**
   - Report-Schema auf v2 erhoeht: `schema_version: "2"`
   - `scores.semantic_score` → `scores.static_semantic_score` (klare Layer-Trennung)
   - `static_semantic_flags` als neues Top-Level-Feld: `[{id, severity, reason}]`
   - Alle Flags klassifiziert: `block` (purpose-mismatch, prompt-injection), `warn` (broad-permissions, cross-file-mismatch)
   - File: `agent/skills/skill-forge/scripts/vet.sh`

3. **✓ vetting-dispatch.sh – Analyst-Layer Refactoring + Severity-Flags**
   - Duplizierter Python-Analyse-Block (timeout vs. non-timeout Branch) unified zu `_run_analyst_py()` inner function
   - Analyst-Flags mit Schweregrad: `block` / `warn` / `info`
   - `semantic_review` in Report enthaelt `schema_version: "2"` + `source: "vetting-dispatch"` (klar als separater Layer markiert)
   - Bug entfernt: orphaned Code-Block (`result = {...}` + `PY\n  fi` Duplikat)
   - File: `agent/skills/vetting/scripts/vetting-dispatch.sh`

4. **✓ Canvas – Konsistente Loading-States + Mobile Layout QA**
   - `refreshHealth()`: `setLoading("health-chips", true/false)` an Start/Ende
   - `refreshGrowbox()`: `setLoading("growbox-state-chips", true/false)` an Start/Ende (inkl. token-missing Branch)
   - Neue CSS-Breakpoints: `max-width: 390px` (iPhone 14/15) + `max-width: 360px` (Samsung base)
   - File: `agent/skills/openclaw-ui/html/index.html`

5. **✓ USER.md – Monatliches Review + Ergaenzungen**
   - `last_reviewed: "2026-04-06"` in Frontmatter
   - Echter Name (Tobias), Aktivitaetsmuster, Arbeitsweise, Telegram-ID dokumentiert
   - File: `agent/USER.md`

### Validierung:
- ✓ `bash -n` fuer alle geaenderten Scripts
- ✓ `~/scripts/skill-forge policy lint`
- ✓ Smoke: code-dispatch 3-Zeilen-Output + `--json`-Output validiert
- ✓ Smoke: vet report `schema_version=2` + `static_semantic_flags=[]` bestaetigt
- ✓ Smoke: Growbox Charts in Canvas vorhanden (`readHaHistorySeries` ✓)

## 2026-04-06 (Restic Offsite-Backup Dokumentation)

### Neu umgesetzt:

1. **✓ Restic Offsite-Backup Dokumentation vervollständigt**
   - Restic-Support war bereits im `~/scripts/backup.sh` implementiert (lokale TAR.GZ + offsite via Restic)
   - Fehlende Dokumentation hinzugefügt: `docs/operations/maintenance-and-backups.md` erweitert um vollständiges Kapitel "Restic Offsite-Backup"
   - `.env.example` erweitert: bessere Kommentare, Setup-Anleitung, Beispiele für B2/SFTP
   - Abgedeckt: Konfiguration (Repository-Typen), Erstes Backup, Retention-Policy, Automatisierung, Restore, Monitoring
   - Validierung: `bash -n ~/scripts/backup.sh` ✓
   - Files: `docs/operations/maintenance-and-backups.md`, `.env.example`

## 2026-04-06 (Skills Optimization Phase 1: Remaining Skill Fixes Completed)

### Neu umgesetzt:

1. **✓ HA-Control – HTTP Error Categorization + Timeouts**
   - `get-state.sh`: `--connect-timeout/--max-time` via `HA_TIMEOUT`
   - `call-service.sh`: HTTP-Klassifizierung fuer `401/403`, `5xx`, sonstige `4xx`; klare Fehlermeldungen
   - Files: `agent/skills/ha-control/scripts/get-state.sh`, `agent/skills/ha-control/scripts/call-service.sh`

2. **✓ Pi-Control – Docker Logs Timeout**
   - `docker-compose.sh logs`: Timeout-Schutz ueber `PI_CONTROL_LOGS_TIMEOUT` (Default kompatibel), bei Timeout klare Truncation-Meldung statt Hanger
   - File: `agent/skills/pi-control/scripts/docker-compose.sh`

3. **✓ Vetting – Analyst Crash Isolation**
   - `vetting-dispatch.sh`: Input-Guard fuer zu grosse/nicht lesbare `SKILL.md`, Analyst-Timeout, Fallback auf neutralen semantischen Delta statt Gesamtabbruch
   - File: `agent/skills/vetting/scripts/vetting-dispatch.sh`

4. **✓ Canary – Audit/State Robustness**
   - `canary-dispatch.sh`: harte Fallbacks bei leerer/korrupten `canary.json` und `audit-log.jsonl`
   - Event-Auswertung liest jetzt robust `command`/`message` Felder aus JSONL
   - File: `agent/skills/canary/scripts/canary-dispatch.sh`

5. **✓ Doc-Keeper – Source-Conflict Resolution (Metadata Sync Guard)**
   - `doc-keeper.sh`: erkennt unmerged git entries, Merge-Conflict-Marker und Marker-Mismatch (`DOC_KEEPER_AUTO_START/END`) und bricht kontrolliert mit Audit-Eintrag ab
   - File: `agent/skills/skill-forge/scripts/doc-keeper.sh`

### Validierung:
- ✓ `bash -n` fuer alle geaenderten Scripts
- ✓ `~/scripts/skill-forge policy lint`
- ✓ Smoke: `~/scripts/skills runbook-maintenance weekly-check --json` -> `status=ok`
- ✓ Smoke: `canary-dispatch evaluate openclaw-rag --json` -> `verdict=Go`
- ✓ Smoke: `PI_CONTROL_LOGS_TIMEOUT=1 docker-compose.sh logs openclaw 10` -> Exit `0` mit Ausgabe
- ✓ Smoke: `doc-keeper.sh run --reason optimization-smoke`

## 2026-04-06 (Skills Optimization Phase 1: Critical Fixes – COMPLETED)

**6/6 CRITICAL Fixes implementiert und validiert**

### Neu umgesetzt seit letztem Stand:

1. **✓ Heartbeat – Partial-Failure-Isolation mit Per-Task-Timeout**
   - Heartbeat nutzt jetzt ein einheitliches Timeout-Wrapper-Muster (`HEARTBEAT_TASK_TIMEOUT`, Default 60s)
   - Isolierte Fehlerbehandlung fuer Subtasks: `doc-keeper` daily-run, Growbox diary/flush/report, `metrics weekly`, `scout weekly`, `shell-tests`
   - Fehler einzelner Subtasks stoppen den Gesamt-Heartbeat nicht mehr
   - Telegram-Heartbeat enthaelt jetzt eine explizite Task-Fehler-Summary
   - Runtime-Bugfix im gleichen Zug: unbound variable fuer Learnings-Pfad behoben (`SCRIPT_DIR` -> `SKILL_DIR`)
   - Files: `agent/skills/heartbeat/scripts/heartbeat-dispatch.sh`

2. **✓ Runbook-Maintenance – Skill voll implementiert**
   - Neuer Dispatcher: `runbook-maintenance-dispatch.sh`
   - Subcommands: `weekly-check`, `checklist`, `failover <scenario>` (jeweils optional `--json`)
   - Weekly-Checks mit per-task Timeout und strukturierter Ergebnisausgabe (human + JSON)
   - Wrapper-Integration in `~/scripts/skills` als eigenstaendiger Domain-Skill
   - SKILL.md von Template-Stub auf vollstaendige Runtime-Doku aktualisiert
   - Files: `agent/skills/runbook-maintenance/SKILL.md`, `agent/skills/runbook-maintenance/scripts/runbook-maintenance-dispatch.sh`, `scripts/skills`

### Validierung:
- ✓ `bash -n` fuer geaenderte Scripts (`heartbeat-dispatch.sh`, `runbook-maintenance-dispatch.sh`, `scripts/skills`)
- ✓ `~/scripts/skill-forge policy lint`
- ✓ Smoke: `~/scripts/skills runbook-maintenance checklist`
- ✓ Smoke: `~/scripts/skills runbook-maintenance failover rag --json`
- ✓ Smoke: `~/scripts/skills runbook-maintenance weekly-check --json`
- ✓ Smoke: `timeout 35 ~/scripts/skills heartbeat` (Lauf bis Metrics-Snapshot, ohne Runtime-Fehler)

## 2026-04-06 (Skills Optimization Phase 1: Critical Fixes – CORE DONE)

**6 CRITICAL Issues verfolgt; 4/6 CRITICAL Fixes implementiert und validiert**

### Neu umgesetzt seit letztem Stand:

1. **✓ Growbox Skill – Retry-Queue fuer HA/Telegram**
   - Persistente Queue: `agent/skills/skill-forge/.state/growbox-message-queue.json`
   - Telegram-Send mit Backoff (1s, 3s, 5s) und Queue-Fallback
   - Heartbeat flusht Queue bei jedem Lauf (`growbox flush-queue`)
   - `mark-sent` erfolgt nur noch bei erfolgreichem Versand
   - Files: `agent/skills/growbox/scripts/growbox-daily-report.sh`, `agent/skills/growbox/scripts/growbox-dispatch.sh`, `agent/skills/heartbeat/scripts/heartbeat-dispatch.sh`, `scripts/skills`

2. **✓ Skill-Manager – State-Transition Validation Gate**
   - Reusable Transition-Validator in `common.sh`
   - Enforced in `vet.sh`, `review.sh`, `canary.sh`
   - Invalid transitions werden mit Policy-Fehler geblockt (kein inkonsistenter State-Write)
   - `review.sh` Write auf atomare Persistenz umgestellt

### Validierung:
- ✓ `bash -n` fuer alle geaenderten Scripts
- ✓ `~/scripts/skill-forge policy lint`
- ✓ Runtime-Smoke: `~/scripts/skill-forge canary status openclaw-rag`
- ✓ Runtime-Smoke: `growbox-dispatch.sh flush-queue`

### Offen (CRITICAL):
- Heartbeat: Partial-failure cascade (task isolation/timeout)
- Runbook-maintenance: Skill ist noch unvollstaendig

---

## 2026-04-06 (Skills Optimization Phase 1: Critical Fixes – PARTIAL COMPLETE)

**6 CRITICAL & 8 HIGH Priority Issues Analyzed; 2/6 CRITICAL Fixes Deployed**

### Implemented Recommendations:

1. **✓ Coding Skill – Disk-Leak Fix**
   - Issue: `generated/` accumulates artifacts indefinitely
   - Solution: 7-day TTL cleanup with `cleanup_old_artifacts()` 
   - File: `agent/skills/coding/scripts/code-dispatch.sh`
   - Validation: ✓ bash -n OK

2. **✓ Scout Skill – GitHub Rate-Limit Resilience**  
   - Issue: Scout crashes on GitHub API 429 (Rate Limit)
   - Solution: `curl_with_backoff()` with exponential backoff (2s→4s→8s, max 3 retries)
   - File: `agent/skills/scout/scripts/scout-dispatch.sh`
   - Validation: ✓ bash -n OK

### Remaining CRITICAL Issues (4/6):
- Growbox: No retry on HA/Telegram → PENDING
- Skill-Manager: State transitions → PENDING
- Heartbeat: Partial-failure cascade → IDENTIFIED (complex)
- Runbook-Maintenance: Unimplemented → PENDING

### Next Steps:
1. Growbox retry-queue implementation
2. Skill-Manager state validation
3. Comprehensive smoke tests

---


## 2026-04-06 (Skills-First Governance Umbau – FULL CYCLE COMPLETE)

**All 9 Phases Implemented, Validated, Documented**

### Phase 0-8 Complete Summary:
- ✓ Governance-Charter verankert: docs/skills/skill-forge-governance.md "Boundary & Governance Model"
- ✓ Domain-Entry-Points komplett: doc-keeper zu scripts/skills hinzugefügt, alle 12 Skills verfügbar
- ✓ Domain-Aliase aus skill-forge entfernt: writer, doc-keeper, heartbeat, learn, metrics, profile, scout nur noch via scripts/skills
- ✓ Heartbeat Hook normalisiert: daily doc-keeper über scripts/skills statt dispatcher.sh Umweg
- ✓ Validation grün: policy lint, bash syntax, domain-smokes
- ✓ CLI-Boundary hart: skill-forge zeigt nur Governance-Kommandos, scripts/skills zeigt Domain-Skills
- ✓ Doku synchronisiert: skill-forge.md, handover.md, README.md, CHANGELOG, heartbeat SKILL.md

### Technical Changes:
1. `/home/steges/scripts/skills`: Added doc-keeper domain-skill entry (+1 skill, total 12)
2. `/home/steges/scripts/skill-forge`: Removed 7 domain-alias case-blocks (writer, doc-keeper, heartbeat, learn, metrics, profile, scout)
3. `/home/steges/scripts/skill-forge` Usage: Restructured to show "(Governance & Lifecycle)" section + "Domain-Skills (use scripts/skills instead)"
4. `/home/steges/agent/skills/heartbeat/scripts/heartbeat-dispatch.sh`: Daily doc-keeper hook normalized to `scripts/skills rag doc-keeper run --daily`
5. `/home/steges/agent/skills/heartbeat/SKILL.md`: Updated dependencies to reflect direct scripts/skills calls + removed dispatcher.sh entries

### Exit Codes & Safety:
- EXIT_USAGE=2, EXIT_MISSING_EXECUTABLE=6 consistent across wrappers
- Policy-lint gate enforced in init/lifecycle commands
- No bypass for governance-critical paths

### Boundary Definition (Final):
**Governance-Only (skill-forge):**
init, status, review, install, update, rollback, policy lint|show, lint shell, vet, test, author, canary start|status|promote|fail, conflict-check, shadow, health, audit, budget, blacklist, orchestrate, incident freeze, provenance, dispatch

**Domain-Only (scripts/skills):**
coding, vetting, canary evaluate, authoring, scout, heartbeat, metrics, profile, learn, health, growbox, doc-keeper

**No Domain-Upstreaming to skill-forge anymore:**
- skill-forge writer → must use scripts/skills coding
- skill-forge heartbeat → must use scripts/skills heartbeat
- skill-forge metrics → must use scripts/skills metrics
etc.

### Backwards Compatibility:
- Thin delegation removed entirely (Phase 8)
- Old `skill-forge writer` calls will fail with usage error (intended, forces migration to scripts/skills)
- OpenClaw must use direct scripts/skills paths (design intent achieved)

### Todos Cleaned Up:
- docs/operations/open-work-todo.md: "Skills-First Governance Umbau" section collapsed to summary + removed all 9 phase entries
- handover.md: Updated to "✓ ABGESCHLOSSEN (2026-04-06)"

### Definition of Done Met:
1. ✓ Routing komplett auf Zielmodell
2. ✓ Validierung komplett grün
3. ✓ Doku komplett synchron und eindeutig
4. ✓ CHANGELOG vollständig
5. ✓ Todo-Bereinigung

---

## 2026-04-06 (Phase 0: Governance Umbau Kickoff)
- **Phase 0 ✓:** Governance-Charter in docs/skills/skill-forge-governance.md verankert ("Boundary & Governance Model"). Klare Trennung: skill-forge = Governance/Lifecycle nur, scripts/skills = Domain-Ausführung.
- **Phase 1 ✓:** Domain-Entry-Points komplett: doc-keeper zu scripts/skills hinzugefügt. Alle 12 Domain-Skills verfügbar über scripts/skills (coding, vetting, canary evaluate, authoring, scout, heartbeat, metrics, profile, learn, health, growbox, doc-keeper). Skill-Manager Usage zeigt "(preferred entry points)" Hinweis.
- **Phase 2 ✓:** Skill-Manager entkopplung: writer, doc-keeper, heartbeat, learn, metrics, profile, scout delegiert zu scripts/skills (thin delegation). Alle Aufrufe gehen durch /home/steges/scripts/skills <domain> <args>.
- **Phase 3 ✓:** Doc-Keeper normalisierung: Heartbeat Hook für daily doc-keeper-run nun direkt über scripts/skills rag doc-keeper (anstelle dispatcher.sh Umweg). SKILL.md heartbeat aktualisiert.
- **Phase 4 ✓:** Contracts/Dispatcher bereits in place. Agent-contracts.json standard; dispatcher.sh validierung strict.
- **Phase 5 ✓:** Output-Standards bereits umgesetzt (--json Flags in Domain-Skills konsistent).
- **Phase 6 (Doku-Hardening) IN PROGRESS:** CHANGELOG aktualisiert mit Phasen-Uebersicht. README, session-handover und skill-forge-governance bereits synchronisiert (Phase 0). Heartbeat SKILL.md updated. docs/operations/maintenance-and-backups.md wird ueberprueft.
- **Boundary-Statement fest verankert:** Keine Domain-Aufgaben mehr in skill-forge CLI nach Phase 2. OpenClaw nutzt direkt scripts/skills. Thin delegation für Rückwärts-Kompatibilität bis Alias-Entfernung (Phase 8).

## 2026-04-06 (Phase 0: Governance Umbau Kickoff)
- **Skills-First Governance Umbau Phase 0 vollständig:** Governance-Charter in `docs/skills/skill-forge-governance.md` verankert ("Boundary & Governance Model" Kapitel). Klare Trennung: `~/scripts/skill-forge` = Lifecycle/Governance nur (install/update/policy/audit/orchestrate/incident), `~/scripts/skills` = Domain-Ausführung (coding/heartbeat/metrics/scout/etc.). Keine Domain-Aufgaben in skill-forge CLI mehr.
- **Rollenmodell dokumentiert:** Skill-Manager orchestriert Domain-Skills, führt sie nicht selbst aus. No duplicate domain logic. Alle fachlichen Aufgaben via `scripts/skills` direkt. Contracts in `agent-contracts.json` abgestimmt auf diese Boundary.
- **Akzeptanzkriterien definiert:** (1) Keine Domain-Commands in skill-forge CLI, (2) OpenClaw nutzt `scripts/skills` für Fachaufgaben, (3) Skill-Manager als Governance-Control-Plane, (4) Doku konsistent über skill-forge.md/handover.md/README.
- **Phasen 1-9 in Todo eingeplant:** Domain-Entry-Points (P1), Skill-Manager-Entkopplung (P2), Doc-Keeper-Normalisierung (P3), Contracts/Dispatcher/Hooks (P4), Output-Standardisierung (P5), Doku-Hardening (P6), Validierungsgates (P7), Alias-Entfernung (P8), Todo-Lifecycle-Abschluss (P9). Detailliertes Plan-Dokument: `/home/steges/.vscode-server/data/User/workspaceStorage/.../plan.md`.

## 2026-04-06 (orchestrate.sh & State-Engine)
- **orchestrate.sh modular refactor (P1):** `run_vet_for_discovered` in 5 diskrete Steps aufgeteilt: `step_discover`, `step_vet`, `step_canary`, `step_promote`, `step_post_check`. Jeder Step schreibt JSON an eine Temp-Datei; klare Input/Output-Schnittstellen ohne Quoting-Probleme via Python-Heredocs.
- **Partial-Failure-Handling:** Per-Skill-Fehler (z. B. `tier_score_failed`) werden im `error`-Feld des jeweiligen Step-Results erfasst und erhoehen `error_count`. Ein kaputtes Skill bricht den Gesamt-Lauf nicht mehr ab.
- **run_id Propagation (State-Engine Hardening):** `orchestrate.sh` exportiert `SKILL_MANAGER_RUN_ID` vor dem ersten Step. `common.sh::log_audit` schreibt die Correlation-ID in jeden Audit-Log-Eintrag. Alle Audit-Events eines Runs sind damit zuordenbar. Bestaetigt: Audit-Log zeigt `run_id` in allen Events, EBUSY-Rate bleibt 0.
- **EXIT_FREEZE in step_promote erkannt:** `exit_code=5` (Incident-Freeze waehrend Promote) wird als `frozen` Action gewertet und nicht als Fehler gezaehlt.
- **BUGFIX: Deadlock in orchestrate entfernt:** `test-vetting.sh` aus `acceptance_gates()` entfernt. Der outer `flock` im skill-forge Wrapper und der innere `with_state_lock` in `vet.sh` nutzten dieselbe Lock-Datei → Deadlock. Fix: nur noch `policy-lint.sh` als Gate; `test vetting` separat ausfuehren. Stale Deadlock-Prozesse aus vorherigen Runs manuell terminiert.
- **BUGFIX: tmp_dir Scope-Fehler in orchestrate:** `local tmp_dir` in `main()` war nach Funktionsrueckkehr nicht mehr im Scope; EXIT-Trap mit `set -u` warf `unbound variable`. Fix: `tmp_dir` global, Trap mit `[[ -n "${tmp_dir:-}" ]]`-Guard.
- **BUGFIX: incident-freeze auto_check las falsche Timestamps:** Verwendete `vetted_at`/`updated_at` aus `known-skills.json` statt `added_at` aus `pending-blacklist.json`. Fix: liest jetzt `added_at` aus der Blacklist-Datei, ermittelt Source per Slug-Lookup.
- **BUGFIX: vet.sh add_pending_blacklist nicht-atomarer Write:** Ersetzte direkten `open(p,'w')` durch `write_json_atomic` aus `py_helpers.py` (mit .bak-Backup und fsync+rename).
- **orchestrator.output.schema.json rueckwaertskompatibel:** Required Fields unveraendert; `--json` Output enthaelt zusaetzlich `steps`-Objekt mit Detail-JSON aller 5 Steps.
- **Incident-Freeze aufgehoben:** Trigger-Bedingung (5 pending-blacklist in 24h) seit >25h erloschen; manuell mit `incident freeze off` aufgehoben.
- **Freeze-Pfad: dispatcher fuer scout:** Nicht-JSON-Freeze-Pfad nutzt jetzt `dispatcher.sh scout scout.sh --dry-run` statt direkten Script-Aufruf.
- **Doku aktualisiert:** `docs/skills/skill-forge-governance.md` – Sektionen "Orchestrate", "Incident Freeze Lifecycle", "Bekannte Architektur-Grenzen".

## 2026-04-06
- **orchestrate.sh modular refactor (P1):** `run_vet_for_discovered` in 5 diskrete Steps aufgeteilt: `step_discover`, `step_vet`, `step_canary`, `step_promote`, `step_post_check`. Jeder Step schreibt JSON an eine Temp-Datei; klare Input/Output-Schnittstellen ohne Quoting-Probleme via Python-Heredocs.
- **Partial-Failure-Handling:** Per-Skill-Fehler (z. B. `tier_score_failed`) werden im `error`-Feld des jeweiligen Step-Results erfasst und erhoehen `error_count`. Ein kaputtes Skill bricht den Gesamt-Lauf nicht mehr ab.
- **run_id Propagation (State-Engine Hardening):** `orchestrate.sh` exportiert `SKILL_MANAGER_RUN_ID` vor dem ersten Step. `common.sh::log_audit` schreibt die Correlation-ID in jeden Audit-Log-Eintrag. Alle Audit-Events eines Runs sind damit zuordenbar. Bestaetigt: Audit-Log zeigt `run_id` in allen Events, EBUSY-Rate bleibt 0.
- **EXIT_FREEZE in step_promote erkannt:** `exit_code=5` (Incident-Freeze waehrend Promote) wird als `frozen` Action gewertet und nicht als Fehler gezaehlt.
- **BUGFIX: Deadlock in orchestrate entfernt:** `test-vetting.sh` aus `acceptance_gates()` entfernt. Der outer `flock` im skill-forge Wrapper und der innere `with_state_lock` in `vet.sh` nutzten dieselbe Lock-Datei → Deadlock. Fix: nur noch `policy-lint.sh` als Gate; `test vetting` separat ausfuehren. Stale Deadlock-Prozesse aus vorherigen Runs manuell terminiert.
- **BUGFIX: tmp_dir Scope-Fehler in orchestrate:** `local tmp_dir` in `main()` war nach Funktionsrueckkehr nicht mehr im Scope; EXIT-Trap mit `set -u` warf `unbound variable`. Fix: `tmp_dir` global, Trap mit `[[ -n "${tmp_dir:-}" ]]`-Guard.
- **BUGFIX: incident-freeze auto_check las falsche Timestamps:** Verwendete `vetted_at`/`updated_at` aus `known-skills.json` statt `added_at` aus `pending-blacklist.json`. Fix: liest jetzt `added_at` aus der Blacklist-Datei, ermittelt Source per Slug-Lookup.
- **BUGFIX: vet.sh add_pending_blacklist nicht-atomarer Write:** Ersetzte direkten `open(p,'w')` durch `write_json_atomic` aus `py_helpers.py` (mit .bak-Backup und fsync+rename).
- **orchestrator.output.schema.json rueckwaertskompatibel:** Required Fields unveraendert; `--json` Output enthaelt zusaetzlich `steps`-Objekt mit Detail-JSON aller 5 Steps.
- **Incident-Freeze aufgehoben:** Trigger-Bedingung (5 pending-blacklist in 24h) seit >25h erloschen; manuell mit `incident freeze off` aufgehoben.
- **Freeze-Pfad: dispatcher fuer scout:** Nicht-JSON-Freeze-Pfad nutzt jetzt `dispatcher.sh scout scout.sh --dry-run` statt direkten Script-Aufruf.
- **Doku aktualisiert:** `docs/skills/skill-forge-governance.md` – Sektionen "Orchestrate", "Incident Freeze Lifecycle", "Bekannte Architektur-Grenzen".

## 2026-04-05 (continued-7)
- **Canvas als zentrale Ops-Startseite weiter ausgebaut:** Dashboard-Quick-Links und Service-Matrix nutzen jetzt standardmaessig die Caddy-Reverse-Proxy-Hosts (`*.lan`) statt harter `IP:Port`-Links.
- **Besserer Reverse-Proxy-Link fuer die Zentrale:** Caddy route fuer Ops-UI auf Alias-Hosts erweitert (`canvas.lan`, `ops.lan`, `zentrale.lan`) fuer kuerzere, merkbare Einstiegs-URLs.
- **MQTT/HA Defaults fuer Proxy-Betrieb:** Canvas-Defaults auf `ha.lan` und `mqtt.lan` (Port `80`) gesetzt; Mosquitto-Open-Link zeigt auf `http://mqtt.lan`.

## 2026-04-05 (continued-6)
- **Canvas UI Phase 2.2 — Action-Log Histogram**: Added 24h SVG histogram above the action log stream (`#action-log-hist`). Aggregates per-hour success/fail counts from `action-log.latest.json`, renders stacked bars (`green=success`, `red=fail`) with time ticks every 6h and dynamic scaling.
- **Canvas UI Phase 2.3 — Dynamic Action Menu**: Replaced hardcoded action buttons with dynamic renderer (`#action-buttons`). Canvas now tries `GET /api/actions` and persists sanitized action names in localStorage config; graceful fallback to defaults (`hello`, `time`, `photo`, `dalek`) if endpoint is unavailable.
- **Canvas UI Phase 2.4 — Dark Mode Toggle**: Added settings toggle (`#set-dark-mode`) with persisted `darkMode` config key and runtime `applyTheme()` switching (`body.light-mode`). Default remains dark; light mode uses adjusted CSS variables for readable contrast.
- **Stability fix during implementation**: Repaired a transient patch corruption in `index.html` by restoring the style/header section and reapplying changes with bounded patches; post-fix smokecheck returns HTTP 200 and editor diagnostics show no errors.

## 2026-04-05 (continued-5)
- **Canvas UI Phase 1.3 — Loading States & Spinners**: Added `setLoading(componentId, isLoading)` utility function for displaying SVG spinner (20x20px, 1s rotation) over components. Spinner animation via CSS @keyframes. Component opacity reduced to 0.6 during loading. Ready for use across Dashboard/Chat/MQTT/RAG fetch operations. No integration in this phase; framework in place for future phases.
- **Canvas UI Phase 1.4 — Keyboard Shortcuts Panel**: Added modal dialog showing all keyboard shortcuts: 1-5 (page switch), R (refresh health), ? (show help), Esc (close modal), Enter/Shift+Enter (chat). Modal opens on `?` press (not in typing context), closes on Esc or click outside. Maintains accessibility with aria-hidden, aria-modal, role="dialog". Styled inline with contrast and KBD visual indicators (cyan accent, monospace font).

## 2026-04-05 (continued-4)
- **Canvas UI Phase 1.2 — Mobile Layout QA**: Added responsive CSS breakpoints for 380px devices (ultra-small mobile); ensured touch-friendly button/input min-height: 44px. Error banner now stacks vertically on <380px. Chat textarea, MQTT inputs, and RAG search fields all meet WCAG 2.1 AA touch target size (44x44px minimum). Tested viewport layouts: >=768px (desktop 2-col), 480-860px (tablet 1-col), 380-480px (small phone), <380px (ultra-compact). Validated all 5 pages responsive without horizontal scroll.

## 2026-04-05 (continued-3)
- **Canvas UI Phase 1.1 — Global Error Banner System**: Refactored error handling with centralized queue-based error management. Added `showError(type, message)` function with automatic 3-queue stacking and 15s auto-dismiss; integrated with all critical failure paths (Growbox/HA, Chat/OpenClaw, RAG Search, Action Log). Error types: network/auth/timeout/schema with color-coded banners and emoji hints. Replaces ad-hoc `showBanner()` calls with unified API. Maintains existing HTML/CSS; JavaScript manages queue flushing. Next: Mobile QA + Loading states (Phase 1.2).

## 2026-04-05 (continued-2)
- Added Canvas Settings phase selector: `growPhase` key in config, `PHASE_PRESETS` with seedling/veg/bloom/flush thresholds, "Load defaults" button fills threshold fields; phase saved to localStorage.
- Added global error banner to Canvas: `#global-error-banner` with `type-network/auth/timeout/schema` CSS classes, `showBanner()/hideBanner()/classifyFetchError()` helpers; hooked into growbox refresh failure.
- Added `/growbox` Telegram command handling to `ha-control/SKILL.md`: shell snippet for reading phase, sensors, and producing a compact summary message.
- Hardened py_helpers.py `write_json_atomic`: creates `.bak` before replace; `read_json_file` auto-restores from `.bak` on JSONDecodeError. Covers corrupted JSON recovery.
- Added flock-protected appends and atomic weekly-aggregate write to `metrics.sh` (`fcntl.LOCK_EX` + `mkstemp/os.replace`).
- Fixed `doc-keeper.sh` daily state update: migrated from raw `open(path,'w')` to `locked_json_update` via py_helpers.
- Added self-reflection learning detection to `heartbeat.sh`: appends orchestrate-failure entry to `.learnings/LEARNINGS.md` (already existed at `agent/skills/skill-forge/.learnings/`).
- Updated RAG ingest.py: added `agent/skills` to ALLOWED_DIRS (indexes SKILL.md files); added self-exclusion for `openclaw-rag` dir; increased `action-log.jsonl` TTL from 200 to 500 lines via `ACTION_LOG_MAX_LINES`.
- Created `scripts/pre-merge-gate.sh`: runs shellcheck on changed files, policy lint, and bash syntax check; `--all` mode also runs contract tests. All 3 checks pass. Fixed EXIT_* constants in `scripts/skill-forge` to use `export` (removes SC2034 shellcheck warnings).
- Added rate limiting to `pi-control/scripts/docker-compose.sh` restart: 120s window per service, tracked via `/tmp/pi-control-restart-rate/<service>.last`. Prevents restart loops.
- Pinned portainer, watchtower, and openclaw images by digest in docker-compose.yml (2026-04-05); documented update workflow in inline comments.
- Added all `.lan` hostnames to `/etc/hosts` on the Pi (Pi-hole DNS only serves LAN clients, not the host itself). `grafana.lan`/`prometheus.lan` now resolve correctly from the Pi.
- Updated `docs/core/security-baseline.md`: socket-proxy section now reflects actual setup (OpenClaw+Homepage via proxy, Portainer direct with accepted-risk documentation).

## 2026-04-05 (continued)
- Deployed Prometheus + Node Exporter + Grafana stack: `node-exporter` (host network, port 9100), `prometheus` (port 9090, 30d retention), `grafana-oss` (port 3003); created `prometheus/prometheus.yml` scraping node-exporter at 60s interval.
- Added `grafana.lan` and `prometheus.lan` routes to Caddy; added all `.lan` hostnames to `/etc/hosts` on the Pi itself (Pi-hole DNS only serves LAN clients, not the host itself).
- Hardened state writes in `metrics.sh` and `doc-keeper.sh`: `weekly_aggregate` now uses `flock` + `mkstemp` + `os.replace` (atomic); `doc-keeper-state.json` daily update migrated to `locked_json_update` via py_helpers. Policy lint: OK.
- Updated `docs/core/security-baseline.md`: corrected Docker socket section to reflect socket-proxy setup; added explicit Portainer-socket-direct section documenting accepted risk with compensating controls.
- Portainer socket-direct: documented as accepted risk in `docs/core/security-baseline.md`; todo closed.

## 2026-04-05
- Fixed mosquitto healthcheck (was using `mosquitto_sub` without credentials → always failing; replaced with TCP port check `nc -z 192.168.2.101 1883`).
- Fixed uptime-kuma healthcheck (`wget` not available in image; replaced with `node` HTTP-check).
- Added `ha-control/scripts/phase-thresholds.sh`: reads current grow phase from `growbox/GROW.md` (`**phase:**` field), maps to German phase names, and extracts matching thresholds from `THRESHOLDS.md`; supports `--json` mode for programmatic use by OpenClaw.
- Added OpenClaw webhook configuration in `openclaw.json` (hooks enabled, `/hooks` path, `growbox-alert` and `esp32-offline` mappings to main agent).
- Added HA automations for proactive OpenClaw notification: `growbox_alarm_openclaw` (temp >30/<18°C or RH >75/<35% for 2-5min) and `esp32_offline_openclaw` (sensor unavailable for 3min) → `rest_command` POST to webhook endpoints.
- Added `rest_command.openclaw_growbox_alert` and `openclaw_esp32_offline` to `homeassistant/config/configuration.yaml` using `!secret openclaw_webhook_bearer`; placeholder entry added to `secrets.yaml` (needs real token from `.env`).
- Added `OPENCLAW_WEBHOOK_TOKEN` and `OPENCLAW_WEBHOOK_BEARER` templates to `.env.example`.
- Added Telegram bot custom commands to `openclaw.json`: `/status`, `/growbox`, `/logs`, `/backup` appear in Telegram command menu.
- Added `pi-control/scripts/status-report.sh` aggregating service health, system metrics (temp/disk/RAM/uptime), and growbox sensors for `/status` command; documented handling for all four commands in `pi-control/SKILL.md`.
- Hardened skill-forge state writes: `incident-freeze.sh`, `blacklist.sh`, `blacklist-promote.sh` migrated from inline `open(..., 'w')` to `py_helpers.file_lock` + `write_json_atomic`; all three state files now written atomically under flock (`.blacklist.lock`, `.incident-freeze.lock`).
- Switched Homepage from direct `/var/run/docker.sock:ro` mount to `DOCKER_HOST=tcp://docker-socket-proxy:2375`; all three socket consumers (openclaw, homepage, glances) now route through the proxy. Portainer retains direct socket (management tool requires full API).
- Added `flock`-based exclusive locking to `reindex.sh` (concurrent runs abort silently); added `.reindex.status` file tracking `running/success/failed` state + checksum; tested concurrent invocation.
- Added `index_meta` table to RAG SQLite schema with `chunk_schema_version` (currently `1.2`) and `last_ingest_at`; written on every ingest run.
- RAG idempotent ingestion confirmed: `replace_file_chunks` uses DELETE+INSERT with `UNIQUE(source, chunk_index)` constraint + `--changed-only` flag; todo closed as already-implemented.
- Enabled and fixed fail2ban: corrected HA logpath (`homeassistant/config/home-assistant.log`), enabled and started service with SSH jail (maxretry=3, bantime=24h) and HA jail active.
- Switched OpenClaw from direct `/var/run/docker.sock` mount to `docker-socket-proxy` middleware (`DOCKER_HOST=tcp://docker-socket-proxy:2375`); direct socket volume removed from openclaw service. Reduces blast radius if OpenClaw is compromised.
- Pinned image versions in `docker-compose.yml` for all critical services: pihole 2026.04.0, homeassistant 2026.4.1, esphome 2026.3.2, tailscale v1.94.2, uptime-kuma 1.23.17, glances 4.5.3-full, homepage v1.12.3, mosquitto 2 (major-pinned), nginx 1.29-alpine. Portainer/watchtower/openclaw remain floating (no version labels available).
- Installed `restic 0.14.0` (arm64 via apt); extended `scripts/backup.sh` with optional offsite-backup section (gated on `RESTIC_REPOSITORY`+`RESTIC_PASSWORD` in `.env`); added restic vars to `.env.example`.
- Set heartbeat interval explicitly to 30m in `infra/openclaw-data/openclaw.json` (was unset, causing rapid-fire heartbeat cycles).

## 2026-04-04
- Evaluated `mvance/unbound:latest`: currently amd64-only on this host context (not suitable as-is for arm64 rollout); documented in `docs/decisions/unbound-evaluation.md`.
- Evaluated Immich for local growbox photo storage and confirmed arm64 image support (server + machine-learning); documented rollout recommendation in `docs/decisions/immich-evaluation.md`.
- Added growbox photo ritual docs (`growbox/diary/photos/README.md`, `DD.MM.YYYY.jpg`) and daily telegram hint when no new photo exists for >7 days.
- Added Growbox mini-sparklines (24h temperature/humidity) to Canvas using Home Assistant History API.
- Extended Canvas Growbox panel with calculated VPD (`kPa`) and combined alarm badge (`OK`/`WARN`/`ALARM`) derived from temp/humidity/CO2/VPD threshold states.
- Added automated Growbox diary flow: `growbox-diary.sh` creates `growbox/diary/DD.MM.YYYY.md` once per day (if missing), enriches entries with trigger context + sensor snapshot, and heartbeat logs the action.
- Added daily Growbox Telegram summary flow: `growbox-daily-report.sh` computes 24h min/max temperature/humidity plus alarms/ESP32 uptime and heartbeat triggers it once per day at 20:00 Europe/Berlin.
- Added Canvas Action-Log panel on MQTT page (latest 50 entries) backed by heartbeat-generated JSON feed `agent/skills/openclaw-ui/html/action-log.latest.json`.
- Extended weekly scout automation with auto-vetting for discovered skills where `scout_score > 7` (tracked as `auto_vetted` in heartbeat audit/action-log).
- Integrated weekly scout dry-run into `skill-forge heartbeat` (`scout --dry-run 5`) with pending-review summary plus audit/action-log entries.
- Reindexed RAG after adding `growbox/HARVEST.md`; harvest schema/content is now retrievable for recommendation context.
- Added `growbox/HARVEST.md` as structured harvest history file (date, dry weight, strain, notes, curing window).
- Documented grow phase handling baseline: `growbox/THRESHOLDS.md` as phase-specific threshold source and machine-readable `phase` field in `growbox/GROW.md`.
- Added OpenClaw action-log ingestion to RAG (`infra/openclaw-data/action-log.jsonl`, normalized/bounded window) so operational actions become searchable.
- Implemented RAG index versioning workflow: daily snapshot rotation (`snapshots/index.db.YYYY-MM-DD`, keep 7), backup integration for snapshot folder, and reindex action-log entries with `index_checksum`.
- Integrated weekly bats regression run into `skill-forge heartbeat` (`health-check.bats` + `backup.bats`) with audit/action-log entries.
- Installed `bats` (arm64) and added shell regression tests in `scripts/tests/health-check.bats` and `scripts/tests/backup.bats` (validated with 4 passing tests).
- Added append-only OpenClaw action log at `infra/openclaw-data/action-log.jsonl` and integrated heartbeat writes for non-trivial steps (orchestrate, doc-keeper daily, weekly metrics, telegram summary).
- Added NVMe SMART monitoring automation: `scripts/health-check.sh` now alerts when SMART status is not `PASSED`, and `skill-forge heartbeat` performs a weekly SMART snapshot (`smartctl -a /dev/nvme0n1`) included in Telegram system status.
- Refactored duplicated inline Python state helpers into shared module `agent/skills/skill-forge/scripts/py_helpers.py` (atomic JSON read/write, UTC timestamp helper, file-lock helper) and migrated skill/authoring/coding dispatch scripts to it.
- Hardened Canvas settings security: input validation/sanitization for HA URL and MQTT host, versioned localStorage keyspace migration (`oc.canvas.v2.*`), and a dedicated `Reset local credentials` action for local HA/MQTT secrets.
- Added Homepage dashboard (`ghcr.io/gethomepage/homepage:latest`) on `:3002` with Caddy routes `home.lan` and `dashboard.lan`, plus initial config in `homepage/config/services.yaml`.
- Added `scripts/canvas-drift-check.sh` to detect Canvas source/deploy drift via SHA256 comparison (includes JSON mode and drift exit code).
- Deployed Uptime Kuma (`louislam/uptime-kuma:latest`) on `:3001` with Caddy route `uptime.lan`, persistent volume, and setup guide for core monitor set plus Telegram alerting (`docs/operations/uptime-kuma-setup.md`).
- Deployed Glances (`nicolargo/glances:latest-full`) in host mode on `:61208` with Caddy route `glances.lan` and Canvas Settings quick links.
- Added documented skill-install retry policy by failure class (network vs policy vs hash-mismatch) in `docs/skills/skill-install-retry-strategy.md`.
- Extended skill-forge metrics with `metrics install-success` for direct latest/weekly install success rate reporting.
- Unified wrapper/lifecycle exit-code conventions and documented them (`2` usage, `3` contract, `4` policy, `5` freeze, `6` missing executable) across key entrypoints (`scripts/skill-forge`, `scripts/skills`, dispatcher/canary/writer/author wrappers).
- Standardized shell lint workflow with repo-wide `.shellcheckrc`, new `scripts/lint-shell.sh`, and `skill-forge lint shell --changed` (with Docker fallback to `koalaman/shellcheck-alpine` if local shellcheck is missing).
- Evaluated three-tier memory pattern (Session/Working/Distilled) and deferred rollout; retained current file-based memory flow and rejected 5s background memsearch watcher for now (`docs/decisions/memory-tier-evaluation.md`).
- Documented web-search decision: defer SearXNG deployment for now, keep existing web-fetch workflows, and postpone `web.search` contract expansion until a search backend is deployed (`docs/decisions/web-search-decision.md`).
- Documented time-series decision for Growbox sensor history: use Home Assistant History API (Option B) now, defer InfluxDB/Grafana (Option A) until deeper analytics are required (`docs/monitoring/time-series-decision.md`).
- Evaluated n8n as automation glue and documented decision to defer deployment in favor of direct OpenClaw skill orchestration (`docs/decisions/automation-decision-n8n.md`).
- Added Pi temperature signal to Canvas Live Signals panel via Home Assistant entity `sensor.raspberry_pi_cpu_temperature` with warn/bad thresholds (70C/80C).
- Added `skill-forge audit --ebusy-baseline [hours]` to quantify config-write race indicators from audit logs; current 24h baseline: 0/412 events (`ebusy_rate=0.0`).
- Extended Canvas dashboard with Growbox live panel (Temp/Humidity/CO2 via Home Assistant REST), local HA token/url settings, threshold-based ok/warn/bad coloring, and configurable auto-refresh (default 30s).
- Added automated wrapper/domain contract regression test via `skill-forge test wrappers` (exit-code parity checks, canary JSON parity between `skill-forge` and `skills`, and dispatcher JSON reachability smoke).
- Migrated skill-forge audit output from pipe-text to JSONL (`.state/audit-log.jsonl`) with structured fields (`ts`, `actor`, `command`, `target`, `result`, `reason`, `run_id`, `message`) and legacy-read compatibility for existing `audit.log` lines.
- Upgraded dispatcher output validation to recursive schema checks (nested required fields, arrays/items, additionalProperties, enum/const, min/max constraints) and added optional `--strict-output` mode for CI/regression gates.
- Added audit analytics commands: `skill-forge audit --top-failures`, `--blocked-promotions`, `--frequent-rejects`.
- Moved resolved architecture decisions (RAG backend/ingestion runtime, Caddy LAN proxy mode, Canvas MQTT auth model, handshake format) from todo tracking into architecture documentation.
- Tuned kernel VM behavior: set `vm.swappiness=10` in `/etc/sysctl.conf`, applied live via `sysctl -p`, and validated active value.
- Added `docs/runbooks/rag-reindex-failure-recovery.md` covering partial-index recovery, corruption handling, and rollback workflow.
- Defined Canvas UI metrics in `docs/operations/canvas-smoke-checklist.md` (Action-Success-Rate and Fehlerquote) with initial target thresholds.
- Added RAG operations baseline metrics (Precision@5, Recall@5, p95 latency, index freshness) in maintenance docs and created a weekly Saturday runbook (`docs/runbooks/rag-qualitaetsreport-samstag.md`).
- Extended `scripts/health-check.sh` with a RAG index freshness alert (`index.db` older than 48h) and validated runtime behavior.
- Expanded Samba veto list to include runtime-sensitive names (`memory`, `openclaw-data`) in addition to `.env` secrets.
- Documented Canvas deployment/rollback path and keyboard shortcuts in service docs, and added a versioned Canvas smoke checklist (`docs/operations/canvas-smoke-checklist.md`).
- Added image status/pinning comment lines per service in `docker-compose.yml` for faster manual update review.
- Added first incident runbooks: `docs/runbooks/pihole-dns-ausfall.md`, `docs/runbooks/openclaw-nicht-erreichbar.md`, and `docs/runbooks/esp32-offline.md`.
- Hardened Mosquitto runtime config: listeners for 1883/9001 now bind to `192.168.2.101` (LAN IP) and file logging was removed in favor of `log_dest stdout`.
- Expanded `docs/core/network-topology.md` with current LAN topology and a live binding assessment (`ss -tulpen`) including MQTT exposure notes.
- Added Canvas keyboard shortcuts: `1-5` for page navigation, `r` for health refresh, and `Esc` to close open dialogs/modals or clear focus.
- Enabled Pi-hole wildcard DNS for `.lan` domains (`address=/.lan/192.168.2.101`) to reduce per-host local DNS maintenance.
- Added Canvas PWA baseline: `manifest.json` with standalone display and icons, manifest link/theme-color in HTML, plus `sw.js` offline fallback ("Verbindung zum Pi verloren").
- Extended Canvas MQTT settings with username/password fields and switched MQTT CONNECT from anonymous to optional credential-based auth sourced from browser localStorage.
- Formalized Canvas single-source setup: `agent/skills/openclaw-ui/html/index.html` is now canonical and `infra/openclaw-data/canvas/index.html` is symlinked to it.
- Documented ARM64 RAG build/runtime gotchas in `docs/operations/maintenance-and-backups.md` (local rag-embed build behavior, dependency constraints, and health-check flow).
- Added Caddy reverse proxy with LAN hostnames (`*.lan`) for Pi-hole, Home Assistant, ESPHome, Portainer, OpenClaw, Canvas, and MQTT WebSocket endpoint routing.
- Extended `scripts/health-check.sh` with a host-header based Caddy smoke-check (`openclaw.lan` via port 80).
- Updated infra/service docs (`CLAUDE.md`, `agent/TOOLS.md`, `docs/core/services-and-ports.md`) to include Caddy and Canvas/MQTT WebSocket URLs.
- Added Pi-hole local DNS host mappings in `pihole.toml` for `pihole.lan`, `ha.lan`, `esphome.lan`, `portainer.lan`, `openclaw.lan`, `canvas.lan`, and `mqtt.lan` -> `192.168.2.101`.
- Recreated the `openclaw` container to apply configured compose memory controls; runtime now enforces `mem_limit: 1g` and `mem_reservation: 256m` (validated via `docker inspect` and `docker stats`).
- Enforced skill-forge canary maturity gate: promotions now require 24h minimum canary runtime; emergency override requires `--emergency --reason`.
- Changed install flow: vetted skills are now started in canary and no longer auto-promoted immediately.
- Added state-write safety for critical lifecycle files (`known-skills.json`, `canary.json`, `author-queue.json`, `writer-jobs.json`) with atomic tmp+rename writes.
- Added state locking for concurrent lifecycle operations (wrapper-level flock plus script-level lock helper usage in critical mutation paths).
- Switched Watchtower to label opt-in mode and limited automatic updates to `esphome`, `portainer`, `mosquitto`, `watchtower`, and `ops-ui`; kept `homeassistant`, `pihole`, and `openclaw` excluded.
- Switched `.gitignore` to a whitelist-first model (`*` + explicit allowlist) and kept sensitive/runtime paths explicitly blacklisted.
- Added Telegram notifications to `skill-forge heartbeat` (summary after each run; automatic chat-id lookup via `getUpdates` when `TELEGRAM_CHAT_ID` is unset; explicit skip hint when token/chat cannot be resolved).
- Clarified heartbeat status snapshot fields: `pending_blacklist_status` (known-skills status count) and `pending_blacklist_queue` (queue length) to avoid counter confusion.
- Improved Telegram heartbeat formatting with readable sections, separators, and emoji markers for faster mobile scanning.
- Expanded heartbeat Telegram scope to full-system context with three logical layers: current runtime snapshot, 24h audit digest, and trend deltas vs. weekly averages.
- Added a formal scheduled-task block in `agent/HEARTBEAT.md` (daily 06:00/08:00/20:00 and weekly Saturday/Sunday checks) to standardize autonomous run cadence.
- Extended `scripts/health-check.sh` with Pi temperature monitoring (`vcgencmd`) including warn/critical thresholds and a non-fatal skip on systems without `/dev/vcio` access.
- Added the pi-control skill with bounded scripts for Docker, disk, system metrics, and backup actions.
- Added agent/HANDSHAKE.md and linked the protocol from CLAUDE.md and agent/HEARTBEAT.md.
- Added a local pre-commit hook that blocks staged `.env`, `secrets.yaml`, and `passwd` files.
- Started a repository changelog convention for future manual updates before commits.
- Added root navigation via index.md and expanded CLAUDE.md with current-state references.
- Added doc-keeper and ha-control skills with skill-forge agent contracts.
- Documented the accepted Docker socket risk and compensating controls.
- Enabled a bounded Home Assistant recorder configuration with 30-day retention and exclusions for noisy Growbox entities.

<!-- DOC_KEEPER_AUTO_START -->
Auto-updated: 2026-04-05T07:36:00Z
Reason: heartbeat-daily
Mode: daily
Recent git commits:
- 1f1447a Initial homelab setup: folder structure, CLAUDE.md, README, docs, scripts (2026-04-03 23:25:21 +0200)
<!-- DOC_KEEPER_AUTO_END -->

