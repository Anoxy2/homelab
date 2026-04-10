#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

usage() {
  echo "Usage: conflict-check.sh <slug>"
}

main() {
  ensure_dirs
  init_state_files
  [[ $# -eq 1 ]] || { usage; exit 1; }
  local slug="$1"

  python3 - "$slug" <<'PY'
import json, re, sys
slug = sys.argv[1]
kp = '/home/steges/agent/skills/skill-forge/.state/known-skills.json'
with open(kp, 'r', encoding='utf-8') as f:
    known = json.load(f)

def toks(s):
    return [t for t in re.split(r'[^a-z0-9]+', s.lower()) if t]

new = set(toks(slug))
conflicts = []
for other, row in known.items():
    if other == slug:
        continue
    if row.get('status') not in ('active', 'canary'):
        continue
    overlap = new.intersection(toks(other))
    # conservative: 2+ shared tokens or one exact first token means conflict candidate
    if len(overlap) >= 2:
        conflicts.append((other, sorted(list(overlap))))
        continue
    nt = toks(slug)
    ot = toks(other)
    if nt and ot and nt[0] == ot[0]:
        conflicts.append((other, [nt[0]]))

if conflicts:
    print('CONFLICT')
    for o, ov in conflicts:
        print(f'{o}|{";".join(ov)}')
    raise SystemExit(2)
print('CLEAR')
PY
}

main "$@"
