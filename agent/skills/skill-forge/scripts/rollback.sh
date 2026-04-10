#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

main() {
  ensure_dirs; init_state_files
  [[ $# -ge 1 ]] || { echo "Usage: rollback.sh <slug> [--list]"; exit 1; }
  local slug="$1"
  if [[ "${2:-}" == "--list" ]]; then
    find "$SM_ROOT/.state/provenance/$slug" -maxdepth 1 -type f 2>/dev/null | sort || true
    exit 0
  fi
  python3 - "$slug" <<'PY'
import json, sys
from datetime import datetime, timezone
slug=sys.argv[1]
p='/home/steges/agent/skills/skill-forge/.state/known-skills.json'
with open(p,'r',encoding='utf-8') as f: d=json.load(f)
row=d.get(slug)
if not row:
    print('NOT_FOUND'); raise SystemExit(2)
row['status']='rollback'
row['rollback_at']=datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
d[slug]=row
with open(p,'w',encoding='utf-8') as f: json.dump(d,f,indent=2,sort_keys=True)
print('OK')
PY
  log_audit "ROLLBACK" "$slug" "manual"
  echo "Rollback marked: $slug"
}
main "$@"
