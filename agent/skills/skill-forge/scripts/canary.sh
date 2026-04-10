#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

usage() {
  echo "Usage: canary.sh start <slug> [hours] | status <slug> | promote <slug> [--emergency --reason <text>] | fail <slug>"
}

policy_canary_min_hours() {
  python3 - <<'PY'
import re
path = '/home/steges/agent/skills/skill-forge/policy/rollout-policy.yaml'
raw = open(path, 'r', encoding='utf-8').read()
m = re.search(r'^\s*hard_min_hours:\s*(\d+)\s*$', raw, re.M)
if not m:
  m = re.search(r'^\s*window_hours:\s*(\d+)\s*$', raw, re.M)
print(m.group(1) if m else '24')
PY
}

ensure_canary_matured() {
  local slug="$1"
  local min_hours="$2"
  python3 - "$slug" "$min_hours" <<'PY'
import json
import sys
from datetime import datetime, timezone, timedelta

slug = sys.argv[1]
min_hours = int(sys.argv[2])
cp = '/home/steges/agent/skills/skill-forge/.state/canary.json'

with open(cp, 'r', encoding='utf-8') as f:
    data = json.load(f)

row = data.get(slug)
if not row:
    print('NO_CANARY')
    raise SystemExit(2)

started_raw = row.get('started_at')
if not started_raw:
    print('MISSING_STARTED_AT')
    raise SystemExit(3)

started = datetime.strptime(started_raw, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
now = datetime.now(timezone.utc)
required = started + timedelta(hours=min_hours)

if now < required:
    remaining = required - now
    mins = int(remaining.total_seconds() // 60)
    print(f'CANARY_TOO_YOUNG remaining_minutes={mins} required_after={required.strftime("%Y-%m-%dT%H:%M:%SZ")}')
    raise SystemExit(4)

print('OK')
PY
}

evaluate_summary() {
  local slug="$1"
  local eval_cmd=(/home/steges/agent/skills/canary/scripts/canary-dispatch.sh evaluate "$slug" --json)
  if command -v timeout >/dev/null 2>&1; then
    eval_cmd=(timeout 30 "${eval_cmd[@]}")
  fi
  "${eval_cmd[@]}" 2>/dev/null | \
  python3 -c 'import json,sys
try:
  data=json.load(sys.stdin)
  verdict=data.get("verdict","unknown")
  confidence=data.get("confidence","na")
  rationale=str(data.get("rationale"," ")).replace("\n"," ").strip()
  if verdict=="unknown" or confidence=="na":
    raise ValueError("missing fields")
  print(f"verdict={verdict} confidence={confidence} rationale={rationale}")
except Exception:
  raise SystemExit(1)'
}

state_update() {
  local slug="$1"
  local op="$2"
  local hours="${3:-24}"
  python3 - "$slug" "$op" "$hours" <<'PY'
import json
import sys
from datetime import datetime, timezone, timedelta

sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import write_json_atomic

slug, op, hours = sys.argv[1], sys.argv[2], int(sys.argv[3])
cp = '/home/steges/agent/skills/skill-forge/.state/canary.json'
kp = '/home/steges/agent/skills/skill-forge/.state/known-skills.json'

with open(cp, 'r', encoding='utf-8') as f:
    c = json.load(f)
with open(kp, 'r', encoding='utf-8') as f:
    k = json.load(f)
row = k.get(slug, {'slug': slug, 'source': 'manual', 'version': '0.0.0'})
now = datetime.now(timezone.utc)
if op == 'start':
    prev = str(row.get('status', 'unknown'))
    if prev not in {'unknown', 'vetted', 'active', 'canary', 'reviewed'}:
        print(f'INVALID_TRANSITION {slug}: {prev} -> canary')
        raise SystemExit(7)
    c[slug] = {
      'started_at': now.strftime('%Y-%m-%dT%H:%M:%SZ'),
      'until': (now + timedelta(hours=hours)).strftime('%Y-%m-%dT%H:%M:%SZ'),
      'status': 'running'
    }
    row['status'] = 'canary'
elif op == 'promote':
    if slug not in c:
      print('NO_CANARY')
      raise SystemExit(2)
    if c[slug].get('status') != 'running':
      print('CANARY_NOT_RUNNING')
      raise SystemExit(3)
    prev = str(row.get('status', 'unknown'))
    if prev not in {'canary', 'active'}:
      print(f'INVALID_TRANSITION {slug}: {prev} -> active')
      raise SystemExit(7)
    c[slug]['status'] = 'promoted'
    c[slug]['promoted_at'] = now.strftime('%Y-%m-%dT%H:%M:%SZ')
    row['status'] = 'active'
elif op == 'fail':
    prev = str(row.get('status', 'unknown'))
    if prev not in {'canary', 'active', 'vetted', 'reviewed', 'pending-review', 'rollback'}:
      print(f'INVALID_TRANSITION {slug}: {prev} -> rollback')
      raise SystemExit(7)
    if slug in c:
      c[slug]['status'] = 'failed'
      c[slug]['failed_at'] = now.strftime('%Y-%m-%dT%H:%M:%SZ')
    row['status'] = 'rollback'
write_json_atomic(cp, c)
k[slug] = row
write_json_atomic(kp, k)
print('OK')
PY
}

status_show() {
  local slug="$1"
  python3 - "$slug" <<'PY'
import json, sys
slug = sys.argv[1]
p = '/home/steges/agent/skills/skill-forge/.state/canary.json'
with open(p, 'r', encoding='utf-8') as f:
    data = json.load(f)
print(json.dumps(data.get(slug, {}), indent=2))
PY
}

main() {
  ensure_dirs
  init_state_files

  local sub="${1:-}"
  case "$sub" in
    start)
      [[ $# -ge 2 ]] || { usage; exit "$EXIT_USAGE"; }
      with_state_lock state_update "$2" start "${3:-24}" >/dev/null
      log_audit "CANARY" "$2" "start hours=${3:-24}"
      echo "Canary started: $2"
      ;;
    status)
      [[ $# -eq 2 ]] || { usage; exit "$EXIT_USAGE"; }
      status_show "$2"
      ;;
    promote)
      [[ $# -ge 2 ]] || { usage; exit "$EXIT_USAGE"; }
      local slug="$2"
      shift 2

      local emergency=0
      local reason=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --emergency)
            emergency=1
            shift
            ;;
          --reason)
            [[ $# -ge 2 ]] || { echo "--reason requires text"; exit "$EXIT_USAGE"; }
            reason="$2"
            shift 2
            ;;
          *)
            echo "Unknown argument: $1"
            usage
            exit "$EXIT_USAGE"
            ;;
        esac
      done

      if [[ "$emergency" -eq 1 && -z "$reason" ]]; then
        echo "Emergency promotion requires --reason."
        exit "$EXIT_USAGE"
      fi

      if [[ "$(is_incident_freeze_on)" == "1" ]]; then
        echo "Incident freeze active: cannot promote canary."
        exit "$EXIT_FREEZE"
      fi

      if [[ "$emergency" -eq 0 ]]; then
        local min_hours
        min_hours="$(policy_canary_min_hours)"
        if ! ensure_canary_matured "$slug" "$min_hours" >/dev/null; then
          echo "Canary minimum age not reached for $slug (min_hours=$min_hours)."
          echo "Use --emergency --reason \"...\" only for justified exceptions."
          exit "$EXIT_POLICY"
        fi
      fi

      with_state_lock state_update "$slug" promote >/dev/null
      local eval_note=""
      if eval_note="$(evaluate_summary "$slug")"; then
        if [[ "$emergency" -eq 1 ]]; then
          log_audit "CANARY" "$slug" "promote active emergency=1 reason=$reason $eval_note"
        else
          log_audit "CANARY" "$slug" "promote active emergency=0 $eval_note"
        fi
      else
        if [[ "$emergency" -eq 1 ]]; then
          log_audit "CANARY" "$slug" "promote active emergency=1 reason=$reason"
        else
          log_audit "CANARY" "$slug" "promote active emergency=0"
        fi
      fi
      if [[ "${DOC_KEEPER_AUTORUN:-1}" == "1" ]]; then
        /home/steges/scripts/skills rag doc-keeper run --reason "post-promote:$slug" --autodoc --autodoc-profile post-promote >/dev/null || {
          log_audit "DOC_KEEPER" "$slug" "post-promote-run failed"
        }
      fi
      echo "Canary promoted to active: $slug"
      ;;
    fail)
      [[ $# -eq 2 ]] || { usage; exit "$EXIT_USAGE"; }
      with_state_lock state_update "$2" fail >/dev/null
      log_audit "CANARY" "$2" "fail rollback"
      echo "Canary failed: $2 -> rollback"
      ;;
    *)
      usage
      exit "$EXIT_USAGE"
      ;;
  esac
}

main "$@"
