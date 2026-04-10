#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

usage() {
  echo "Usage: reaper.sh [--dry-run]"
}

main() {
  ensure_dirs
  init_state_files

  local dry_run=0
  if [[ "${1:-}" == "--dry-run" ]]; then
    dry_run=1
  elif [[ $# -gt 0 ]]; then
    usage
    exit 1
  fi

  python3 - "$dry_run" <<'PY'
import json, sys
from datetime import datetime, timezone

dry_run = bool(int(sys.argv[1]))
base = '/home/steges/agent/skills/skill-forge/.state'
kp = base + '/known-skills.json'

with open(kp, 'r', encoding='utf-8') as f:
    known = json.load(f)

now = datetime.now(timezone.utc)
changes = []

for slug, row in known.items():
    status = row.get('status')
    if status not in ('active', 'canary', 'vetted', 'pending-review'):
        continue

    ts = row.get('last_used_at') or row.get('vetted_at') or row.get('last_scout') or row.get('discovered_at')
    if not ts:
        continue
    try:
        dt = datetime.strptime(ts, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
    except Exception:
        continue
    days = (now - dt).days

    target = None
    if days >= 90:
        target = 'disabled'
    elif days >= 60:
        target = 'canary-disable'
    elif days >= 30:
        target = 'review'

    if not target:
        continue

    changes.append({'slug': slug, 'from': status, 'to': target, 'inactive_days': days})
    if not dry_run:
        row['status'] = target
        row['reaper_at'] = now.strftime('%Y-%m-%dT%H:%M:%SZ')

if not dry_run:
    with open(kp, 'w', encoding='utf-8') as f:
        json.dump(known, f, indent=2, sort_keys=True)

print(json.dumps({'dry_run': dry_run, 'count': len(changes), 'changes': changes}, indent=2))
PY
}

main "$@"
