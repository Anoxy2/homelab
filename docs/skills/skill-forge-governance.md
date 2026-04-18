# Skill-Manager Betrieb

## Zweck

Der Skill-Manager steuert den gesamten Lifecycle von Skills und erzeugten Artefakten im OpenClaw-Workspace:

- Discovery und Vetting
- Multi-Source Discovery (GitHub-basierte Quellen)
- Quarantaene + Blacklist-Promotion
- Skill-Authoring (auto/template/from-tested/scratch)
- Canary-Rollout und Rollback
- Writer-Module fuer Docs/Code/Config/Test
- Governance ueber Policy, Audit, Budget, Health

## Bereits umgesetzt (nicht mehr Todo)

Der aktuelle Funktionsstand umfasst bereits:

- Domain-Wrapper `~/scripts/skills` fuer direkte Skill-Nutzung (coding, vetting, canary, authoring)
- Skill-Manager als Lifecycle/Governance-Schicht (install/update/rollback/policy/audit/orchestrate/provenance)
- Coding-Workflow mit Reviewer-Gate (`completed` vs `pending-review`)
- Vetting-Opt-in mit `--semantic`
- Canary-Evaluation mit `Go|No-Go|Extend` und Freeze-Beruecksichtigung

## Prinzip: Ein Skill, viele Wrapper

Neue oder wiederkehrende Faehigkeiten werden **nicht** als mehrfacher, fast gleicher Skill neu gebaut.
Stattdessen gilt:

- Eine fachliche Logik wird einmal als Skill mit klaren Rollen gebaut (z. B. `coding`, `vetting`, `canary`)
- Aufrufe laufen ueber Wrapper (`~/scripts/skill-forge` und `~/scripts/skills`) und Dispatcher
- Wiederverwendung passiert ueber Agent-Rollen und `agent-contracts.json`, nicht ueber Skill-Kopien

Ziel:

- weniger Drift zwischen aehnlichen Skills
- zentraler Security-/Policy-Check
- schnellere Aenderungen, weil nur eine Skill-Implementierung gepflegt wird

## Architektur-Grenzen (wichtig)

Es gibt drei Schichten, die bewusst getrennt sind:

1. Wrapper/CLI-Einstieg:
- `~/scripts/skill-forge`
- `~/scripts/skills`
- nimmt Kommandos entgegen und routed sie weiter

2. Skill-Manager-Core (Lifecycle-Engine):
- `~/agent/skills/skill-forge/scripts/`
- besitzt den kanonischen State (`known-skills.json`, `canary.json`, Audit-Log, Policy-Gates)
- darf hard-gates und State-Transitions ausfuehren

3. Domain-Skills (fachliche Logik):
- `~/agent/skills/coding/`, `~/agent/skills/vetting/`, `~/agent/skills/canary/`, `~/agent/skills/authoring/`
- liefern semantische Entscheidungen, Artefakt-Generierung oder read-only Evaluation
- werden ueber Wrapper/Core aufgerufen

Alle eigenstaendigen Skills (direkte Nutzung ueber `~/scripts/skills`):

```
skills coding code|docs|config|test <task-text>
skills vetting <slug> [--json]
skills canary evaluate <slug> [--json]
skills authoring <name> [--mode ...] [--reason ...]
skills scout [--dry-run|--live [N]|--summary|--add|--apply-suggestions] [--json] [--semantic]
skills heartbeat [--live [N] [vet_score]]
skills metrics record|weekly|latest|install-success|risk-report ...
skills profile show|add <keyword>|reset
skills learn observe "<text>" [--tags a,b] | show [--tag x] [--since 7d] [--json] | search "<q>" [--json] | weekly [--json] | promote <id> | extract <id>
skills memory remember "<text>" [--cat decision|pattern|config|incident|fact] [--tags x,y] [--actor <actor>]
skills memory recall [--cat x] [--tag y] [--since 30d] [--json]
skills memory search "<query>" [--json]
skills memory forget <id>
skills memory update <id> "<new text>"
skills memory ingest
skills memory stats [--json]
skills health report|budget
skills growbox diary|daily-report|flush-queue|should-report|mark-sent|status
skills rag doc-keeper run [--reason <text>] [--daily] [--autodoc] [--autodoc-dry-run]
skills runbook-maintenance weekly-check|checklist|failover <scenario> [--json]
skills vuln-watch --weekly [--dry-run] [--json] | --summary | --json
skills rag retrieve <query> [--limit N] [--json]
skills rag reindex [--changed-only] [--json]
```

JSON-Konvention fuer Wrapper und Dispatcher:
- `--json` ist kanonisch maschinenlesbar
- bei `--json` darf kein vorangestellter Klartext, Header oder Mischformat auf stdout erscheinen
- menschenlesbare Hinweise gehoeren nur in den Default-Modus ohne `--json`

Kurzantwort auf die typische Frage "geht alles ueber skill-forge?":
- Nein als Default: jeder Skill laeuft direkt ueber `~/scripts/skills`
- Ja nur fuer Lifecycle/Ops: `install`, `update`, `rollback`, `policy`, `audit`, `blacklist`, `orchestrate`, `incident`, `provenance`, `canary start|promote|fail`

