#!/bin/bash
# growbox-diary.sh — Thin Wrapper
# Alle Logik liegt in: ~/agent/skills/growbox/scripts/growbox-diary.sh
# Direkte Nutzung: ~/scripts/skills growbox diary

set -euo pipefail

GROWBOX_DIARY="/home/steges/agent/skills/growbox/scripts/growbox-diary.sh"

if [[ ! -x "$GROWBOX_DIARY" ]]; then
  echo "growbox-diary.sh: Growbox-Skill nicht gefunden: $GROWBOX_DIARY" >&2
  exit 6
fi

exec "$GROWBOX_DIARY" "$@"
