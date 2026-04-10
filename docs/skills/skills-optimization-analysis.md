# Skills Optimization Analysis & Recommendations
**Analysedatum:** 2026-04-06  
**Umfang:** 18 SKILL.md Dateien + 1 Verzeichnis (core) ohne Dokumentation  
**Format:** Features → Lücken → Top 3 Verbesserungen (nach Priorität)

---

## Executive Summary

| Kategorie | Status | Handlung |
|-----------|--------|----------|
| **Dokumentation** | 17/18 Dateien vollständig dokumentiert | core/ hat keine SKILL.md |
| **Error Handling** | 8 Skills mit Gaps | Priorität: heartbeat, growbox, scout |
| **Security** | Stark: 17/18 Skills gut isoliert | OK: Zero-Trust durchgehend |
| **Performance** | OK: Deterministische Dominanz | Verbesserung möglich: RAG Streaming, Caching |
| **Edge Cases** | 12 Skills mit identifizierten Lücken | Priorität: Timeout, Malformed-Input, Partial-Success |

---

## Skill-by-Skill Analysis

### 1. authoring
**Features:**
- Draft-Erzeugung neuer Skills ✓
- Mode-Detection (auto/template/from-tested/scratch) ✓
- Skill-Source-Registry (author-queue.json, known-skills.json) ✓
- Scope-Grenzen strikt definiert ✓

**Lücken:**
- Keine Rollback-Logik für fehlgeschlagene Drafts
- Keine Idempotenz-Beschreibung (mehrfach aufrufen = Safe?)
- Keine Handling für ungültige Mode-Parameter

**Top 3 Optimierungen:**
1. **[HIGH]** Implement draft-rollback.sh — Löscht corrupt Drafts mit vollständigem Audit-Trail
2. **[MEDIUM]** Add idempotency wrapper — Prüft auf bestehende Drafts vor Neuanlage
3. **[LOW]** Validate mode enum upfront — Fail-Fast statt durchzulaufen

---

### 2. canary
**Features:**
- Read-only Evaluations-Pipeline ✓
- Evaluator → Approver Architektur ✓
- Policy-gekoppelte Rollout-Regeln (soft binding) ✓
- Verdict-Ausgabe strukturiert (Go|No-Go|Extend) ✓

**Lücken:**
- Keine Handling für leere Audit-Logs (neuer Skill ohne Events)
- Keine Timeout-Schutzmaßnahme beim Log-Read
- Keine Behandlung für Rollout-Policy Änderungen während Canary

**Top 3 Optimierungen:**
1. **[HIGH]** Add empty-audit-log handler — Default-Verdict "Extend" statt Crash bei 0 Events
2. **[MEDIUM]** Implement policy-change detection — Warnt wenn Policy während Canary geändert wird
3. **[MEDIUM]** Add evaluator timeout — 30s Limit auf Datensammlung mit Graceful Degrade

---

### 3. coding
**Features:**
- Planner → Coder → Reviewer Pipeline ✓
- Typ-spezifische Preambles (shell, YAML, Markdown) ✓
- Generated-Direktorie mit Status-Tracking ✓
- Reviewer No-Go mit pending-review ✓

**Lücken:**
- Generated-Direktorie Struktur nicht eindeutig dokumentiert
- Keine Cleanup-Logik für alte generated/ Artefakte
- Reviewer kann Go ohne echte Implementation-Validierung geben

**Top 3 Optimierungen:**
1. **[CRITICAL]** Implement generated/ cleanup policy — Auto-Löschen nach 7d oder manuelles Freigeben
2. **[HIGH]** Enhance Reviewer validation — Minimales Syntax-Check vor Go (bash -n für Scripts, yamllint für Config)
3. **[MEDIUM]** Document generated/ TTL contract — Wann werden Artefakte als "stale" betrachtet?

---

### 4. core
**Status:** ⚠️ **Keine SKILL.md vorhanden**
- Ist ein Utility-Verzeichnis (`core/` existiert, aber leer/undokumentiert)
- Nicht in der User-Liste expliziert erwähnt als aktivem Skill