Entscheidungsregel (immer anwenden):
- Skill fachlich nutzen → `~/scripts/skills <skill> ...`
- Skills verwalten / Governance / Lifecycle → `~/scripts/skill-forge ...`

## Boundary & Governance Model (Hartes Prinzip)

### `~/scripts/skill-forge` — NUR Governance & Lifecycle, KEINE Domain-Ausführung

Der Skill-Manager ist **ausschließlich** für Lifecycle- und Governance-Funktionen verantwortlich:

- **Installieren/Aktualisieren/Rollback** von Skills
- **Policy- und Audit-Kontrolle** über installed Skills
- **Canary-Rollout** und Promotion mit Governance-Gates
- **Incident Management** (Freeze, Blacklist)
- **Provenance** und Safety-Checklisten

Der Skill-Manager führt **keine fachlichen Domain-Aufgaben aus**. Er orchestriert sie nur, indem er:
- Domain-Skills über `~/scripts/skills` aufruft
- State-Transitions kontrolliert
- Policy-Gates enforced

**Konkreter Endzustand:**
```bash
# ❌ FALSCH - Skill-Manager darf keine Domain-Logik enthalten
~/scripts/skill-forge coding <task>           # Diese Command darf NICHT existieren
~/scripts/skill-forge heartbeat --live        # Diese Command darf NICHT existieren
~/scripts/skill-forge writer docs "<task>"    # Diese Command wird durch `~/scripts/skills coding ...` ersetzt

# ✅ RICHTIG - Domain-Skills laufen DIREKT über ~/scripts/skills
~/scripts/skills coding code|docs|config|test <task>
~/scripts/skills heartbeat [--live [N]]
# coding ist ein Domain-Skill, nicht ein Skill-Manager-Kommando
```

### `~/scripts/skills` — Domain-Ausführung & Fachaufgaben

Alle fachlichen Aufgaben werden **direkt über `~/scripts/skills`** ausgeführt:

- `coding` – Code, Doku, Configs schreiben/reviewen
- `heartbeat` – Status-Repport, Anomalie-Erkennung
- `metrics` – Metriken erfassen und auswerten
- `scout` – Neue Skills entdecken
- `learn` – Erkenntnisse extrahieren und sammeln
- `learn weekly` – verdichtet Audit-, Action- und Risk-Signale einmal pro Woche zu konkreten Verbesserungsvorschlaegen in `/home/steges/agent/LEARNINGS.md`
- `learn observe/search/show` – ad-hoc Learnings erfassen, filtern und durchsuchen
- `memory` – explizites, kategorisiertes Langzeitwissen in `memory.jsonl` pflegen und via `memory ingest` nach `agent/MEMORY.md` spiegeln
- `health`, `profile`, `growbox`, `runbook-maintenance`, `canary evaluate`, `rag (retrieve/reindex/doc-keeper/autodoc)` – alle weiteren Domain-Skills
- `vuln-watch` – Wöchentliche GitHub-Suche nach AI/LLM-Sicherheitslücken; schreibt in `docs/monitoring/vuln-log.md`, Top-5 via Telegram
- `rag` – RAG-Retrieval und Reindex

**OpenClaw nutzt für Fachaufgaben direkt `~/scripts/skills`, nicht `~/scripts/skill-forge`.**

Diese Trennung ist **hart verankert in den Skill-Contracts in `agent-contracts.json`** — wenn ein Agent einen Domain-Skill aufruft, wird der Dispatcher die Anfrage auf `~/scripts/skills` umleiten, nicht auf `~/scripts/skill-forge`.

### Orchestration vs. Ausführung

**Orchestration-Pfad (Skill-Manager-Kern):**
```bash
~/scripts/skill-forge orchestrate --vet-score 70
  → Discovery (Scout)
  → Vetting aller Skills
  → Canary-Promotion mit Gates
```

**Ausführungs-Pfad (Domain-Skills, direkt):**
```bash
# OpenClaw möchte Code schreiben
~/scripts/skills coding code "Implementiere X"
```

Der Orchestrator kann `~/scripts/skills` **aufrufen**, hat aber keine separate Vetting-Logik oder Code-Generierung. Diese bleiben im Skill-Kern.

### Keine doppelte Domain-Logik

**Verboten:**
- Eine `coding`-Implementierung im Skill-Manager und eine im Coding-Skill (Drift, Performance-Probleme, Sicherheitsrisiken)
- Writer-Module als Wrapper um echte Writer-Logik (Indirection ohne Mehrwert)

**Erlaubt:**
- Thin Delegation: Skill-Manager routed zur echten Implementation in `~/scripts/skills`
- Meta-Aufgaben: Policy-Enforcing, Audit-Logging, State-Transitions

### Erfolgs- und Abnahmkriterien

1. **Keine Domain-Aufgaben in skill-forge CLI:**
   - `~/scripts/skill-forge status|policy|audit|orchestrate` sind erlaubt (Governance)
   - `~/scripts/skill-forge coding|heartbeat|metrics|writer` sind **nicht erlaubt** (Domain)

