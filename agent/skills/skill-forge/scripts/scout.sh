#!/bin/bash
# scout.sh — Thin Wrapper (delegiert an den eigenständigen Scout-Skill)
# Alle Logik liegt in: ~/agent/skills/scout/scripts/scout-dispatch.sh
# Direkte Nutzung: ~/scripts/skills scout ...

set -euo pipefail

SCOUT_DISPATCH="/home/steges/agent/skills/scout/scripts/scout-dispatch.sh"

if [[ ! -x "$SCOUT_DISPATCH" ]]; then
  echo "scout.sh: Scout-Skill nicht gefunden: $SCOUT_DISPATCH" >&2
  exit 6
fi

exec "$SCOUT_DISPATCH" "$@"