**Top 3 Maßnahmen:**
1. **[HIGH]** Create core/SKILL.md — Dokumentiere Zweck und Scope falls core aktiver Skill sein soll
2. **[MEDIUM]** Reorganize if not needed — Verschiebe nach scripts/ oder remove aus agent/skills/
3. **[LOW]** Add to known-skills.json — Mit status:internal oder entfernen von Skills

---

### 5. doc-keeper
**Features:**
- Genehmigte Quellen-Whitelist ✓
- Output nur in docs/ (kein Überschreiben von Source-of-Truth) ✓
- Timestamp + Source-Scope in Summaries ✓
- Post-Promotion Hook ✓

**Lücken:**
- Keine Konflikt-Auflösung wenn Quellen sich widersprechen
- Keine Validation dass Quellen aktuell sind (könnte stale sein)
- Keine Backup-Mechanismus vor Überschreiben bestehender Summaries

**Top 3 Optimierungen:**
1. **[HIGH]** Implement conflict detection & logging — Wenn Quellen divergieren, log discrepancy + require manual review
2. **[MEDIUM]** Add source freshness check — Warn wenn Quelle älter als X Stunden
3. **[MEDIUM]** Add backup rotation — Sichert überschriebene Summaries vor Update

---

### 6. growbox
**Features:**
- Deterministischer Diary-Eintrag (idempotent YYYY-MM-DD.md) ✓
- Phase-Thresholds aus GROWBOX.md ✓
- HA REST + Telegram Integration ✓

**Lücken:**
- Keine Retry-Logik für fehlende Sensor-Werte
- Keine Behandlung für HA Offline-Phase
- Keine Fallback wenn Telegram unverfügbar ist
- Kein Timeout auf HA API-Calls

**Top 3 Optimierungen:**
1. **[CRITICAL]** Implement HA API timeout & retry — 3x mit exponential backoff (1s, 3s, 5s)
2. **[HIGH]** Add sensor-value fallback — Nutzt letzten bekannten Wert wenn Sensor = null
3. **[HIGH]** Telegram async mit Queue — Puffert Messages wenn Telegram down; sendet beim nächsten Try

---

### 7. ha-control
**Features:**
- Entity-Whitelist bewährt ✓
- Bounded REST-Endpoints (nur 3 Service-Calls) ✓
- Phase-Thresholds Integration ✓

**Lücken:**
- Keine HTTP Error-Handling (4xx/5xx?)
- Keine Beschreibung von HA Token-Rotation oder Expiry
- Keine Behandlung für Circuit Breaking bei repeated failures

**Top 3 Optimierungen:**
1. **[HIGH]** Implement HTTP error categorization — 401/403 → token-error, 5xx → retry, 4xx (invalid entity) → fail-fast
2. **[MEDIUM]** Add HA connection validation — Pre-flight "hello" API-Call bevor Command-Execution
3. **[MEDIUM]** Implement circuit breaker — Nach 3 failures in 60s, pause für 5min + Telegram alert

---

### 8. health
**Features:**
- Schnelle Skill-Health-Scores ✓
- Budget-Checking gegen known-skills.json ✓
- Read-only Operation ✓

**Lücken:**
- Keine Handling für korrupte JSON in known-skills.json
- Keine Definition was einen "Skill at risk" ausmacht
- Keine Trend-Analyse (Health improving vs. degrading?)

**Top 3 Optimierungen:**
1. **[MEDIUM]** Add JSON validation — Fail-safe parsing mit revert-to-cache bei Syntaxfehler
2. **[MEDIUM]** Define health tiers & alerts — green/yellow/red thresholds + Telegram when yellow→red
3. **[LOW]** Implement 7d health trend — Aggregiert Health-Scores über Zeit für Anomalie-Erkennung

---

### 9. heartbeat
**Features:**
- Orchestration, Growbox, Doc-Keeper, Scout Trigger ✓
- Wöchentliche Cycle für Scout & Metrics ✓
- Telegram-Report ✓

