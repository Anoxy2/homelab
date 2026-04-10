#!/bin/bash
# health.sh — Thin Wrapper (delegiert an den eigenständigen Health-Skill)
# Alle Logik liegt in: ~/agent/skills/health/scripts/health-dispatch.sh
# Direkte Nutzung: ~/scripts/skills health report|budget

set -euo pipefail

HEALTH_DISPATCH="/home/steges/agent/skills/health/scripts/health-dispatch.sh"

if [[ ! -x "$HEALTH_DISPATCH" ]]; then
  echo "health.sh: Health-Skill nicht gefunden: $HEALTH_DISPATCH" >&2
  exit 6
fi

exec "$HEALTH_DISPATCH" "$@"
