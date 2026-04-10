#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

set_state() {
  local enabled="$1"
  python3 - "$enabled" <<'PY'
import json, sys
from datetime import datetime, timezone
enabled = sys.argv[1] == 'true'
p = '/home/steges/agent/skills/skill-forge/.state/shadow-mode.json'
with open(p, 'w', encoding='utf-8') as f:
    json.dump({'enabled': enabled, 'changed_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}, f)
PY
}

main() {
  ensure_dirs
  init_state_files
  [[ -f "$STATE_DIR/shadow-mode.json" ]] || echo '{"enabled":false,"changed_at":null}' > "$STATE_DIR/shadow-mode.json"

  local cmd="${1:-status}"
  case "$cmd" in
    on)
      set_state true
      log_audit "SHADOW" "-" "on"
      echo "Shadow mode enabled"
      ;;
    off)
      set_state false
      log_audit "SHADOW" "-" "off"
      echo "Shadow mode disabled"
      ;;
    status)
      cat "$STATE_DIR/shadow-mode.json"
      ;;
    *)
      echo "Usage: shadow-mode.sh on|off|status"
      exit 1
      ;;
  esac
}

main "$@"