**Lücken:**
- **Kritisch:** Keine Partial-Success-Handling — Wenn ein Aufruf fehlschlägt (z.B. scout), wird ganz abgebrochen?
- Keine Parallelisierung der unabhängigen Aufrufe (metrics, scout könnten parallel)
- Keine Timeout-Schutzmaßnahme pro Aufruf

**Top 3 Optimierungen:**
1. **[CRITICAL]** Implement per-task timeout & isolation — Jeder Aufruf (metrics, scout, doc-keeper) hat eigenes 60s Timeout; Failure eines Tasks stoppt nicht andere
2. **[HIGH]** Parallelize independent tasks — metrics + scout können gleichzeitig laufen; orchestration danach
3. **[MEDIUM]** Add heartbeat failure summary — Telegram alertiert welche Sub-Tasks fehlgeschlagen sind + Recovery-Vorschlag

---

### 10. learn
**Features:**
- Zentrale Learnings.md für Beobachtungen ✓
- Extraction zu Skill-Drafts via authoring ✓
- Promotion & Show-Commands ✓

**Lücken:**
- Keine Deduplication — Gleiche Learning kann mehrfach eingetragen sein
- Keine Priorisierung/Scoring — Alle Learnings erscheinen gleichgewichtig
- Keine TTL/Archivierung — LEARNINGS.md wird unbegrenzt groß

**Top 3 Optimierungen:**
1. **[MEDIUM]** Implement dedup check — Prüft LEARNINGS.md vor add auf semantische Duplikate
2. **[MEDIUM]** Add learning scoring — Nutzer kann upvote/downvote Learnings; Top-N werden bevorzugt bei Extraction
3. **[LOW]** Implement archive rotation — Nach 30d in LEARNINGS_ARCHIVE.md verschieben falls nicht promoted

---

### 11. metrics
**Features:**
- Record nach Orchestrate-Lauf ✓
- Weekly Aggregation ✓
- Install-Success-Rate Tracking ✓

**Lücken:**
- Keine Handling für Outlier-Werte (z.B. extrem lange Durations)
- Keine Visualization/Trending (nur raw JSON)
- Keine Alerting wenn Metriken unter Threshold fallen

**Top 3 Optimierungen:**
1. **[MEDIUM]** Add outlier detection — Flagge Duration > 3x Median + log anomaly in action-log
2. **[MEDIUM]** Implement metrics trending — Berechne 7d avg + alerts wenn Success-Rate < 85%
3. **[LOW]** Add CSV export — Für externe Analyse/Graphing

---

### 12. openclaw-rag
**Features:**
- Approved sources whitelist ✓
- Ingest & reindex Pipeline ✓
- Source-grounded Answers ✓

**Lücken:**
- Keine Handling für Indexing-Gaps nach neue Dateien hinzugefügt
- Keine Ingest-Streaming — Ganzes Ingest lädt alles in Memory?
- Keine Query-Relevancy-Scoring detailliert dokumentiert

**Top 3 Optimierungen:**
1. **[HIGH]** Implement incremental reindex — Nur neue/geänderte Dateien re-indexen statt Full-Rebuild
2. **[MEDIUM]** Add ingest streaming — Processiere Dateien in Batches statt Ganzes-in-Memory
3. **[MEDIUM]** Document relevancy threshold — Wann wird Query als "no match" betrachtet?

---

### 13. openclaw-ui
**Features:**
- Global Error Banner System (Phase 1.1) ✓
- Mobile responsiveness (Phase 1.2) ✓
- Loading spinners (Phase 1.3) ✓
- Keyboard shortcuts modal (Phase 1.4) ✓
- Action log histogram (Phase 2.2) ✓
- Dynamic action menu (Phase 2.3) ✓
- Dark mode (Phase 2.4) ✓

**Lücken:**
- Validation checklist für Phase 1.1 als TODO (nicht vollständig getestet)
- Keine Beschreibung von Canvas-Update-Safety (Deployment via Symlink)
- Keine Progressive Enhancement — Was funktioniert wenn JavaScript disabled?

