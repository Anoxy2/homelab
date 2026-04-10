# Core — Shared Role Contracts

Verbindliche Rollendefinitionen für alle Agents im Skill-Manager-Ökosystem.

---

## Allgemeine Grundregeln (gelten für alle Agents)

1. **Kein Zustandsschreiben außerhalb des zugewiesenen Scopes** — Jeder Agent darf nur die Dateien schreiben, die explizit in seinem Scope-Abschnitt definiert sind.
2. **Read vor Write** — Vor jeder Zustandsänderung muss der aktuelle Zustand gelesen werden.
3. **JSON-Output ist kanonisch** — Bei `--json`-Flag immer valides JSON, kein gemischtes Text/JSON.
4. **Kein Abbruch ohne Audit** — Fehler, die zu einem Non-Zero-Exit führen, müssen einen `log_audit`-Eintrag hinterlassen.
5. **Keine Secrets in Outputs** — Credentials, Tokens und Passwörter dürfen niemals in Logs, Outputs oder Canvases erscheinen.

---

## Rollen-Übersicht

| Role | Pipeline | Scope |
|------|----------|-------|
| `orchestrator` | Orchestrate-Loop | known-skills.json (read), canary.json (read) |
| `scout` | Skill-Discovery | scout-results.json (write) |
| `vetter` | Vetting-Score | known-skills.json (write: score only) |
| `vetting-analyst` | Semantisches Vetting | vetter-report.json (write: semantic_review) |
| `vetting-reviewer` | Vetting-Entscheidung | Output-only, kein State-Write |
| `author` | Skill-Authoring | author-queue.json (write) |
| `planner` | Coding-Pipeline | plan.json (write, transient) |
| `coder` | Coding-Pipeline | writer-jobs.json (write) |
| `reviewer` | Coding-Pipeline | writer-jobs.json (write: review_verdict) |
| `canary-evaluator` | Canary-Evaluation | Output-only, read-only |
| `canary-approver` | Canary-Approval | Output-only, kein State-Write |
| `doc.keeper` | Dokumentations-Sync | *.md in docs/ (write) |
| `writer` | Artefakt-Erzeugung | writer-jobs.json (write) |

---

## Ausgabe-Verträge

Alle Agents MÜSSEN sich an die Schema-Datei im `contracts/`-Verzeichnis ihres Skills halten.

```
agent/skills/<skill>/contracts/<agent-name>.output.schema.json
```

Schema-Verletzungen werden vom `dispatcher.sh` mit einem `SCHEMA-VIOLATION`-Audit-Eintrag abgelehnt.

---

## Staged vs. Active Mode

| Mode | Bedeutung |
|------|-----------|
| `active` | Agent wird automatisch im Orchestrate-Loop aktiviert |
| `staged` | Agent wird nur manuell oder durch expliziten Dispatch aufgerufen |
| `disabled` | Agent ist deaktiviert, kein Dispatch möglich |

Alle neuen Agents starten als `staged`. Promotion zu `active` erfordert eine positiv abgeschlossene Canary-Phase.
