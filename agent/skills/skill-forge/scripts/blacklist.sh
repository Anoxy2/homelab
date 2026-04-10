#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

BLACKLIST_LOCK="$STATE_DIR/.blacklist.lock"

main(){
  ensure_dirs; init_state_files
  local sub="${1:-list}"
  case "$sub" in
    add)
      [[ $# -ge 4 ]] || { echo "Usage: blacklist.sh add skill|creator <id> <reason>"; exit 1; }
      local typ="$2"; local id="$3"; shift 3; local reason="$*"
      if [[ "$typ" == "skill" ]]; then
        python3 - "$id" "$reason" <<'PY'
import sys
sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import file_lock, read_json_file, write_json_atomic
from datetime import datetime, timezone
slug, reason = sys.argv[1], sys.argv[2]
p = '/home/steges/agent/skills/skill-forge/.state/blacklist-skills.json'
lp = '/home/steges/agent/skills/skill-forge/.state/.blacklist.lock'
with file_lock(lp):
    arr = read_json_file(p, [])
    arr.append({'slug': slug, 'reason': reason,
                'added': datetime.now(timezone.utc).strftime('%Y-%m-%d'), 'source': 'manual'})
    write_json_atomic(p, arr)
PY
      else
        python3 - "$id" "$reason" <<'PY'
import sys
sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import file_lock, read_json_file, write_json_atomic
from datetime import datetime, timezone
cid, reason = sys.argv[1], sys.argv[2]
p = '/home/steges/agent/skills/skill-forge/.state/blacklist-creators.json'
lp = '/home/steges/agent/skills/skill-forge/.state/.blacklist.lock'
with file_lock(lp):
    arr = read_json_file(p, [])
    arr.append({'owner_id': cid, 'reason': reason,
                'added': datetime.now(timezone.utc).strftime('%Y-%m-%d'), 'source': 'manual'})
    write_json_atomic(p, arr)
PY
      fi
      log_audit "BLACKLIST" "-" "add $typ $id"
      echo "Blacklist added: $typ $id"
      ;;
    list)
      echo "skills:"
      cat "$STATE_DIR/blacklist-skills.json"
      echo
      echo "creators:"
      cat "$STATE_DIR/blacklist-creators.json"
      ;;
    remove)
      [[ $# -eq 3 ]] || { echo "Usage: blacklist.sh remove skill <slug>"; exit 1; }
      [[ "$2" == "skill" ]] || { echo "Only skill remove supported"; exit 1; }
      python3 - "$3" <<'PY'
import sys
sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import file_lock, read_json_file, write_json_atomic
slug = sys.argv[1]
p = '/home/steges/agent/skills/skill-forge/.state/blacklist-skills.json'
lp = '/home/steges/agent/skills/skill-forge/.state/.blacklist.lock'
with file_lock(lp):
    arr = read_json_file(p, [])
    arr = [x for x in arr if x.get('slug') != slug]
    write_json_atomic(p, arr)
print('OK')
PY
      log_audit "BLACKLIST" "-" "remove skill $3"
      echo "Blacklist removed: skill $3"
      ;;
    promote)
      "$SCRIPT_DIR/blacklist-promote.sh"
      ;;
    *)
      echo "Usage: blacklist.sh add|list|remove|promote"
      exit 1
      ;;
  esac
}
main "$@"
