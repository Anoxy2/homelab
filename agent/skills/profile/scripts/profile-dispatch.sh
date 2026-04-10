#!/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source "/home/steges/agent/skills/skill-forge/scripts/common.sh"

PROFILE="$STATE_DIR/usage-profile.json"

main() {
  ensure_dirs; init_state_files
  [[ -f "$PROFILE" ]] || echo '{"keywords":[]}' > "$PROFILE"
  local sub="${1:-show}"
  case "$sub" in
    show)
      cat "$PROFILE"
      ;;
    add)
      [[ $# -eq 2 ]] || { echo "Usage: profile-dispatch.sh add <keyword>"; exit 1; }
      python3 - "$2" <<'PY'
import json, sys
kw=sys.argv[1]
p='/home/steges/agent/skills/skill-forge/.state/usage-profile.json'
with open(p,'r',encoding='utf-8') as f: d=json.load(f)
arr=d.setdefault('keywords',[])
if kw not in arr: arr.append(kw)
with open(p,'w',encoding='utf-8') as f: json.dump(d,f,indent=2,sort_keys=True)
print('OK')
PY
      log_audit "PROFILE" "-" "add $2"
      echo "Added keyword: $2"
      ;;
    reset)
      echo '{"keywords":[]}' > "$PROFILE"
      log_audit "PROFILE" "-" "reset"
      echo "Profile reset"
      ;;
    *)
      echo "Usage: profile-dispatch.sh show|add <keyword>|reset"
      exit 1
      ;;
  esac
}
main "$@"
