#!/bin/bash
# profile.sh — Thin Wrapper (delegiert an den eigenständigen Profile-Skill)
# Alle Logik liegt in: ~/agent/skills/profile/scripts/profile-dispatch.sh
# Direkte Nutzung: ~/scripts/skills profile ...

set -euo pipefail

PROFILE_DISPATCH="/home/steges/agent/skills/profile/scripts/profile-dispatch.sh"

if [[ ! -x "$PROFILE_DISPATCH" ]]; then
  echo "profile.sh: Profile-Skill nicht gefunden: $PROFILE_DISPATCH" >&2
  exit 6
fi

exec "$PROFILE_DISPATCH" "$@"