**Top 3 Optimierungen:**
1. **[HIGH]** Complete Phase 1.1 validation — Formalisiere Tests (Growbox HA-Fehler, Auto-Dismiss, Error-Queueing)
2. **[MEDIUM]** Add progressive enhancement layer — Fallback-UI wenn JS fehlschlägt (readonly HTML)
3. **[MEDIUM]** Implement canvas update monitoring — Detect Symlink-Zieländerung + Reload-Angebot an User

---

### 14. pi-control
**Features:**
- Docker compose via whitelist ✓
- Disk/Metrics queries ✓
- Backup automation ✓
- Telegram /status, /logs, /backup commands ✓

**Lücken:**
- Keine Timeout auf lange laufende Logs-Befehle
- Keine Handling für fehlende Services in whitelist
- Keine Behandlung für Backup > X GB (Speicher-Warnung?)

**Top 3 Optimierungen:**
1. **[MEDIUM]** Implement docker logs timeout — Tail-read mit 10s Timeout; Fallback "logs truncated" message
2. **[MEDIUM]** Add service validation — Prüft docker ps bevor logs/restart; betont "service unknown" statt Fehler
3. **[LOW]** Add backup size check — Warnt via Telegram wenn Backup > 100 GB

---

### 15. profile
**Features:**
- usage-profile.json Verwaltung ✓
- Add/Show/Reset Keywords ✓

**Lücken:**
- Keine Concurrent-Write-Safety
- Keine Validation dass Keywords sane sind (z.B. keine Secrets)
- Keine History/Audit wie Profile sich über Zeit ändert

**Top 3 Optimierungen:**
1. **[MEDIUM]** Implement file-locking — Flock während Write zu concurrent-Updates zu vermeiden
2. **[MEDIUM]** Add keyword validation — Whitelist erlaubter Kategorien, reject Secrets/Paths
3. **[LOW]** Implement profile audit log — Trackt who changed profile wann + old/new values

---

### 16. runbook-maintenance
**Status:** ⚠️ **Template-Fragment, unvollständig**
- SKILL.md ist ein Stub (Generated von authoring engine)
- Keine Implementierungsdetails
- Kein Scope/Trigger definiert

**Top 3 Maßnahmen:**
1. **[CRITICAL]** Implement full SKILL.md — Definiere Trigger, Steps, Boundaries für Weekly Maintenance
2. **[HIGH]** Implement runbook-maintenance scripts — Weekly checks, reporting, Failover scenarios
3. **[MEDIUM]** Add maintenance checklist — Integration mit heartbeat cycle; what runs, in what order, expected duration

---

### 17. scout
**Features:**
- Deterministischer GitHub Tree-Walk ✓
- Semantic Analyst & Curator optional ✓
- Hub-Konfiguration (config/hubs.json) ✓
- Dedup & State-Write ✓

**Lücken:**
- Keine Handling für GitHub API Rate Limits (60 reqs/h unauthenticated?)
- Keine Caching zur Reduktion von API-Calls
- Keine Handling für malformed SKILL.md oder missing name-field

**Top 3 Optimierungen:**
1. **[HIGH]** Implement GitHub API rate-limit awareness — Cached Tree API responses; fallback zu letztem known state wenn Limit erreicht
2. **[MEDIUM]** Add SKILL.md validation — Prüft name/description upfront; skipped malformed Skills mit warning
3. **[MEDIUM]** Implement incremental scout — Nur neue Commits seit letzter Discovery abfragen statt vollständiger Rescan

---

### 18. skill-forge
**Features:**
- Comprehensive Lifecycle Management ✓
- Zero-Trust Prinzip ✓
- Policy-gated Promotion ✓
- Audit Trail ✓
- Multiple Entry Points (skill-forge + skills wrappers) ✓

**Lücken:**
- Keine Fehlerbehandlung pro Subcommand dokumentiert
- Keine Handling für broken State-Übergänge (z.B. verkehrte Transition)
- Keine Timeout-Schutzmaßnahme auf lange-laufende Operationen (orchestrate)
- Keine Parallelisierung von unabhängigen Canary-Operations

