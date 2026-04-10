---
name: skill-forge
description: Zero-trust lifecycle manager for external skills and generated artifacts in this homelab. Use for scout, vetting, quarantine blacklist, authoring, canary rollout, writer workflows, and provenance tracking.
---

# skill-forge

## Purpose
Manage third-party skills and self-authored artifacts with a deterministic, auditable, and policy-gated lifecycle.

## Architecture Boundary
- `skill-forge` ist der Lifecycle/Governance-Entry (Install/Update/Policy/Canary-Promotion/Audit/Provenance).
- `skills` ist der bevorzugte Domain-Entry fuer fachliche Skill-Nutzung.
- Beide Wrapper muessen auf dieselbe Domain-Implementierung zeigen (keine Logik-Duplikate).

## Principles
- Zero trust for external inputs.
- Deterministic scripts for state changes.
- Agent reasoning only where semantic decisions are needed.
- Every action must be auditable.
- Promotion to active is always gated by policy/canary/freeze.

## Triggers
Use when the user asks to:
- discover new skills
- vet a skill before install
- quarantine or blacklist suspicious skills
- write provenance evidence
- enable freeze mode during incidents
- create a new skill intentionally
- auto-generate docs/code/config/tests through writer workflows

Use proactively when:
- recurring tasks suggest a missing capability
- canary items need promotion or rollback
- pending blacklist entries need promotion checks
- heartbeat detects drift in policy/status health

## Workspace Paths
- Agent workspace: /home/steges/agent
- Skill root: /home/steges/agent/skills
- Skill manager root: /home/steges/agent/skills/skill-forge
- Runtime data: /home/steges/infra/openclaw-data

## Lifecycle States
DISCOVERED -> VETTED -> EXTRACTED -> DRAFTED -> CANARY -> ACTIVE -> LEARNED -> MATURED -> SELF-WRITTEN

Parallel paths:
- EXTREME -> PENDING-BLACKLIST -> BLACKLISTED
- ACTIVE -> ROLLBACK

## Safety Gates
- Policy lint must pass before operational changes.
- Incident freeze blocks promotion to active.
- Canary is required for risky changes and generated skills.
- Vetter is mandatory for external and scratch-generated risky skills.
- Provenance write is required for every promoted artifact.

## Authoring Modes
- template: Use internal template skeleton for known patterns.
- from-tested: Reuse safe structure from already validated internal skill patterns.
- scratch: Full custom generation, treated as highest risk.
- auto: Select mode from context and constraints.

## Writer Modes

Writer-Jobs laufen über den `coding`-Skill mit einer Planner→Coder→Reviewer-Pipeline. Kein TODO-Stub mehr — jedes Artefakt hat einen sinnvollen Skeleton.

- docs: Runbooks, Erklärungen, Operator-Docs (Markdown mit Zweck/Schritte/Rollback)
- code: Scripts/Helpers mit Shell-Safety-Defaults (`set -euo pipefail`, Dependency-Check)
- config: Strukturierte YAML-Drafts mit version-Feld und Kommentar-Header
- test: Smoke- und Validierungs-Scripts mit assert-Boilerplate

Reviewer-No-Go → `status=pending-review`, Artefakt bleibt in `generated/`, steges genehmigt manuell.

## Operational Playbooks

### Daily Safe Run
1. /home/steges/scripts/skill-forge policy lint
2. /home/steges/scripts/skill-forge scout
3. /home/steges/scripts/skill-forge blacklist promote
4. /home/steges/scripts/skill-forge health
5. /home/steges/scripts/skill-forge budget

### Author New Skill
1. /home/steges/scripts/skill-forge author skill <name> --mode auto --reason "<goal>"
2. /home/steges/scripts/skill-forge author queue
3. /home/steges/scripts/skill-forge canary start <name> 24
4. /home/steges/scripts/skill-forge canary promote <name>

### Incident Run
1. /home/steges/scripts/skill-forge incident freeze on
2. /home/steges/scripts/skill-forge audit --rejected
3. /home/steges/scripts/skill-forge incident freeze status
4. /home/steges/scripts/skill-forge incident freeze off (only after manual review)

## Heartbeat Integration
During heartbeat cycles, this skill should be treated as an operations guardrail:
- quick status check each heartbeat window
- policy + blacklist promotion in longer interval windows
- immediate alert if incident freeze is on unexpectedly
- immediate alert if pending blacklist keeps growing across cycles

## Commands
- /home/steges/scripts/skill-forge init
- /home/steges/scripts/skill-forge status
- /home/steges/scripts/skill-forge review <slug>
- /home/steges/scripts/skill-forge install <slug> [source] [version] [score]
- /home/steges/scripts/skill-forge update <slug> [--changelog <text>]|--all|--dry-run
- /home/steges/scripts/skill-forge rollback <slug> [--list]
- /home/steges/scripts/skill-forge profile show|add <keyword>|reset
- /home/steges/scripts/skill-forge policy lint
- /home/steges/scripts/skill-forge policy show
- /home/steges/scripts/skill-forge scout --add <slug> <source> <version>
- /home/steges/scripts/skill-forge scout --dry-run|--live [limit]
- /home/steges/scripts/skill-forge vet <slug> <score> [--file <path>]
- /home/steges/scripts/skill-forge vet <slug> <score> --semantic
- /home/steges/scripts/skill-forge test vetting
- /home/steges/scripts/skill-forge author skill <name> --mode auto|template|from-tested|scratch --reason "<goal>"
- /home/steges/scripts/skill-forge author queue
- /home/steges/scripts/skill-forge author approve <job-id>
- /home/steges/scripts/skill-forge canary start <slug> [hours]
- /home/steges/scripts/skill-forge canary status <slug>
- /home/steges/scripts/skill-forge canary evaluate <slug>
- /home/steges/scripts/skill-forge canary promote <slug>
- /home/steges/scripts/skill-forge canary fail <slug>
- /home/steges/scripts/skill-forge writer docs <task-text>
- /home/steges/scripts/skill-forge writer code <task-text>
- /home/steges/scripts/skill-forge writer config <task-text>
- /home/steges/scripts/skill-forge writer test <task-text>
- /home/steges/scripts/skill-forge shadow on|off|status
- /home/steges/scripts/skill-forge health
- /home/steges/scripts/skill-forge audit [--rejected]
- /home/steges/scripts/skill-forge budget
- /home/steges/scripts/skill-forge blacklist add skill|creator <id> <reason>
- /home/steges/scripts/skill-forge blacklist list
- /home/steges/scripts/skill-forge blacklist remove skill <slug>
- /home/steges/scripts/skill-forge blacklist promote
- /home/steges/scripts/skill-forge learn show|promote <id>|extract <id>
- /home/steges/scripts/skill-forge heartbeat
- /home/steges/scripts/skill-forge orchestrate [--live [limit]] [--vet-score <n>]
- /home/steges/scripts/skill-forge incident freeze on|off|status
- /home/steges/scripts/skill-forge provenance <slug>
- /home/steges/scripts/skill-forge provenance write <slug> <source> <url> <upstream_fingerprint> <score> <tier> <version>

## Standalone Domain Commands
- /home/steges/scripts/skills coding code|docs|config|test <task-text>
- /home/steges/scripts/skills vetting <slug> [--json]
- /home/steges/scripts/skills canary evaluate <slug> [--json]
- /home/steges/scripts/skills authoring <name> [--mode auto|template|from-tested|scratch] [--reason <text>]
