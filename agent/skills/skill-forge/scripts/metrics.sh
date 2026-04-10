#!/bin/bash
# metrics.sh — Thin Wrapper (delegiert an den eigenständigen Metrics-Skill)
# Alle Logik liegt in: ~/agent/skills/metrics/scripts/metrics-dispatch.sh
# Direkte Nutzung: ~/scripts/skills metrics ...

set -euo pipefail

METRICS_DISPATCH="/home/steges/agent/skills/metrics/scripts/metrics-dispatch.sh"

if [[ ! -x "$METRICS_DISPATCH" ]]; then
  echo "metrics.sh: Metrics-Skill nicht gefunden: $METRICS_DISPATCH" >&2
  exit 6
fi

exec "$METRICS_DISPATCH" "$@"
