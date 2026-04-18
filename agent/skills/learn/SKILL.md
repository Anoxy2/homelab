---
name: learn
description: Verwaltet gesammelte Learnings aus dem Systembetrieb. Zeigt, fördert und extrahiert Erkenntnisse als neue Skill-Drafts.
---

# learn

## Zweck

Haelt Learnings als strukturierten Backing-Store und als lesbare, RAG-faehige Sicht. Beobachtungen koennen sofort erfasst, durchsucht und bei Bedarf als neue Skills extrahiert werden.

## Wann nutzen

```bash
~/scripts/skills learn observe "<text>" [--tags a,b]
~/scripts/skills learn show [--tag x] [--since 7d] [--json]
~/scripts/skills learn search "<keyword>" [--json]
~/scripts/skills learn weekly [--json]
~/scripts/skills learn promote <id>
~/scripts/skills learn extract <id>
```

## Storage

- Backing-Store: `skill-forge/.state/learnings.jsonl` (JSONL, strukturiert)
- Lesbare Sicht: `/home/steges/agent/LEARNINGS.md` (RAG-approved, agent-doc 280/30)
- Weekly-State: `skill-forge/.state/learn-weekly.json`

## Pipeline

- `observe` schreibt sofort in JSONL und ergaenzt `agent/LEARNINGS.md`
- `weekly` verdichtet die letzten 7 Tage aus Audit-Log, Action-Log, Pending-Review-Backlog und Risk-Report
- `promote` markiert vorhandene IDs als promoted im JSONL-Store
- `extract` delegiert an `~/scripts/skill-forge author ...` (Lifecycle bleibt im Manager)

## Scope-Grenzen

| Erlaubt | Verboten |
|---------|----------|
| Lesen + Schreiben in learnings.jsonl und agent/LEARNINGS.md | Direkte Skill-Status-Aenderungen |
| Delegieren an authoring via skill-forge | Schreiben in State-Dateien des Managers |
