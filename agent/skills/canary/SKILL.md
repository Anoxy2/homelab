---
name: canary
description: Semantische Canary-Evaluation via Evaluator→Approver-Pipeline. Trigger: canary evaluate <slug>. Read-only — kein Zustandsschreiben. Liefert Empfehlung promote|extend|fail + Go/No-Go Verdict.
---

# Canary — Evaluations-Skill

## Zweck

Dieser Skill analysiert laufende Canary-Deployments semantisch und liefert
eine strukturierte Empfehlung (`promote | extend | fail`) auf Basis von
Audit-Log-Einträgen, Canary-Zustand und Rollout-Policy.

**Alle Operationen sind read-only.** Der Skill schreibt keinen Zustand.
Die eigentliche Promote/Fail-Entscheidung trifft weiterhin `canary.sh` via
`skill-forge canary promote|fail <slug>`.

## Trigger

```
~/scripts/skill-forge canary evaluate <slug>
~/scripts/skills canary evaluate <slug>
```

Nur für Skills mit `status: canary` in `known-skills.json` sinnvoll.

## Pipeline

```
canary-dispatch.sh evaluate <slug>
    │
    ├─ canary-evaluator   (liest canary.json + audit-log + rollout-policy.yaml)
    │    └─ output: { slug, recommendation, confidence, evidence[] }
    │
    └─ canary-approver    (bewertet Empfehlung; kein Zustandsschreiben)
         └─ output: { slug, verdict: Go|No-Go|Extend, rationale }
```

## Scope-Grenzen

| Erlaubt | Verboten |
|---------|----------|
| Lesen von canary.json | Schreiben in canary.json |
| Lesen des Audit-Logs | `canary promote` oder `canary fail` ausführen |
| Ausgabe von Empfehlungen | Direkte Statusänderungen |
| Lesen von known-skills.json | Modifikation von known-skills.json |

## Rollout-Policy (Soft Binding)

Werte aus `policy/rollout-policy.yaml` — abgerufen zur Laufzeit:

| Parameter | Wert | Bedeutung |
|-----------|------|-----------|
| `window_hours` | 24 | Standard-Canary-Fenster in Stunden |
| `max_triggers_per_day` | 5 | Max. Audit-Events vor Eskalation |
| `require_no_high_or_extreme_events` | true | EXTREME/HIGH-Events bedeuten No-Go |
| `require_no_trigger_conflict` | true | Konflikt-Events bedeuten No-Go |

Versionierte Kriterien pro Skill:

- Datei: `~/agent/skills/skill-forge/policy/canary-criteria.yaml`
- `default` definiert Baseline fuer alle Skills
- `skills.<slug>` kann `window_hours`, `hard_min_hours`, `max_triggers_per_day` und Guards pro Skill ueberschreiben

## Ausgabe-Format

canary-approver gibt aus:

```json
{
  "slug": "<slug>",
  "verdict": "Go|No-Go|Extend",
  "rationale": "...",
  "evaluator_recommendation": "promote|extend|fail",
  "confidence": 80
}
```
