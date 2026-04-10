#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

usage() {
  echo "Usage: author-queue.sh list|approve <job-id>"
}

list_jobs() {
  python3 - <<'PY'
import json
p = '/home/steges/agent/skills/skill-forge/.state/author-queue.json'
with open(p, 'r', encoding='utf-8') as f:
    rows = json.load(f)
if not rows:
    print('No author jobs in queue.')
else:
    for r in rows:
        print(f"{r.get('id')} | {r.get('name')} | {r.get('mode')} | {r.get('status')}")
PY
}

approve_job() {
  local job_id="$1"
  python3 - "$job_id" <<'PY'
import json
import sys

sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import utc_now_iso, write_json_atomic

job_id = sys.argv[1]
p = '/home/steges/agent/skills/skill-forge/.state/author-queue.json'

with open(p, 'r', encoding='utf-8') as f:
    rows = json.load(f)
found = False
for r in rows:
    if r.get('id') == job_id:
        r['status'] = 'approved'
        r['approved_at'] = utc_now_iso()
        found = True
if not found:
    print('NOT_FOUND')
    raise SystemExit(2)
write_json_atomic(p, rows)
print('OK')
PY
}

main() {
  ensure_dirs
  init_state_files

  local sub="${1:-list}"
  case "$sub" in
    list)
      list_jobs
      ;;
    approve)
      [[ $# -eq 2 ]] || { usage; exit 1; }
      with_state_lock approve_job "$2" >/dev/null
      log_audit "AUTHOR" "-" "approve job=$2"
      echo "Approved: $2"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
