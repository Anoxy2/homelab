---
name: runbook-maintenance
description: Weekly maintenance runbook checks, checklist output, and failover runbook routing
---

# runbook-maintenance

## Purpose
Stellt einen wartbaren Maintenance-Workflow bereit:
- woechentliche Gesundheits-Checks mit klaren Exit-Codes
- standardisierte Maintenance-Checkliste fuer den Betrieb
- schnelles Routing auf passende Failover-Runbooks

## Trigger
Nutzen, wenn nach folgenden Aufgaben gefragt wird:
- woechentliche Ops-/Maintenance-Pruefungen
- strukturierte Reihenfolge fuer Routine-Wartung
- passende Runbook-Auswahl bei Stoerfall/Failover

## Steps
1. `weekly-check`: Fuehrt Kernchecks sequenziell mit Per-Task-Timeout aus.
2. `checklist`: Liefert die verbindliche Reihenfolge inkl. erwarteter Dauer.
3. `failover <scenario>`: Verweist auf das passende Stoerungs-Runbook.

## Commands
- `~/scripts/skills runbook-maintenance weekly-check [--json]`
- `~/scripts/skills runbook-maintenance checklist [--json]`
- `~/scripts/skills runbook-maintenance failover <openclaw|pihole-dns|esp32|rag> [--json]`

## Outputs
- Human-readable Zusammenfassung fuer Shell/Chat
- Optional JSON fuer Automatisierung (`--json`)
- Exit-Code `1`, wenn im weekly-check mindestens ein Task fehlschlaegt/timeoutet

## Boundaries
- No secrets in output.
- Respect incident freeze and policy gates.
- Keine destruktiven Eingriffe (kein restart/rollback im Dispatcher selbst).
