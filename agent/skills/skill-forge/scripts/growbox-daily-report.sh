#!/bin/bash
# growbox-daily-report.sh — Thin Wrapper
# Alle Logik liegt in: ~/agent/skills/growbox/scripts/growbox-daily-report.sh
# Direkte Nutzung: ~/scripts/skills growbox daily-report

set -euo pipefail

GROWBOX_REPORT="/home/steges/agent/skills/growbox/scripts/growbox-daily-report.sh"

if [[ ! -x "$GROWBOX_REPORT" ]]; then
  echo "growbox-daily-report.sh: Growbox-Skill nicht gefunden: $GROWBOX_REPORT" >&2
  exit 6
fi

exec "$GROWBOX_REPORT" "$@"