2. **OpenClaw nutzt nur `~/scripts/skills` für Fachaufgaben:**
   - Agent-Contracts zeigen auf `skills`, nicht auf `skill-forge`
   - Runbooks und Cron-Jobs verwenden `skills`, nicht `skill-forge`

3. **Skill-Manager ist ein Control-Plane:**
   - Kann Domain-Befehle **orchestrieren** (z. B. alle Skills vetten vor Promotion)
   - Kann Domain-Befehle **blocken** (Policy, Freeze, Blacklist)
   - Führt sie aber nicht selbst **aus**

4. **Doku ist konsistent:**
   - `docs/skills/skill-forge-governance.md`, `docs/operations/session-handover.md`, `README.md` betouen diese Grenze
   - `~/scripts/skill-forge --help` und `~/scripts/skills --help` zeigen die klare Trennung

## Pfade

- Wrapper: `~/scripts/skill-forge`
- Domain-Wrapper: `~/scripts/skills`
- Root: `~/agent/skills/skill-forge/`
- State: `~/agent/skills/skill-forge/.state/`
- Policies: `~/agent/skills/skill-forge/policy/`
- Agent Contracts: `~/agent/skills/skill-forge/config/agent-contracts.json`
- Generierte Artefakte: `~/agent/skills/skill-forge/generated/`

## Orchestrate – Modulare Step-Pipeline

`orchestrate.sh` ist in 5 diskrete Steps aufgeteilt, die jeweils JSON an eine Temp-Datei schreiben und nacheinander aufgerufen werden:

1. **step_discover** – Scout laeuft, liefert Liste der `discovered`-Slugs aus State
2. **step_vet** – Vetting pro Slug; per-Skill-Fehler werden im `error`-Feld captured, nicht fatal
3. **step_canary** – Conflict-Check + Canary-Start fuer alle vetted Skills; Konflikte bleiben in Canary
4. **step_promote** – Promote-Versuch; frische Canaries schlagen mit `too_young` fehl (erwartetes Verhalten, kein Fehler); `frozen` bei aktivem Freeze
5. **step_post_check** – Freeze auto-check, Blacklist-Promote, Health, Budget

Jeder Step hat eine klare JSON-Schnittstelle:
- Input: Pfad zur vorherigen Step-JSON-Datei (ausser step_discover)
- Output: JSON in temporaere Datei mit `kind`, `run_id`, und step-spezifischen Feldern

Der finale `--json` Output bleibt rueckwaertskompatibel zum `orchestrator.output.schema.json` (required fields unveraendert) und enthaelt zusaetzlich ein `steps`-Objekt mit dem Detail-Output jedes Steps.

Partial-Failure-Handling: Fehler bei einem einzelnen Skill (z. B. `tier_score_failed`) werden im `error`-Feld des jeweiligen Results erfasst und erhoehen nur `error_count`. Der Rest des Runs laeuft weiter.

### run_id Propagation (State-Engine Hardening)

`orchestrate.sh` exportiert `SKILL_MANAGER_RUN_ID` als Umgebungsvariable vor dem ersten Step. Alle Subcommands (`canary.sh`, `vet.sh`, `dispatcher.sh` etc.) erben diesen Wert. `common.sh::log_audit` liest `SKILL_MANAGER_RUN_ID` und schreibt ihn in jedes Audit-Log-Event (`run_id`-Feld in `audit-log.jsonl`). So koennen alle Audit-Eintraege eines Orchestrate-Runs mit einer einzigen Correlation-ID zusammengefasst werden.

### Bekannte Architektur-Grenzen

**Outer-Lock Deadlock (gefixt):**
Der `skill-forge orchestrate` Wrapper haelt einen exklusiven `flock` auf `STATE_LOCK`. Wenn `acceptance_gates()` intern `test-vetting.sh` aufrief, das seinerseits `vet.sh` → `with_state_lock` (selbe Lock-Datei) ausloeste, entstand ein Deadlock. Fix: `test-vetting.sh` ist aus `acceptance_gates()` entfernt. Die Policy-Lint bleibt als Gate. Fuer Regressionstests:

```bash
~/scripts/skill-forge test vetting
```

**tmp_dir Scope (gefixt):**
`trap ... EXIT` feuert nach Rueckkehr aus `main()`, wo `local tmp_dir` nicht mehr im Scope war (`set -u` → Fehler). Fix: `tmp_dir` ist global (kein `local`) und die Trap prueft auf non-empty vor `rm -rf`.

## Incident Freeze – Lifecycle

### Wann wird ein Freeze ausgeloest?

Automatisch per `incident-freeze.sh auto-check`, wenn innerhalb von 24h `>= 3` neue `pending-blacklist`-Eintraege von derselben Source in `pending-blacklist.json` erscheinen.

### Wie heben?

```bash
~/scripts/skill-forge incident freeze status   # aktueller Zustand
~/scripts/skill-forge incident freeze off      # manuell aufheben (erfordert Claude/steges)
```

Policy `manual_override_required_for_unfreeze: true` bedeutet: auto-check kann NICHT selbst aufheben, auch wenn Bedingungen erloschen sind. `auto-check` gibt dann `CONDITIONS_CLEAR_MANUAL_UNFREEZE_REQUIRED` aus als Signal, dass manuelle Aufhebung sinnvoll waere.

