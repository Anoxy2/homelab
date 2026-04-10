#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

main() {
  ensure_dirs; init_state_files
  [[ $# -eq 1 ]] || { echo "Usage: review.sh <slug>"; exit 1; }
  local slug="$1"

  if ! validate_known_skill_transition "$slug" "reviewed" "pending-review,reviewed" >/dev/null; then
    echo "Blocked invalid state transition for $slug -> reviewed" >&2
    exit "$EXIT_POLICY"
  fi

  with_state_lock python3 - "$slug" <<'PY'
import json, sys
sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import write_json_atomic
slug=sys.argv[1]
kp='/home/steges/agent/skills/skill-forge/.state/known-skills.json'
with open(kp,'r',encoding='utf-8') as f: k=json.load(f)
row=k.get(slug)
if not row:
    print('NOT_FOUND'); raise SystemExit(2)
row['status']='reviewed'
k[slug]=row
write_json_atomic(kp, k)
print('OK')
PY
  log_audit "REVIEW" "$slug" "manual-reviewed"
  echo "Reviewed: $slug"
}
main "$@"
