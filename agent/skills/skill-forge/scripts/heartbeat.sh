#!/bin/bash
# heartbeat.sh — Thin Wrapper (delegiert an den eigenständigen Heartbeat-Skill)
# Alle Logik liegt in: ~/agent/skills/heartbeat/scripts/heartbeat-dispatch.sh
# Direkte Nutzung: ~/scripts/skills heartbeat [--live [N] [vet_score]]

set -euo pipefail

HEARTBEAT_DISPATCH="/home/steges/agent/skills/heartbeat/scripts/heartbeat-dispatch.sh"

if [[ ! -x "$HEARTBEAT_DISPATCH" ]]; then
  echo "heartbeat.sh: Heartbeat-Skill nicht gefunden: $HEARTBEAT_DISPATCH" >&2
  exit 6
fi

exec "$HEARTBEAT_DISPATCH" "$@"
