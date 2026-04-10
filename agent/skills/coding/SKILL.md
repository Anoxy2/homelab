---
name: coding
description: Generates real (non-stub) code, config, docs, and test artifacts for the skill-forge. Replaces writer.sh logic with a Planner→Coder→Reviewer pipeline. Use for all artifact generation tasks.
---

# coding

## Zweck

Erzeugt echte Artefakte für den Skill-Manager-Workflow: Shell-Scripts, YAML-Configs, Runbook-Docs, Smoke-Test-Scripts. Kein TODO-Stub mehr — jedes Artefakt hat einen sinnvollen Skeleton.

## Agenten-Pipeline

```
Planner → Coder → Reviewer
```

1. **Planner** — klärt Scope, wählt Artefakttyp, schreibt `plan.json` mit Constraints und Acceptance-Criteria
2. **Coder** — generiert Artefakt gemäß `plan.json` mit typ-spezifischem Pflicht-Preamble, keine Secrets einbetten
3. **Reviewer** — Security- und Policy-Check; Go → `status=completed`; No-Go → `status=pending-review`

## Artefakt-Typen

| kind   | Ausgabe                   | Pflicht-Preamble                        |
|--------|---------------------------|-----------------------------------------|
| code   | `generated/code/<slug>.sh`   | `#!/bin/bash\nset -euo pipefail`       |
| config | `generated/config/<slug>.yaml` | YAML-Header mit name und description  |
| docs   | `generated/docs/<slug>.md`   | Markdown mit Zweck/Schritte/Rollback   |
| test   | `generated/test/<slug>.sh`   | `#!/bin/bash\nset -euo pipefail` + assert-Boilerplate |

## Status-Bedeutungen

| status          | Bedeutung                                                  |
|-----------------|------------------------------------------------------------|
| completed       | Reviewer hat Go gegeben, Artefakt produktionsbereit        |
| pending-review  | Reviewer hat No-Go gegeben, steges muss manuell freigeben  |

## Reviewer No-Go

Wenn der Reviewer ein Problem findet, bleibt das Artefakt in `generated/` mit `status=pending-review` und `review_verdict=fail:<grund>`. Es wird **nicht** gelöscht. steges muss das Artefakt prüfen und manuell freigeben oder löschen.

## Scope-Grenzen

Dieser Skill generiert nur Artefakte. Er schreibt **nicht** in:
- `.env`, `secrets.yaml`, `esphome/config/secrets.yaml`
- `policy/`-Dateien
- `known-skills.json`, `canary.json` oder andere State-Files direkt

## Dispatcher

`code-dispatch.sh` ist der einzige State-Writer dieses Skills.

## Integration mit Skill-Manager

Dieser Skill ist ein intern authored Skill (`source: internal`). Er ist sowohl standalone als auch über den Skill-Manager nutzbar:

```bash
~/scripts/skills coding code|docs|config|test "<task-text>"
```

Im Skill-Manager läuft derselbe Pfad über `writer.sh` als Thin-Wrapper:

```bash
~/scripts/skill-forge writer code|docs|config|test "<task-text>"
```

## Referenzen

- [shell-safety.md](references/shell-safety.md) — Pflicht-Preambles und Forbidden-Patterns
- [output-formats.md](references/output-formats.md) — writer-jobs.json-Schema, Envelope-Schema
- [policy-constraints.md](references/policy-constraints.md) — was niemals erzeugt werden darf
