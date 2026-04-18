#!/bin/bash

set -euo pipefail

SM_ROOT="/home/steges/agent/skills/skill-forge"
STATE_DIR="$SM_ROOT/.state"
POLICY_DIR="$SM_ROOT/policy"
AUDIT_LOG="$STATE_DIR/audit-log.jsonl"

# Canonical exit codes for wrapper and lifecycle scripts.
EXIT_USAGE=2
EXIT_CONTRACT=3
EXIT_POLICY=4
EXIT_FREEZE=5
EXIT_MISSING_EXECUTABLE=6

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

ensure_dirs() {
  mkdir -p "$SM_ROOT/scripts" "$SM_ROOT/references" "$SM_ROOT/policy" "$SM_ROOT/config"
  mkdir -p "$SM_ROOT/templates/skill" "$SM_ROOT/catalog"
  mkdir -p "$SM_ROOT/generated/docs" "$SM_ROOT/generated/code" "$SM_ROOT/generated/config" "$SM_ROOT/generated/test"
  mkdir -p "$STATE_DIR" "$STATE_DIR/provenance" "$STATE_DIR/vetter-reports"
}

init_state_files() {
  [[ -f "$STATE_DIR/known-skills.json" ]] || echo '{}' > "$STATE_DIR/known-skills.json"
  [[ -f "$STATE_DIR/pending-blacklist.json" ]] || echo '[]' > "$STATE_DIR/pending-blacklist.json"
  [[ -f "$STATE_DIR/blacklist-skills.json" ]] || echo '[]' > "$STATE_DIR/blacklist-skills.json"
  [[ -f "$STATE_DIR/blacklist-creators.json" ]] || echo '[]' > "$STATE_DIR/blacklist-creators.json"
  [[ -f "$STATE_DIR/fingerprints.json" ]] || echo '{}' > "$STATE_DIR/fingerprints.json"
  [[ -f "$STATE_DIR/update-log.json" ]] || echo '[]' > "$STATE_DIR/update-log.json"
  [[ -f "$STATE_DIR/source-cache.json" ]] || echo '{}' > "$STATE_DIR/source-cache.json"
  [[ -f "$STATE_DIR/author-queue.json" ]] || echo '[]' > "$STATE_DIR/author-queue.json"
  [[ -f "$STATE_DIR/writer-jobs.json" ]] || echo '[]' > "$STATE_DIR/writer-jobs.json"
  [[ -f "$STATE_DIR/canary.json" ]] || echo '{}' > "$STATE_DIR/canary.json"
  [[ -f "$STATE_DIR/shadow-mode.json" ]] || echo '{"enabled":false,"changed_at":null}' > "$STATE_DIR/shadow-mode.json"
  [[ -f "$STATE_DIR/incident-freeze.json" ]] || echo '{"enabled":false,"changed_at":null,"reason":""}' > "$STATE_DIR/incident-freeze.json"
  [[ -f "$STATE_DIR/doc-keeper-state.json" ]] || echo '{"last_daily_run":""}' > "$STATE_DIR/doc-keeper-state.json"
  [[ -f "$AUDIT_LOG" ]] || : > "$AUDIT_LOG"
}

log_audit() {
  local action="$1"
  local slug="$2"
  local msg="$3"
  python3 - "$AUDIT_LOG" "$action" "$slug" "$msg" "$(now_iso)" <<'PY'
import json
import os
import re
import sys

path, action, target, message, ts = sys.argv[1:]

reason = ""
match = re.search(r"(?:^|\s)reason=([^\s].*)", message)
if match:
    reason = match.group(1).strip()

action_upper = action.upper()
if action_upper in {"PASS", "PROMOTE", "INSTALL"}:
    result = "success"
elif action_upper in {"REJECT", "CONTRACT", "ROLLBACK"}:
    result = "failed"
elif action_upper in {"REVIEW", "CANARY", "BLACKLIST", "HEARTBEAT", "ORCHESTRATE", "TEST"}:
    result = "info"
else:
    result = "info"

record = {
    "ts": ts,
    "actor": "skill-forge",
    "command": action,
    "target": target,
    "result": result,
    "reason": reason,
    "run_id": os.getenv("SKILL_MANAGER_RUN_ID", ""),
    "message": message,
}

with open(path, "a", encoding="utf-8") as f:
    f.write(json.dumps(record, ensure_ascii=True) + "\n")
PY
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing required command: $cmd" >&2
    exit 1
  }
}

with_state_lock() {
  local lock_file="$STATE_DIR/skill-forge.state.lock"
  if [[ "${SM_LOCK_HELD:-0}" == "1" ]]; then
    "$@"
    return $?
  fi
  if command -v flock >/dev/null 2>&1; then
    mkdir -p "$STATE_DIR"
    exec {lock_fd}>"$lock_file"
    flock "$lock_fd"
    set +e
    "$@"
    local rc=$?
    set -e
    flock -u "$lock_fd"
    exec {lock_fd}>&-
    return $rc
  else
    "$@"
  fi
}

validate_known_skill_transition() {
  local slug="$1"
  local to_status="$2"
  local allowed_csv="$3"

  python3 - "$STATE_DIR/known-skills.json" "$slug" "$to_status" "$allowed_csv" <<'PY'
import json
import sys

path, slug, to_status, allowed_csv = sys.argv[1:5]
allowed = {x.strip() for x in allowed_csv.split(',') if x.strip()}

with open(path, 'r', encoding='utf-8') as f:
  known = json.load(f)

row = known.get(slug)
current = 'unknown' if row is None else str(row.get('status', 'unknown'))

if current == to_status:
  print('OK')
  raise SystemExit(0)

if current not in allowed:
  print(f"INVALID_TRANSITION {slug}: {current} -> {to_status}; allowed={','.join(sorted(allowed))}")
  raise SystemExit(1)

print('OK')
PY
}

is_incident_freeze_on() {
  python3 - <<'PY'
import json
p = '/home/steges/agent/skills/skill-forge/.state/incident-freeze.json'
with open(p, 'r', encoding='utf-8') as f:
    data = json.load(f)
print('1' if data.get('enabled') else '0')
PY
}
