#!/bin/bash
# budget.sh — Thin Wrapper (delegiert an health-dispatch.sh budget)
# Alle Logik liegt in: ~/agent/skills/health/scripts/health-dispatch.sh
# Direkte Nutzung: ~/scripts/skills health budget

set -euo pipefail

HEALTH_DISPATCH="/home/steges/agent/skills/health/scripts/health-dispatch.sh"

if [[ ! -x "$HEALTH_DISPATCH" ]]; then
  echo "budget.sh: Health-Skill nicht gefunden: $HEALTH_DISPATCH" >&2
  exit 6
fi

exec "$HEALTH_DISPATCH" budget "$@"
