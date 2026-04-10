---
name: health
description: Skill-Health-Report (Status-Scores pro Skill) und Budget-Check (aktive Skills vs. Limits). Deterministisch, read-only gegenüber known-skills.json.
---

# health

## Zweck

Gibt einen schnellen Überblick über den Gesundheitszustand aller Skills und prüft ob das System innerhalb der konfigurierten Skill-Budget-Grenzen bleibt.

## Wann nutzen

```bash
~/scripts/skills health report    # Skill-by-Skill Score-Übersicht
~/scripts/skills health budget    # Budget-Check (aktive Skills vs. Limit)
```

## Scope-Grenzen

| Erlaubt | Verboten |
|---------|----------|
| Lesen von known-skills.json, canary.json | Schreiben in State-Dateien |
| Lesen von config/limits.yaml | Lifecycle-Operationen |