### auto_check Bug (gefixt)

`auto_check` las vorher `vetted_at` / `updated_at` aus `known-skills.json` — das ist der Vetting-Zeitpunkt, nicht der Blacklist-Additions-Zeitpunkt. Fix: liest jetzt `added_at` aus `pending-blacklist.json` und ermittelt die `source` per Slug-Lookup in `known-skills.json`.

## State Safety (neu)

Der Skill-Manager nutzt jetzt zwei Schutzschichten fuer kritischen State:

- Serielle Ausfuehrung via Lock (`flock`) fuer Lifecycle-Kommandos (`orchestrate`, `update`, `author`, `canary`)
- Atomare JSON-Writes (tmp + `os.replace`) fuer zentrale State-Dateien
- Gemeinsame Python-Helfer in `~/agent/skills/skill-forge/scripts/py_helpers.py` fuer JSON read/write, UTC-Timestamps und File-Locking (statt duplizierter Inline-Implementierungen)

Betroffene Kern-Dateien:

- `known-skills.json`
- `canary.json`
- `author-queue.json`
- `writer-jobs.json`

Ziel:

- keine Race-Conditions bei parallelen Jobs
- keine korrupten/halb geschriebenen JSON-Dateien bei Abbruch waehrend Write

### Reentrantes Locking im Wrapper-Pfad (neu)

Beim Aufruf ueber `~/scripts/skill-forge` werden Lifecycle-Kommandos mit einem Outer-`flock` ausgefuehrt. Damit Subscripts im selben Prozesspfad nicht auf derselben Lock-Datei self-deadlocken, gilt:

- der Wrapper markiert gelockte Aufrufe mit `SM_LOCK_HELD=1`
- `with_state_lock` in `common.sh` erkennt diesen Marker und nimmt in diesem Fall **keinen** zweiten `flock`

Damit terminiert `canary promote` deterministisch statt an einem verschachtelten Lock zu blockieren.

### State-Transition Guards (neu)

Fuer `known-skills.json` werden ungueltige Statuswechsel jetzt aktiv blockiert:

- `vet.sh` akzeptiert nur definierte Zielstatus (`vetted`, `pending-review`, `pending-blacklist`) aus erlaubten Vorzustaenden
- `review.sh` erlaubt nur `pending-review -> reviewed` (idempotent `reviewed -> reviewed`)
- `canary.sh` prueft bei `start|promote|fail` die erlaubte Transition vor dem State-Write

Bei Verletzung wird der Write abgebrochen (Policy-Exit), statt inkonsistente Status in den State zu schreiben.

### Growbox Retry-Queue im Heartbeat (neu)

Der Growbox-Daily-Report hat jetzt eine persistente Retry-Queue in:

- `~/agent/skills/skill-forge/.state/growbox-message-queue.json`

Verhalten:

- Telegram-Send mit exponential backoff (1s, 3s, 5s)
- Bei Fehlschlag wird die Nachricht gequeued statt verworfen
- Jeder Heartbeat fuehrt `growbox flush-queue` aus und sendet queued Nachrichten nach
- `mark-sent` wird nur noch bei erfolgreichem Versand gesetzt (nicht mehr bei Queue-Fallback)
- HA-Reads nutzen ebenfalls Retry/Backoff und schreiben bei Teilfehlern Warnhinweise in den Versandpfad

## Audit und Contract-Validation (neu)

- Audit ist jetzt JSONL-basiert in `~/agent/skills/skill-forge/.state/audit-log.jsonl` (ein JSON-Objekt pro Zeile).
- Standardfelder pro Eintrag: `ts`, `actor`, `command`, `target`, `result`, `reason`, `run_id`, `message`.
- `audit.sh` und Metrik-/Heartbeat-Auswertungen lesen JSONL und bleiben kompatibel zu vorhandenen Legacy-Zeilen aus `audit.log`.
- `dispatcher.sh --validate-output` validiert rekursiv gegen das Output-Schema (inkl. nested `required`, `array`/`items`, `additionalProperties`, `enum`/`const`, Min/Max-Regeln).
- Optionaler Strict-Mode `--strict-output` erzwingt bei Object-Schemas mit `properties` standardmaessig keine Zusatzfelder (wenn `additionalProperties` nicht explizit gesetzt ist) und ist fuer CI/Regression gedacht.

## Skill-Hardening (Skills Optimization Phase 1)

Folgende haeufige Failure-Klassen sind jetzt in den Domain-Skills gehaertet:

