# Output-Formate — coding skill

## writer-jobs.json Schema

Jeder Writer-Job wird in `agent/skills/skill-forge/.state/writer-jobs.json` eingetragen.

```json
{
  "id": "writer-<unix-timestamp>-<4stellige-hash>",
  "type": "code|config|docs|test",
  "task": "<original task text>",
  "path": "<absoluter Pfad zur generierten Datei>",
  "envelope_path": "<absoluter Pfad zum Envelope-JSON>",
  "schema_version": "1",
  "status": "completed|pending-review",
  "reviewed": true,
  "review_verdict": "pass|fail:<grund>",
  "created_at": "2026-04-04T15:00:00Z"
}
```

### Neue Felder (ab coding-skill v1)

| Feld | Typ | Bedeutung |
|------|-----|-----------|
| `reviewed` | bool | War das Artefakt im Reviewer-Durchlauf (immer true wenn code-dispatch.sh gelaufen) |
| `review_verdict` | string | `pass` = Go; `fail:<grund>` = No-Go |
| `status` | string | `completed` = bereit; `pending-review` = steges muss freigeben |

## Envelope-Schema

Jedes Artefakt bekommt ein Envelope-JSON in `generated/envelopes/<slug>.json`:

```json
{
  "intent": "Generate <kind> artifact for task",
  "triggers": ["<task text>"],
  "workflow_steps": ["collect-context", "generate-artifact", "verify-result"],
  "exclusions": ["secrets", "destructive-commands"],
  "risk_notes": "Generated artifact requires review before production use."
}
```

## Artefakt-Pfade

| kind   | Pfad |
|--------|------|
| code   | `agent/skills/skill-forge/generated/code/<slug>.sh` |
| config | `agent/skills/skill-forge/generated/config/<slug>.yaml` |
| docs   | `agent/skills/skill-forge/generated/docs/<slug>.md` |
| test   | `agent/skills/skill-forge/generated/test/<slug>.sh` |
| envelope | `agent/skills/skill-forge/generated/envelopes/<slug>.json` |

## Audit-Log-Format

Jeder Writer-Job schreibt einen Eintrag ins Audit-Log:

```
CODING | <kind> | job=<job-id> path=<pfad> status=<status> verdict=<verdict>
```

Beispiele:
```
CODING | code | job=writer-1712345678-4231 path=generated/code/healthcheck.sh status=completed verdict=pass
CODING | code | job=writer-1712345679-9012 path=generated/code/deploy.sh status=pending-review verdict=fail:hardcoded-credential
```

## Job-Status-Übergänge

```
(erzeugt) → completed    # Reviewer: Go
(erzeugt) → pending-review  # Reviewer: No-Go

pending-review → (manuell gelöscht)      # steges löscht nach Review
pending-review → (manuell umbenannt/übernommen)  # steges übernimmt nach Fix
```

Es gibt keinen automatischen Übergang von `pending-review` zu `completed` — das ist bewusst.

## Output-Contract (coding.output.schema.json)

Das Dispatcher-Framework validiert den Output von `code-dispatch.sh` gegen:

```
agent/skills/coding/contracts/coding.output.schema.json
```

Pflichtfelder: `job_id`, `path`, `status`, `review_verdict`
