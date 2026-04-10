#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

main() {
  ensure_dirs
  init_state_files

  local hours
  hours="$(awk -F': ' '/quarantine_hours:/ {print $2}' "$POLICY_DIR/vetting-policy.yaml" | tr -d '[:space:]')"
  [[ -n "$hours" ]] || hours=24

  python3 - "$hours" <<'PY'
import sys
sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import file_lock, read_json_file, write_json_atomic
from datetime import datetime, timezone

hours = int(sys.argv[1])
now = datetime.now(timezone.utc)
pp = '/home/steges/agent/skills/skill-forge/.state/pending-blacklist.json'
bs = '/home/steges/agent/skills/skill-forge/.state/blacklist-skills.json'
lp = '/home/steges/agent/skills/skill-forge/.state/.blacklist.lock'

with file_lock(lp):
    pending = read_json_file(pp, [])
    blocked = read_json_file(bs, [])

    remain = []
    promoted = 0
    for row in pending:
        ts = row.get('added_at')
        try:
            dt = datetime.strptime(ts, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
        except Exception:
            remain.append(row)
            continue
        age_h = (now - dt).total_seconds() / 3600.0
        if age_h >= hours:
            blocked.append({
                'slug': row.get('slug'),
                'reason': row.get('reason', 'pending promoted'),
                'added': now.strftime('%Y-%m-%d'),
                'source': 'auto-promote'
            })
            promoted += 1
        else:
            remain.append(row)

    write_json_atomic(pp, remain)
    write_json_atomic(bs, blocked)

print(promoted)
PY
}

count="$(main)"
log_audit "BLACKLIST" "-" "promoted=$count"
echo "Promoted entries: $count"