- **HA-Control:** `get-state.sh`/`call-service.sh` nutzen Timeouts; `call-service.sh` klassifiziert HTTP-Fehler (`401/403`, `5xx`, restliche `4xx`) mit klaren Operator-Hinweisen.
- **Pi-Control:** `docker-compose.sh logs` hat einen harten Timeout (`PI_CONTROL_LOGS_TIMEOUT`) und beendet bei Timeout kontrolliert mit Truncation-Hinweis statt Blocking.
- **Vetting:** `vetting-dispatch.sh` isoliert Analyst-Fehler (Timeout, unlesbare/zu grosse `SKILL.md`) und faellt auf neutralen semantischen Delta zurueck, damit der Vetting-Flow nicht komplett abbricht.
- **Canary:** `canary-dispatch.sh` toleriert leere/korrupten State- und Audit-Dateien besser und nutzt robuste JSONL-Feld-Auswertung (`command`/`message`).
- **Canary Promote Flow:** `canary.sh` kapselt `evaluate_summary` mit Timeout und ruft den Post-Promote Doc-Keeper ueber den gueltigen Entry-Point `~/scripts/skills rag doc-keeper ...` auf.
- **Doc-Keeper im RAG-Skill:** `openclaw-rag/scripts/doc-keeper-dispatch.sh` blockiert Runs bei Source-/Metadata-Konflikten (unmerged entries, Merge-Marker, Marker-Mismatch im Changelog) und schreibt den Fehlschlag ins Audit.

## Exit-Code-Konvention

Einheitliche Exit-Codes fuer Wrapper/Lifecycle-Fehlerfaelle:

- `2` = Usage / falsche Argumente
- `3` = Contract-Verletzung (Agent/Script/Schema)
- `4` = Policy-Block (`policy lint` fehlgeschlagen)
- `5` = Freeze-Block (z. B. Canary-Promotion bei aktivem Incident Freeze)
- `6` = Fehlende Executable / fehlender Entry-Wrapper

Diese Codes sind in den zentralen Wrappers (`scripts/skill-forge`, `scripts/skills`) und im Dispatcher verankert.

## Memory und Identitaet

Damit der Agent den von Tobias gebauten Skill-Manager in Chat-Kontexten sicher wiedererkennt, muss die Information in den persistenten Agent-Dateien stehen:

- Long-Term Memory: `~/agent/MEMORY.md`
- Daily Memory: `~/agent/memory/YYYY-MM-DD.md`
- User-Profil (immer geladen): `~/agent/USER.md`

Namensregel:

- System-Identitaet ist **OpenClaw**.
- `Nanobot` ist nur der aktuelle Telegram-Anzeigename und kann geaendert werden.

Telegram-Check (Sollverhalten):

- Frage: "erkennst du den skill manager den ich fuer dich gebaut hab"
- Erwartung: positive Erkennung inkl. Referenz auf
	- `~/agent/skills/skill-forge`
	- `~/scripts/skill-forge`

## Kernbefehle

### Status und Governance

```bash
~/scripts/skill-forge status
~/scripts/skill-forge policy lint
~/scripts/skill-forge lint shell --changed
~/scripts/skill-forge policy show
~/scripts/skill-forge health
~/scripts/skill-forge budget
~/scripts/skill-forge audit --rejected
~/scripts/skill-forge audit --top-failures
~/scripts/skill-forge audit --blocked-promotions
~/scripts/skill-forge audit --frequent-rejects
~/scripts/skill-forge audit --ebusy-baseline 24
~/scripts/skill-forge orchestrate --vet-score 70
```

### Discovery / Vetting

Scout laeuft als eigenstaendiger Skill — direkte Nutzung ueber `~/scripts/skills scout`:

```bash
# Scout (direkt, bevorzugt)
~/scripts/skills scout --dry-run [--json]
~/scripts/skills scout --live [N] [--json] [--semantic]
~/scripts/skills scout --summary [--json]
~/scripts/skills scout --add <slug> <source> <version>
~/scripts/skills scout --apply-suggestions [--dry-run]

# Scout via skill-forge Wrapper (delegiert an skills scout)
~/scripts/skill-forge scout --dry-run
~/scripts/skill-forge scout --live 20
~/scripts/skill-forge scout --add <slug> <source> <version>
```

Scout-Skill-Pfade:
- Dispatch: `~/agent/skills/scout/scripts/scout-dispatch.sh`
- Hub-Konfiguration (konfigurierbar, nicht hardcoded): `~/agent/skills/scout/config/hubs.json`
- Curator-Vorschlaege: `~/agent/skills/scout/.state/curator-suggestions.json`
- Agenten-Rollen: `scout-analyst` (Relevanz-Scoring), `scout-curator` (lernt Suchbegriffe)

```bash
~/scripts/skill-forge vet <slug> <score>
~/scripts/skill-forge vet <slug> <score> --file <path>
~/scripts/skill-forge vet <slug> <score> --semantic
~/scripts/skill-forge conflict-check <slug>
~/scripts/skill-forge review <slug>
~/scripts/skill-forge test vetting
~/scripts/skill-forge test resilience
~/scripts/skill-forge test wrappers
```

### Install / Update / Rollback

```bash
~/scripts/skill-forge install <slug> <source> <version> <score>
~/scripts/skill-forge update <slug>
~/scripts/skill-forge update <slug> --changelog "delta ..."
~/scripts/skill-forge update --all
~/scripts/skill-forge update --dry-run
~/scripts/skill-forge rollback <slug>
~/scripts/skill-forge rollback <slug> --list
~/scripts/skill-forge reaper --dry-run
```

Update-Flow-Hinweis:
- `update.sh` fuehrt Re-Vetting vor der finalen Aktivierung aus (kein kurzzeitiges `active` mehr vor Vetting-Entscheid)

### Blacklist und Incident

