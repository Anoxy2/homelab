#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

FREEZE_FILE="$STATE_DIR/incident-freeze.json"
FREEZE_LOCK="$STATE_DIR/.incident-freeze.lock"

set_state() {
  local enabled="$1"
  local reason="$2"
  python3 - "$enabled" "$reason" "$FREEZE_FILE" "$FREEZE_LOCK" <<'PY'
import sys
sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import locked_json_update, utc_now_iso

enabled_str, reason, fpath, lpath = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
enabled = (enabled_str == 'true')

def updater(_old):
    return {
        'enabled': enabled,
        'changed_at': utc_now_iso(),
        'reason': reason,
    }

locked_json_update(fpath, lpath, updater, {})
PY
}

show_state() {
  cat "$FREEZE_FILE"
}

auto_check() {
  # Reads added_at timestamps from pending-blacklist.json (the canonical source),
  # then looks up the source of each slug from known-skills.json to group by source.
  # This fixes the previous bug where known-skills.json's vetted_at/updated_at were
  # used instead — those timestamps reflect vetting time, not blacklist-addition time.
  python3 - "$FREEZE_FILE" "$FREEZE_LOCK" <<'PY'
import json, sys
sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import file_lock, read_json_file, write_json_atomic, utc_now_iso
from datetime import datetime, timezone, timedelta

fpath, lpath = sys.argv[1], sys.argv[2]
blp = '/home/steges/agent/skills/skill-forge/.state/pending-blacklist.json'
kp  = '/home/steges/agent/skills/skill-forge/.state/known-skills.json'
pp  = '/home/steges/agent/skills/skill-forge/policy/incident-policy.yaml'

threshold = 3
with open(pp, 'r', encoding='utf-8') as f:
  for line in f:
    if line.strip().startswith('extreme_findings_same_source_24h:'):
      threshold = int(line.split(':', 1)[1].strip())
      break

# Use pending-blacklist.json added_at as the canonical timestamp
bl_entries = read_json_file(blp, [])
known      = read_json_file(kp, {})
now        = datetime.now(timezone.utc)
window     = now - timedelta(hours=24)

counts = {}
for entry in bl_entries:
  ts = entry.get('added_at')
  if not ts:
    continue
  try:
    dt = datetime.strptime(ts, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
  except Exception:
    continue
  if dt < window:
    continue
  slug = entry.get('slug', '')
  src  = known.get(slug, {}).get('source', 'unknown')
  counts[src] = counts.get(src, 0) + 1

tripped = [(s, c) for s, c in counts.items() if c >= threshold]

with file_lock(lpath):
    freeze = read_json_file(fpath, {})
    if tripped and not freeze.get('enabled'):
        src, c = sorted(tripped, key=lambda x: x[1], reverse=True)[0]
        new_freeze = {
            'enabled': True,
            'changed_at': utc_now_iso(),
            'reason': f'auto: source={src} pending_blacklist_24h={c} threshold={threshold}',
        }
        write_json_atomic(fpath, new_freeze)
        print('AUTO_FREEZE_ON')
    elif tripped and freeze.get('enabled'):
        print('ALREADY_FROZEN')
    elif not tripped and freeze.get('enabled'):
        # Conditions are clear but policy requires manual unfreeze
        print('CONDITIONS_CLEAR_MANUAL_UNFREEZE_REQUIRED')
    else:
        print('AUTO_FREEZE_CLEAR')
PY
}

main() {
  ensure_dirs
  init_state_files

  local cmd="${1:-status}"
  case "$cmd" in
    on)
      set_state true "manual"
      log_audit "INCIDENT" "-" "freeze on"
      echo "Incident freeze enabled"
      ;;
    off)
      set_state false "manual"
      log_audit "INCIDENT" "-" "freeze off"
      echo "Incident freeze disabled"
      ;;
    status)
      show_state
      ;;
    auto-check)
      auto_check
      ;;
    *)
      echo "Usage: incident-freeze.sh on|off|status|auto-check"
      exit 1
      ;;
  esac
}

main "$@"