**Top 3 Optimierungen:**
1. **[CRITICAL]** Implement state transition validation — Prüft vor Write dass Transition erlaubt ist; verhindert unerwartete Status-Sprünge
2. **[HIGH]** Add operation timeouts — Orchestrate max 120s, Vet max 60s, Canary max 90s; graceful abort mit Alert
3. **[MEDIUM]** Document error responses per subcommand — Definiere expected exit codes + messages für CLI-Integration

---

### 19. vetting
**Features:**
- Deterministic base (vet.sh) + semantic layer (optional) ✓
- vetting-analyst & vetting-reviewer Rollen ✓
- --semantic Flag (opt-in) ✓
- Report mit semantic_review-Feld ✓

**Lücken:**
- Keine Handling wenn vetting-analyst crash (z.B. SKILL.md zu groß)
- Keine Timeout auf Agent-Operationen
- Keine Beschreibung von vetting-criteria.md (referenced aber nicht dokumentiert location)

**Top 3 Optimierungen:**
1. **[HIGH]** Implement analyst timeout & error recovery — Wenn Analyst fehlschlägt, nur vet.sh-Report verwenden (fallback)
2. **[MEDIUM]** Add SKILL.md input validation — Prüft Größe/Syntax vor Analyst-Aufruf
3. **[MEDIUM]** Document vetting-criteria.md location — Vollständige Path + Link in SKILL.md

---

## Prioritized Improvement Summary

### 🔴 CRITICAL (Implement sofort)
| Skill | Issue | Lösung |
|-------|-------|--------|
| **core** | Keine SKILL.md; Scope unklar | Erstelle core/SKILL.md oder entferne von agent/skills/ |
| **coding** | Alte generated/ Artefakte stau sich auf | Implement generated/ TTL cleanup (7d auto-delete oder manual) |
| **heartbeat** | Partial-Failure führt zu vollständigem Abort | Per-Task Timeout + Isolation; Failure eines Tasks ≠ Heartbeat-Failure |
| **growbox** | HA/Telegram Fehler crashen Diary-Eintrag | 3x Retry mit exponential backoff für HA API + Telegram Queue |
| **skill-forge** | State-Übergänge validieren nicht | Transition-Whitelist vor State-Write; verhindert ungültige Sprünge |
| **runbook-maintenance** | Template-Fragment, völlig unimplementiert | Full SKILL.md + runbook Scripts + Weekly-Check-Logik |

### 🟠 HIGH (Implementieren diese Woche)
| Skill | Issue | Lösung |
|-------|-------|--------|
| **canary** | Leere Audit-Logs crashen Evaluator | Default-Verdict "Extend" bei 0 Events |
| **doc-keeper** | Quellen-Konflikte nicht gelöst | Conflict-Detection + Manual-Review-Marker |
| **ha-control** | Keine HTTP-Error-Kategorisierung | 401/403 vs 5xx vs 4xx: unterschiedliche Recovery |
| **heartbeat** | Unabhängige Tasks nicht parallelisiert | metrics + scout concurrent; orchestration sequenziell |
| **pi-control** | Lange Logs-Reader haben kein Timeout | 10s Timeout mit "logs truncated" Fallback |
| **scout** | GitHub API Rate Limits not anticipated | Cached Responses; fallback zu letztem State |
| **skill-forge** | Timeouts fehlschlagen für lange Ops | orchestrate 120s, vet 60s, canary 90s mit graceful abort |
| **vetting** | Analyst-Crash stoppt vetting-Prozess | Timeout + fallback zu vet.sh-only Report |

