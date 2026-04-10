---
name: core
description: Shared role contracts and agent definitions for the skill-forge ecosystem. No dispatch script — provides governance rules and role boundaries used by all other skills.
---

# core

## Purpose
Zentrale Rollendefinitionen und Governance-Regeln für alle Agents im Skill-Manager-Ökosystem.
Kein eigenes Dispatch-Script — dient als Referenz-Basis für Policy-Checks und Agent-Verhalten.

## Inhalt
- `AGENTS.md` — Verbindliche Rollendefinitionen (Scope, Write-Rules, Audit-Pflicht)
- `ROLES.md` — Rollenhierarchie und Zuständigkeitsgrenzen

## Trigger
Nicht direkt aufrufbar. Regeln werden von skill-forge (policy lint), vet.sh und allen Dispatch-Scripts implizit referenziert.