```bash
~/scripts/skill-forge blacklist add skill <slug> <reason>
~/scripts/skill-forge blacklist add creator <id> <reason>
~/scripts/skill-forge blacklist list
~/scripts/skill-forge blacklist remove skill <slug>
~/scripts/skill-forge blacklist promote
~/scripts/skill-forge incident freeze on
~/scripts/skill-forge incident freeze status
~/scripts/skill-forge incident freeze off
```

Hinweis:
- Der Orchestrator fuehrt automatisch `incident-freeze auto-check` aus.
- Bei zu vielen `pending-blacklist`-Faellen derselben Quelle in 24h kann Freeze automatisch aktiviert werden (Policy-gesteuert).

### Authoring / Writer / Canary

```bash
~/scripts/skill-forge author skill <name> --mode auto --reason "<goal>"
~/scripts/skill-forge author queue
~/scripts/skill-forge author approve <job-id>

~/scripts/skill-forge writer docs "<task>"
~/scripts/skill-forge writer code "<task>"
~/scripts/skill-forge writer config "<task>"
~/scripts/skill-forge writer test "<task>"

~/scripts/skill-forge canary start <slug> 24
~/scripts/skill-forge canary status <slug>
~/scripts/skill-forge canary evaluate <slug>
~/scripts/skill-forge canary promote <slug>
~/scripts/skill-forge canary promote <slug> --emergency --reason "<begruendung>"
~/scripts/skill-forge canary fail <slug>
```

Authoring-Pipeline:
- `author-skill.sh` ist ein Thin-Wrapper
- ruft intern `~/scripts/skills authoring ...` auf
- Implementierung liegt in `~/agent/skills/authoring/scripts/authoring-dispatch.sh`
- Name wird vor der Erzeugung zu einem slug normalisiert (`Sample Skill` → `sample-skill`); normalisierte Kollisionen gegen bestehende Skill-Verzeichnisse und `known-skills.json` werden abgelehnt
- Draft-Erzeugung legt direkt ein minimales Skeleton an: `SKILL.md`, `agents/`, `scripts/<slug>-dispatch.sh`, `contracts/default.output.schema.json`, `references/AUTHORING.md`
- Queue + `known-skills.json` speichern Authoring-Metadaten mit `slug`, `quality_score`, `quality_tier` und `authoring_mode`
- Draft-Erzeugung bleibt `status=drafted` und geht danach durch Vetting/Canary wie bisher

Writer-Pipeline (ab coding-skill v1):
- `writer.sh` ist ein Thin-Wrapper der `~/scripts/skills coding ...` aufruft
- Pipeline: Planner → Coder → Reviewer (Security-/Policy-Check)
- Reviewer Go → `status=completed`, Artefakt direkt verwendbar
- Reviewer No-Go → `status=pending-review`, Artefakt bleibt in `generated/`, steges genehmigt manuell
- Felder in `writer-jobs.json`: `reviewed: bool`, `review_verdict: pass|fail:<grund>`

Wrapper-Nutzung statt Skill-Duplikate:

- `writer` bleibt Entry-Point und nutzt denselben Domain-Pfad wie standalone (`~/scripts/skills coding ...`)
- gleiche Code-Erzeugungslogik fuer `code|docs|config|test`, gesteuert ueber Artefakt-Typ
- keine separaten Copy-Skills nur fuer leicht andere Prompt-Varianten

Vetting-Erweiterung:

- `vet.sh` bleibt deterministischer Default
- mit `--semantic` wird zusaetzlich der Vetting-Skill zugeschaltet (standalone: `~/scripts/skills vetting ...`)
- Ergebnis: gleicher Vetting-Flow, aber mit optionaler semantischer Zweitmeinung

Canary-Erweiterung:

- `canary evaluate <slug>` nutzt den read-only Canary-Skill (standalone: `~/scripts/skills canary evaluate ...`)
- Evaluator + Approver liefern `Go|No-Go|Extend` inkl. `freeze_enabled`, ohne State zu schreiben
- Canary-Kriterien sind versioniert und pro Skill übersteuerbar in `agent/skills/skill-forge/policy/canary-criteria.yaml` (`default` + `skills.<slug>`)
- Promotion/Fail bleibt weiterhin explizit in `canary.sh`
- `canary promote <slug>` schreibt Evaluations-Begruendung (`verdict`, `confidence`, `rationale`) nur bei erfolgreicher Evaluationsantwort ins Audit-Log

Canary-Gates:
- Promotion ist blockiert, wenn `incident freeze` aktiv ist.
- Promotion ist nur aus `running`-Canary erlaubt.
- Promotion ist erst nach `hard_min_hours` (aktuell 24h) erlaubt.
- Ausnahme nur per `--emergency --reason "..."`.
- Install startet Canary, aber promoted nicht mehr sofort automatisch.

### Learn / Memory / Profile / Provenance / Heartbeat

