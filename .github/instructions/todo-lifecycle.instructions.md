---
description: "Use when implementing or closing todos, editing docs/operations/open-work-todo.md, or changing skill-forge scripts/policies. Enforces: implement first, validate, document changes, then remove completed todos."
name: "Todo Lifecycle And Documentation Gate"
applyTo:
  - "**/*todo*.md"
  - "docs/skills/skill-forge-governance.md"
  - "CHANGELOG.md"
  - "scripts/skill-forge"
  - "agent/skills/skill-forge/policy/**/*.yaml"
  - "agent/skills/skill-forge/scripts/**/*.sh"
---
# Todo Lifecycle And Documentation Gate

## Required Order

When completing work items, follow this strict sequence:

1. Implement code/config changes.
2. Validate behavior with relevant checks.
3. Document the new behavior in the appropriate docs.
4. Update changelog when behavior/process changed.
5. Only then update todo tracking.

## Todo List Rule

- Keep todo lists as open-work only across the repository.
- Do not keep completed entries as historical `[x]` items.
- Remove completed items from any `*todo*.md` file after documentation is updated.
- Default and canonical todo file is `docs/operations/open-work-todo.md`.
- Do not create new todo files under `agent/`; `agent/TO-DO.md` is migration-only.

## Validation Rule

For skill-forge lifecycle/policy changes, run at least:

- `/home/steges/scripts/skill-forge policy lint`
- Syntax checks for modified shell scripts (`bash -n ...`)
- One runtime smoke-check command on the changed path

If validation fails, do not remove todo items.

## Documentation Mapping

Use this mapping before removing a todo item:

- Skill-manager lifecycle/ops behavior: `docs/skills/skill-forge-governance.md`
- Process/governance changes: `CHANGELOG.md`
- Service/runtime architecture changes: `docs/core/services-and-ports.md` or `docs/core/system-architecture.md`

If no matching doc exists, create or extend one first.

## Changelog Rule

- Update `CHANGELOG.md` only when behavior or process changed.
- Changelog updates are not required for purely clerical todo edits.

## Emergency Exceptions

If an emergency shortcut is used (for example canary emergency promote), documentation must include:

- why emergency path was needed
- who/what was impacted
- what follow-up action is required
- Documentation in `CHANGELOG.md` plus matching Fachdoku is sufficient (no separate runbook requirement by default).
