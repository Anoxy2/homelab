#!/bin/bash
# learn.sh — Thin Wrapper (delegiert an den eigenständigen Learn-Skill)
# Alle Logik liegt in: ~/agent/skills/learn/scripts/learn-dispatch.sh
# Direkte Nutzung: ~/scripts/skills learn ...

set -euo pipefail

LEARN_DISPATCH="/home/steges/agent/skills/learn/scripts/learn-dispatch.sh"

if [[ ! -x "$LEARN_DISPATCH" ]]; then
  echo "learn.sh: Learn-Skill nicht gefunden: $LEARN_DISPATCH" >&2
  exit 6
fi

exec "$LEARN_DISPATCH" "$@"