```bash
~/scripts/skills learn observe "<text>" [--tags a,b]
~/scripts/skills learn show [--tag x] [--since 7d] [--json]
~/scripts/skills learn search "<q>" [--json]
~/scripts/skills learn weekly [--json]
~/scripts/skills learn promote <id>
~/scripts/skills learn extract <id>

~/scripts/skills memory remember "<text>" [--cat decision|pattern|config|incident|fact] [--tags x,y] [--actor <actor>]
~/scripts/skills memory recall [--cat x] [--tag y] [--since 30d] [--json]
~/scripts/skills memory search "<query>" [--json]
~/scripts/skills memory forget <id>
~/scripts/skills memory update <id> "<new text>"
~/scripts/skills memory ingest
~/scripts/skills memory stats [--json]

~/scripts/skill-forge profile show
~/scripts/skill-forge profile add <keyword>
~/scripts/skill-forge profile reset

~/scripts/skill-forge provenance <slug>
~/scripts/skill-forge provenance write <slug> <source> <url> <fingerprint> <score> <tier> <version>

~/scripts/skill-forge heartbeat
~/scripts/skill-forge heartbeat --live 15 70
~/scripts/skill-forge dispatch scout ~/agent/skills/skill-forge/scripts/scout.sh --summary
~/scripts/skill-forge metrics latest
~/scripts/skill-forge metrics weekly
~/scripts/skill-forge metrics install-success
~/scripts/skill-forge metrics risk-report   # Risiko-Score je Skill (reject/rollback/tier)
```

Retry-Strategie fuer Install-Fehler:
- Siehe `docs/skills/skill-install-retry-strategy.md` (network vs policy vs hash-mismatch)

Heartbeat Telegram-Status:
- `heartbeat.sh` sendet nach jedem Lauf eine kompakte Telegram-Zusammenfassung (dry/live, orchestrate-Status, Freeze/Pending/Canary, Metrics-Auszug).
- Snapshot-Felder trennen Status und Queue explizit: `pending_blacklist_status` (Skills im Status) und `pending_blacklist_queue` (Queue-Laenge).
- Nachricht ist logisch in drei Ebenen gegliedert: System Jetzt, Vergangenes (24h Audit-Digest), Trend vs. 7-Tage-Mittel.
- NVMe-SMART wird zusaetzlich woechentlich im Heartbeat geprueft (via `smartctl -a /dev/nvme0n1`) und als kompakte Zeile in "System Jetzt" ausgegeben.
- Shell-Regressionstests (`scripts/tests/health-check.bats`, `scripts/tests/backup.bats`) laufen zusaetzlich woechentlich im Heartbeat via `bats`; Ergebnis wird im Audit protokolliert.
- Scout laeuft zusaetzlich woechentlich als `scout --dry-run 5`; der Heartbeat meldet `pending-review` Kandidaten in der Statuszeile und schreibt Audit/Action-Log.
- Gefundene Kandidaten mit `scout_score > 7` werden im selben Weekly-Run automatisch in Vetting ueberfuehrt (aktueller Lauf zaehlt als `auto_vetted=<n>` in Audit/Action-Log).
- Growbox Tagesbericht wird taeglich um 20:00 (Europe/Berlin) ueber den Heartbeat angestossen (`growbox-daily-report.sh`) und per Telegram versendet, wenn Bot-Token/Chat-ID vorhanden sind.
- Voraussetzungen in `.env`: `TELEGRAM_BOT_TOKEN` und `TELEGRAM_CHAT_ID`.
- Wenn `TELEGRAM_CHAT_ID` fehlt, versucht der Heartbeat die letzte Chat-ID via `getUpdates` automatisch zu ermitteln.
- Ohne gueltigen Token oder ohne verwertbare Bot-Updates wird der Heartbeat normal ausgefuehrt, aber Telegram wird mit Hinweis uebersprungen.
- `TELEGRAM_CHAT_ID` ermitteln (nach einer Nachricht an den Bot): `curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getUpdates" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'][-1]['message']['chat']['id'])"`

Dispatch-Hinweis:
- `dispatch` fuehrt nur Agent->Script-Kombinationen aus, die in `agent-contracts.json` freigegeben sind.
- Nicht erlaubte Kombinationen werden als `Contract violation` blockiert.

Core-Konventionen:
- Gemeinsame Rollen-/Output-Regeln liegen in `~/agent/skills/core/AGENTS.md` und `~/agent/skills/core/ROLES.md`.
- Neue Skills richten sich zuerst nach diesen Konventionen, dann nach skill-spezifischen Regeln.

## Wrapper-Parity Regression (lokal)

Ziel: sicherstellen, dass `skill-forge`-Wrapper und direkte Domain-Wrapper bei identischem Input dasselbe Domain-Ergebnis liefern.

Aktueller Pflicht-Check (canary evaluate):

```bash
~/scripts/skill-forge canary evaluate resilience-check --json > /tmp/sm_canary.json
~/scripts/skills canary evaluate resilience-check --json > /tmp/skills_canary.json
diff -u /tmp/sm_canary.json /tmp/skills_canary.json
```

Erwartung:
- Beide Kommandos Exit-Code `0`.
- `diff` ist leer (Output-Parity vorhanden).

Automatisierter Sammeltest:

```bash
~/scripts/skill-forge test wrappers
```

Dieser Test deckt drei Contracts ab:
- Exit-Code-Paritaet fuer ungueltige Wrapper-Aufrufe.
- JSON-Output-Paritaet fuer `canary evaluate ... --json` ueber beide Wrapper.
- Dispatcher-Erreichbarkeit mit JSON-Output-Validierung (`dispatch scout ... --summary --json`).

