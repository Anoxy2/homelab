---
name: metrics
description: Zeichnet Orchestrate-Lauf-Metriken auf und liefert Latest/Weekly-Reports. Deterministisch, kein LLM-Aufruf. State in skill-forge/.state/metrics.jsonl.
---

# metrics

## Zweck

Erfasst nach jedem Orchestrate-Lauf quantitative Metriken (Install-Success-Rate, Rollback-Rate, Decision-Time) und stellt wöchentliche Aggregationen bereit.

## Wann nutzen

```bash
~/scripts/skills metrics record <run_id> <live:0|1> <vet_score> <duration_ms>
~/scripts/skills metrics weekly
~/scripts/skills metrics latest
~/scripts/skills metrics install-success
```

## Scope-Grenzen

| Erlaubt | Verboten |
|---------|----------|
| Lesen von known-skills.json, audit-log.jsonl | Änderungen an known-skills.json |
| Schreiben in metrics.jsonl, metrics-weekly.json | Lifecycle-Operationen |
