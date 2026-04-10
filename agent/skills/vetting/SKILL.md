---
name: vetting
description: Erweitert vet.sh um semantische Agent-Analyse. Aktiviert mit --semantic Flag. Zwei Rollen: vetting-analyst (liest SKILL.md, gibt Score-Delta) + vetting-reviewer (PASS/REVIEW/REJECT auf Basis von vet.sh-Report + Analyst-Delta).
---

# vetting

## Zweck

Ergänzt den deterministischen `vet.sh`-Scan um eine semantische Analyse-Schicht. Wird nur aktiviert wenn `--semantic` explizit übergeben wird — der deterministische Pfad bleibt Default.

## Wann nutzen

```bash
# Deterministisch (default, kein Umbau):
~/scripts/skill-forge vet <slug> <score>

# Mit semantischer Erweiterung (opt-in):
~/scripts/skill-forge vet <slug> <score> --semantic

# Standalone-Vetting-Skill:
~/scripts/skills vetting <slug> [--json]
```

## Pipeline

```
vet.sh (deterministisch) → vetting-dispatch.sh → vetting-analyst → vetting-reviewer
```

1. `vet.sh` läuft normal und schreibt vorläufigen Report in `.state/vetter-reports/<slug>.json`
2. `vetting-dispatch.sh` liest den Report, liest SKILL.md des Skills, ruft vetting-analyst auf
3. **vetting-analyst** gibt `semantic_delta` (-20..+10) + Flags + Rationale als JSON
4. **vetting-reviewer** bekommt vet.sh-Report + Analyst-Delta → PASS/REVIEW/REJECT
5. `vetting-dispatch.sh` updated den Report mit `semantic_review`-Feld

## Agenten-Rollen

| Agent | Aufgabe | State-Write |
|-------|---------|------------|
| vetting-analyst | Semantischer Score-Delta aus SKILL.md-Analyse | Nein |
| vetting-reviewer | Finale Go/No-Go-Entscheidung | Nein |

`vetting-dispatch.sh` ist der einzige State-Writer.

## Ergebnis im vetter-report

Report enthält nach `--semantic`-Durchlauf zusätzlich:

```json
{
  "semantic_review": {
    "analyst_delta": -10,
    "analyst_flags": ["purpose-mismatch"],
    "analyst_rationale": "...",
    "reviewer_verdict": "REVIEW",
    "reviewer_rationale": "..."
  }
}
```

## Integration mit orchestrate.sh

`orchestrate.sh` bleibt unverändert — kein `--semantic` im Default-Orchestrate-Pfad.

## Scope-Grenzen

- Kein Agenten-Write in `known-skills.json` oder `pending-blacklist.json`
- Kein Überschreiben von `vet.sh`-Hard-Gates (EXTREME → immer pending-blacklist)
- Kein Zugriff auf `.env`, `secrets.yaml`

## Referenzen

- [vetting-criteria.md](references/vetting-criteria.md) — Risiko-Erkennungsregeln für den Analyst