## Daily Runbook

```bash
~/scripts/skill-forge policy lint
~/scripts/skill-forge heartbeat
~/scripts/skill-forge status
```

Vollautomatischer Pipeline-Lauf:

```bash
~/scripts/skill-forge orchestrate --live 15 --vet-score 70
```

Orchestrator-Gates:

- `policy lint` muss erfolgreich sein
- `test vetting` muss erfolgreich sein

Shell-Lint-Standard:
- Profil: `/.shellcheckrc` im Repo-Root
- Pflichtlauf fuer geaenderte Shell-Skripte: `~/scripts/skill-forge lint shell --changed`
- Fallback: wenn `shellcheck` lokal fehlt, nutzt der Runner automatisch `koalaman/shellcheck-alpine` via Docker
- `policy lint` prueft zusaetzlich Agent-MD Dateien (`*/agents/*.md`, `*/AGENTS.md`) auf verbotene State-Write-Befehlsmuster (Redirection/`tee` in `.state`-JSON Dateien)
- Source-Trust-Tier beeinflusst Vetting-Score
- Konfliktcheck blockiert direkte Promotion und laesst Skill in Canary
- incident-freeze auto-check laeuft nach Vetting

Optional Security Add-on:

```bash
~/scripts/skill-forge audit --rejected
~/scripts/skill-forge blacklist promote
```

OpenClaw Config-Write Guard (Race-Condition-Schutz):

- Host-seitiger Guard: `~/scripts/openclaw-config-guard.sh`
- Erzwingt exklusive Lock-Datei (`infra/openclaw-data/openclaw-config-write.lock`) fuer schreibende OpenClaw-Config-Operationen
- Retry bei `EBUSY` (`run -- <cmd...>`), inklusive Convenience-Wrapper: `login-github-copilot`
- EBUSY-Messung aus `infra/openclaw-data/logs/config-audit.jsonl`:

```bash
~/scripts/openclaw-config-guard.sh ebusy-rate 720
~/scripts/openclaw-config-guard.sh compare 168 24
```

RAG CLI-Standardisierung:

- Neuer Domain-Einstieg: `~/scripts/skills rag ...`
- `retrieve` und `reindex` nutzen einheitliche Timeout-Optionen und Fallbacks.

```bash
~/scripts/skills rag retrieve "heartbeat status" --limit 5 --timeout-ms 1500 --json
~/scripts/skills rag reindex --changed-only --timeout-seconds 600 --json
```

RAG Timeout/Fallback Verhalten:

- `retrieve.py` versucht zuerst FTS, danach LIKE-Fallback.
- Bei leerem/fehlerhaftem Primärindex wird der neueste Snapshot unter `infra/openclaw-data/rag/snapshots/index.db.*` als Fallback genutzt.
- Antwort enthält Metadaten: `search_mode`, `db_used`, `fallback_used`, `timeout_ms`, `warning`.
- Deutsche Query-Rewrites werden beim Keyword-Expand angewendet (z. B. `ausfall`, `wiederherstellung`, `tagebuch`, `dienste`).
- Neue Growbox-Diary-Quellen erhalten im Reranking einen Recency-Boost, damit aktuelle Tageskontexte vor älteren Diary-Eintraegen landen.
- `reindex.sh` nutzt konfigurierbares Timeout (`RAG_REINDEX_TIMEOUT_SECONDS`, default 600) und führt bei Integritätsfehlern (`PRAGMA quick_check`) Snapshot-Restore-Fallback aus.

RAG Gold-Set / Qualitaetsmessung:

```bash
python3 ~/agent/skills/openclaw-rag/scripts/evaluate-goldset.py --limit 5 --timeout-ms 1500
```

- Gold-Set Datei: `agent/skills/openclaw-rag/GOLD-SET.json`
- Referenzmessung vom 2026-04-06: `avg Precision@5=0.32`, `avg Recall@5=0.625`, `p95=70.28ms`

Shared Argument Parser:

- `scripts/lib/common-flag-parser.sh` vereinheitlicht wiederkehrende Flags (`--json`, `--dry-run`, `--reason`).
- Eingebunden in `scripts/skills` und `scripts/skill-forge` für konsistente Flag-Weitergabe.

## Troubleshooting

### Policy lint schlägt fehl

1. `~/scripts/skill-forge policy show`
2. YAML in `~/agent/skills/skill-forge/policy/` korrigieren
3. `~/scripts/skill-forge policy lint` erneut ausfuehren

### Incident freeze bleibt aktiv

1. `~/scripts/skill-forge incident freeze status`
2. `~/scripts/skill-forge audit --rejected`
3. Nach Review: `~/scripts/skill-forge incident freeze off`

### Provenance fehlt

1. `~/scripts/skill-forge provenance <slug>`
2. Falls leer: `~/scripts/skill-forge provenance write ...`

### Canary bleibt haengen

1. `~/scripts/skill-forge canary status <slug>`
2. Erfolgsfall: `~/scripts/skill-forge canary promote <slug>`
3. Fehlerfall: `~/scripts/skill-forge canary fail <slug>`