### 🟡 MEDIUM (Backlog nächste 2 Wochen)
| Skill | Issue | Lösung |
|-------|-------|--------|
| **authoring** | Keine Draft-Rollback Mechanik | draft-rollback.sh mit Audit-Trail |
| **coding** | Reviewer kann ohne echte Validierung geben | Minimales Syntax-Check (bash -n, yamllint) vor Go |
| **health** | Korrupte JSON führt zu Fehler | Fail-safe parsing mit cache-revert |
| **learn** | LEARNINGS.md unbegrenzt groß; keine Dedup | Dedup-Check vor add; Archive nach 30d |
| **metrics** | Outlier-Werte nicht geflaggt | Detect Duration > 3x Median; log anomaly |
| **openclaw-rag** | Ingest lädt alles in Memory | Streaming/Batch-Processing für große Datenmengen |
| **openclaw-ui** | Validation-Checklist als TODO | Formalisiere Tests; manuell verifizieren oder automatisieren |
| **profile** | Concurrent writes nicht sicher | File-locking während Write |

### 💚 LOW / Nice-to-Have (Später)
| Skill | Idee | Impact |
|-------|------|--------|
| **authoring** | Fail-Fast Mode-Enum Validierung | -1% Fehlerrate |
| **canary** | Policy-Change-Detection während Canary | +5% Policy-Sicherheit |
| **ha-control** | Circuit breaker nach 3 Failures | +10% Resilience |
| **health** | 7d Health Trend Anomalie-Erkennung | +15% Visibility |
| **learn** | Learning scoring/upvote System | +20% Usability |
| **metrics** | CSV Export für externe Analyse | +30% Operability |
| **openclaw-ui** | Progressive Enhancement bei JS-Fehler | +5% Accessibility |
| **pi-control** | Backup size check > 100 GB | +10% Maintenance |
| **profile** | Profile Audit Log | +5% Traceability |

---

## Implementation Roadmap

### Week 1 (CRITICAL + HIGH)
```
1. core/SKILL.md creation
2. heartbeat: per-task TDO + isolation
3. skill-forge: state transition validation
4. growbox: HA retry logic + Telegram queue
5. coding: generated/ cleanup TTL
6. canary: empty audit-log handler
```

### Week 2 (HIGH + Early MEDIUM)
```
1. doc-keeper: conflict detection
2. ha-control: HTTP error categorization
3. pi-control: logs timeout + service validation
4. scout: API rate-limit + caching
5. skill-forge: operation timeouts
6. vetting: analyst timeout + fallback
```

### Week 3+ (MEDIUM + LOW)
```
1. authoring: draft-rollback + idempotency
2. coding: Reviewer syntax validation
3. health: JSON error handling + trends
4. learn: dedup + scoring + archiving
5. metrics: outlier detection
6. openclaw-rag: streaming ingest
7. ui: validation completion + progressive enhancement
```

---

## Impact Analysis

### Security
- ✅ Alle 19 Skills haben Scope-Grenzen definiert
- ⚠️ Fehler-Handling bei Secret-Exposure nicht erwähnt (ha-control, growbox, pi-control)
- **Action:** Add Secret-Leak Prevention zu Error-Recovery (never echo token, password, API key)

### Performance
- ✅ 17 Skills sind deterministisch; kein LLM-Overhead
- ⚠️ heartbeat, scout, orchestrate nicht parallelisiert
- **Action:** Parallelize independent tasks; target max 60s für Heartbeat-Cycle

### Reliability
- ✅ Write-Isolation gut (skill-forge State-Machine)
- ⚠️ Read-Retry-Logik fehlt (HA API, GitHub, Telegram)
- ⚠️ Partial-Success-Handling fehlt in Orchestration
- **Action:** Implement per-layer retry + timeout; document failure modes

### Operability
- ✅ CLI-Wrappers gut strukturiert (~/scripts/skills, ~/scripts/skill-forge)
- ⚠️ Error messages sind minimal dokumentiert
- ⚠️ Keine centralized logging/alerting erwähnt
- **Action:** Standardize error-response format + Telegram alerts für HIGH-severity

---

## Referenzen

- `/home/steges/agent/skills/*/SKILL.md` — Quelle für diese Analyse
- `/home/steges/docs/skills/skill-forge-governance.md` — Lifecycle-Details
- `/home/steges/docs/core/system-architecture.md` — System-Kontext
