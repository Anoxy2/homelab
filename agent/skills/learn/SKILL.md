---
name: learn
description: Verwaltet gesammelte Learnings aus dem Systembetrieb. Zeigt, fördert und extrahiert Erkenntnisse als neue Skill-Drafts.
---

# learn

## Zweck

Hält `~/.learnings/LEARNINGS.md` als lebendiges Log von Beobachtungen und Erkenntnissen aus dem laufenden Betrieb. Learnings können als Basis für neue Skills extrahiert werden.

## Wann nutzen

```bash
~/scripts/skills learn show
~/scripts/skills learn weekly [--json]
~/scripts/skills learn promote <id>
~/scripts/skills learn extract <id>
```

## Pipeline

- `weekly` verdichtet die letzten 7 Tage aus Audit-Log, Action-Log, Pending-Review-Backlog und Risk-Report zu konkreten LEARNINGS-Eintraegen mit IDs
- `extract` delegiert an `~/scripts/skill-forge author ...` (Lifecycle bleibt im Manager)

## Scope-Grenzen

| Erlaubt | Verboten |
|---------|----------|
| Lesen + Anhängen in .learnings/LEARNINGS.md | Direkte Skill-Status-Änderungen |
| Delegieren an authoring via skill-forge | Schreiben in State-Dateien des Managers |
