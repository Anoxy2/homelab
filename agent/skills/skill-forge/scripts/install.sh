#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

main() {
  ensure_dirs; init_state_files
  [[ $# -ge 1 ]] || { echo "Usage: install.sh <slug> [source] [version] [score]"; exit 1; }
  local slug="$1"
  local source_name="${2:-manual}"
  local version="${3:-0.1.0}"
  local score="${4:-85}"

  "$SCRIPT_DIR/scout.sh" --add "$slug" "$source_name" "$version" >/dev/null
  "$SCRIPT_DIR/vet.sh" "$slug" "$score" >/dev/null

  local status
  status="$(python3 - "$slug" <<'PY'
import json, sys
slug=sys.argv[1]
p='/home/steges/agent/skills/skill-forge/.state/known-skills.json'
with open(p,'r',encoding='utf-8') as f: d=json.load(f)
print(d.get(slug,{}).get('status','unknown'))
PY
)"

  if [[ "$status" == "vetted" ]]; then
    "$SCRIPT_DIR/canary.sh" start "$slug" 24 >/dev/null
    log_audit "INSTALL" "$slug" "source=$source_name version=$version score=$score canary_started=24h"
    echo "Installed in canary: $slug (24h minimum before promote)"
  else
    log_audit "INSTALL" "$slug" "source=$source_name version=$version score=$score blocked status=$status"
    echo "Install blocked for $slug (status=$status)"
  fi
}
main "$@"
