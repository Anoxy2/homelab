#!/bin/bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SM_SCRIPTS="/home/steges/agent/skills/skill-forge/scripts"
SKILLS_WRAPPER="/home/steges/scripts/skills"
# shellcheck source=/dev/null
source "$SM_SCRIPTS/common.sh"

HEARTBEAT_TASK_TIMEOUT="${HEARTBEAT_TASK_TIMEOUT:-60}"
HEARTBEAT_AUTODOC_TIMEOUT="${HEARTBEAT_AUTODOC_TIMEOUT:-240}"
HEARTBEAT_AUTODOC_PROVIDER="${HEARTBEAT_AUTODOC_PROVIDER:-copilot}"
HEARTBEAT_AUTODOC_MODEL="${HEARTBEAT_AUTODOC_MODEL:-gpt-4.1}"
declare -a TASK_FAILURES=()

run_with_timeout() {
  local timeout_s="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout --signal=TERM --kill-after=5 "${timeout_s}" "$@"
  else
    "$@"
  fi
}

record_task_failure() {
  local task="$1"
  local detail="$2"
  TASK_FAILURES+=("${task}: ${detail}")
}

# shellcheck source=/home/steges/scripts/lib/env.sh
source "/home/steges/scripts/lib/env.sh"

ACTION_LOG_PATH="/home/steges/infra/openclaw-data/action-log.jsonl"
ACTION_LOG_CANVAS_JSON="/home/steges/agent/skills/openclaw-ui/html/action-log.latest.json"
CANVAS_OPS_BRIEF_SCRIPT="/home/steges/scripts/canvas-ops-brief.sh"
CANVAS_STATE_BRIEF_SCRIPT="/home/steges/scripts/canvas-state-brief.sh"
CANVAS_SKILL_PAGES_BRIEF_SCRIPT="/home/steges/scripts/canvas-skill-pages-brief.sh"

ensure_action_log() {
  mkdir -p "$(dirname "$ACTION_LOG_PATH")"
  [[ -f "$ACTION_LOG_PATH" ]] || : > "$ACTION_LOG_PATH"
}

append_action_log() {
  local skill="$1"
  local action="$2"
  local result="$3"
  local triggered_by="$4"
  python3 - "$ACTION_LOG_PATH" "$skill" "$action" "$result" "$triggered_by" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, skill, action, result, triggered_by = sys.argv[1:]
record = {
  'ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
  'skill': skill,
  'action': action,
  'result': result,
  'triggered_by': triggered_by,
}
with open(path, 'a', encoding='utf-8') as f:
  f.write(json.dumps(record, ensure_ascii=True) + '\n')
PY
}

refresh_action_log_canvas_snapshot() {
  python3 - "$ACTION_LOG_PATH" "$ACTION_LOG_CANVAS_JSON" <<'PY'
import json
import os
import tempfile
from datetime import datetime, timezone
import sys

src, dest = sys.argv[1], sys.argv[2]
rows = []
if os.path.exists(src):
  with open(src, 'r', encoding='utf-8', errors='ignore') as f:
    for line in f:
      line = line.strip()
      if not line:
        continue
      try:
        rows.append(json.loads(line))
      except json.JSONDecodeError:
        continue

payload = {
  'updated_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
  'count': min(len(rows), 50),
  'entries': rows[-50:],
}

os.makedirs(os.path.dirname(dest), exist_ok=True)
fd, tmp = tempfile.mkstemp(prefix='.tmp-', suffix='.json', dir=os.path.dirname(dest))
try:
  with os.fdopen(fd, 'w', encoding='utf-8') as f:
    json.dump(payload, f, ensure_ascii=True, indent=2)
    f.flush()
    os.fsync(f.fileno())
  os.replace(tmp, dest)
  os.chmod(dest, 0o644)
finally:
  if os.path.exists(tmp):
    os.unlink(tmp)
PY
}

heartbeat_status_snapshot() {
  python3 - "$STATE_DIR" <<'PY'
import json
import sys

state_dir = sys.argv[1]

with open(f"{state_dir}/known-skills.json", 'r', encoding='utf-8') as f:
    known = json.load(f)
with open(f"{state_dir}/pending-blacklist.json", 'r', encoding='utf-8') as f:
    pending = json.load(f)
with open(f"{state_dir}/canary.json", 'r', encoding='utf-8') as f:
    canary = json.load(f)
with open(f"{state_dir}/incident-freeze.json", 'r', encoding='utf-8') as f:
    freeze = json.load(f)

active = sum(1 for v in known.values() if v.get('status') == 'active')
canary_running = sum(1 for v in canary.values() if v.get('state') == 'running')
pending_status = sum(1 for v in known.values() if v.get('status') == 'pending-blacklist')

print(
  f"known={len(known)} active={active} canary_running={canary_running} "
  f"pending_blacklist_status={pending_status} pending_blacklist_queue={len(pending)} "
  f"freeze={'on' if freeze.get('enabled') else 'off'}"
)
PY
}

latest_metrics_line() {
  local metrics_json
  metrics_json="$(/home/steges/scripts/skills metrics latest 2>/dev/null || true)"
  if [[ -z "$metrics_json" ]]; then
    echo "metrics=n/a"
    return
  fi

  python3 - <<'PY' "$metrics_json"
import json
import sys

raw = sys.argv[1]
try:
    m = json.loads(raw)
except json.JSONDecodeError:
    print("metrics=unparseable")
    raise SystemExit(0)

print(
    "metrics "
    f"run_id={m.get('run_id', '-')}; "
    f"live={m.get('live', '-')}; "
    f"install_success_rate={m.get('install_success_rate', '-')}; "
    f"rollback_rate={m.get('rollback_rate', '-')}; "
    f"decision_s={m.get('time_to_decision', '-')}"
)
PY
}

system_runtime_line() {
  local containers
  containers="$(docker ps --format '{{.Names}}|{{.Status}}' 2>/dev/null || true)"
  local disk_root
  disk_root="$(df -h / | awk 'NR==2 {print $5}' | tr -d '%' 2>/dev/null || echo n/a)"
  local load1
  load1="$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo n/a)"
  local mem_used_pct
  mem_used_pct="$(free -m 2>/dev/null | awk 'NR==2 {if ($2>0) printf("%.0f", ($3/$2)*100); else print "n/a"}' || echo n/a)"

  python3 - <<'PY' "$containers" "$disk_root" "$load1" "$mem_used_pct"
import sys

raw = sys.argv[1]
disk = sys.argv[2]
load = sys.argv[3]
mem = sys.argv[4]

running = 0
total = 0
unhealthy = 0

for line in raw.splitlines():
  if not line.strip():
    continue
  total += 1
  parts = line.split('|', 1)
  status = parts[1] if len(parts) > 1 else ''
  low = status.lower()
  if low.startswith('up'):
    running += 1
  if 'unhealthy' in low:
    unhealthy += 1

print(
  f"containers={running}/{total}; unhealthy={unhealthy}; "
  f"disk_root={disk}%; load1={load}; mem_used={mem}%"
)
PY
}

recent_audit_digest_line() {
  python3 - <<'PY' "$AUDIT_LOG" "$LEGACY_AUDIT_LOG"
import json
import os
import sys
from datetime import datetime, timedelta, timezone

paths = [p for p in sys.argv[1:] if p]
cutoff = datetime.now(timezone.utc) - timedelta(hours=24)

rejects = 0
promotes = 0
rollbacks = 0
heartbeat_fail = 0
last = "none"

lines = []
for path in paths:
  if not os.path.exists(path):
    continue
  with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    lines.extend([ln.strip() for ln in f if ln.strip()])

for ln in lines:
  if ln.startswith('{'):
    try:
      obj = json.loads(ln)
    except json.JSONDecodeError:
      continue
    ts = obj.get('ts', '')
    action = str(obj.get('command', ''))
    slug = str(obj.get('target', ''))
    msg = str(obj.get('message', ''))
  else:
    parts = [p.strip() for p in ln.split('|', 3)]
    if len(parts) < 4:
      continue
    ts, action, slug, msg = parts

  last = f"{action}:{slug}:{msg[:70]}"
  try:
    dt = datetime.strptime(ts, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
  except Exception:
    continue
  if dt < cutoff:
    continue

  if action == 'REJECT':
    rejects += 1
  if action == 'PROMOTE' or 'vetted->active' in msg:
    promotes += 1
  if action == 'ROLLBACK':
    rollbacks += 1
  if action == 'HEARTBEAT' and 'failed rc=' in msg:
    heartbeat_fail += 1

print(
  f"24h rejects={rejects}; promotes={promotes}; rollbacks={rollbacks}; "
  f"heartbeat_fail={heartbeat_fail}; last={last}"
)
PY
}

weekly_trend_line() {
  python3 - <<'PY' "$STATE_DIR/metrics.jsonl" "$STATE_DIR/metrics-weekly.json"
import json
import sys

latest_path = sys.argv[1]
weekly_path = sys.argv[2]

latest = {}
weekly = {}

try:
  with open(latest_path, 'r', encoding='utf-8') as f:
    rows = [ln.strip() for ln in f if ln.strip()]
  if rows:
    latest = json.loads(rows[-1])
except Exception:
  latest = {}

try:
  with open(weekly_path, 'r', encoding='utf-8') as f:
    weekly = json.load(f)
except Exception:
  weekly = {}

def diff(latest_key, weekly_key):
  l = latest.get(latest_key)
  w = weekly.get(weekly_key)
  if l is None or w is None:
    return 'n/a'
  try:
    d = float(l) - float(w)
    sign = '+' if d >= 0 else ''
    return f"{sign}{d:.4f}"
  except Exception:
    return 'n/a'

runs = weekly.get('runs', 'n/a')
print(
  f"vs_week install={diff('install_success_rate', 'avg_install_success_rate')}; "
  f"rollback={diff('rollback_rate', 'avg_rollback_rate')}; "
  f"decision_s={diff('time_to_decision', 'avg_time_to_decision')}; runs_week={runs}"
)
PY
}

send_telegram_heartbeat() {
  local text="$1"
  local token="${TELEGRAM_BOT_TOKEN:-}"
  local chat_id="${TELEGRAM_CHAT_ID:-${OPENCLAW_TELEGRAM_CHAT_ID:-}}"

  if [[ -z "$token" ]]; then
    echo "Telegram heartbeat skipped: TELEGRAM_BOT_TOKEN fehlt"
    return 0
  fi

  if [[ -z "$chat_id" ]]; then
    chat_id="$(curl -fsS --max-time 10 "https://api.telegram.org/bot${token}/getUpdates" 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); r=d.get('result', []); print(r[-1]['message']['chat']['id'] if r and r[-1].get('message') and r[-1]['message'].get('chat') else '')" 2>/dev/null || true)"
    if [[ -z "$chat_id" ]]; then
      echo "Telegram heartbeat skipped: TELEGRAM_CHAT_ID fehlt und konnte nicht automatisch ermittelt werden (Bot kurz anschreiben)."
      return 0
    fi
    echo "Telegram heartbeat: Chat-ID automatisch aus getUpdates ermittelt (${chat_id})"
  fi

  local api_url="https://api.telegram.org/bot${token}/sendMessage"
  if ! curl -fsS --retry 2 --max-time 10 "$api_url" \
      -d "chat_id=${chat_id}" \
      -d "disable_web_page_preview=true" \
      --data-urlencode "text=${text}" >/dev/null; then
    echo "Telegram heartbeat send failed"
    return 0
  fi
}

risk_summary_line() {
  # Best effort: report aktualisieren, falls verfügbar.
  set +e
  run_with_timeout "$HEARTBEAT_TASK_TIMEOUT" /home/steges/scripts/skills metrics risk-report >/dev/null 2>&1
  set -e

  python3 - <<'PY' "$STATE_DIR/skill-risk-report.json"
import json
import sys

path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
except Exception:
    print('risk=n/a')
    raise SystemExit(0)

skills = list((data.get('skills') or {}).values())
if not skills:
    print('risk=none')
    raise SystemExit(0)

high = [s for s in skills if float(s.get('risk_score', 0) or 0) >= 70]
medium = [s for s in skills if 40 <= float(s.get('risk_score', 0) or 0) < 70]

top = sorted(skills, key=lambda s: float(s.get('risk_score', 0) or 0), reverse=True)[:3]
top_line = ', '.join(f"{t.get('slug', '?')}({int(float(t.get('risk_score', 0) or 0))})" for t in top)

print(f"high={len(high)}; medium={len(medium)}; top={top_line}")
PY
}

# Entscheidet adaptiv: "live|dry VET_SCORE"
# Regeln (in Priorität):
#  1. Incident-Freeze ON      → dry 70
#  2. >= 3 Canaries in-flight → dry 75
#  3. >= 3 Skills risk >= 70  → dry 80
#  4. >= 1 Skill  risk >= 70  → live 75
#  5. avg rollback_rate > 0.3 → dry 85
#  6. Default                 → live 70
decide_orchestrate_params() {
  local mode="live"
  local vet_score=70

  # 1. Incident-Freeze
  if [[ -f "$STATE_DIR/incident-freeze.json" ]]; then
    local freeze_on
    freeze_on="$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
print('1' if d.get('enabled') else '0')
" "$STATE_DIR/incident-freeze.json" 2>/dev/null || echo 0)"
    if [[ "$freeze_on" == "1" ]]; then
      echo "dry 70"
      return
    fi
  fi

  # 2. Canaries in-flight
  if [[ -f "$STATE_DIR/canary.json" ]]; then
    local running_canaries
    running_canaries="$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
print(sum(1 for v in d.values() if v.get('state')=='running'))
" "$STATE_DIR/canary.json" 2>/dev/null || echo 0)"
    if [[ "$running_canaries" -ge 3 ]]; then
      mode="dry"
      vet_score=75
    fi
  fi

  # 3+4. Risk-Score
  if [[ -f "$STATE_DIR/skill-risk-report.json" ]]; then
    local high_risk
    high_risk="$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
skills=list((d.get('skills') or {}).values())
print(sum(1 for s in skills if float(s.get('risk_score',0) or 0) >= 70))
" "$STATE_DIR/skill-risk-report.json" 2>/dev/null || echo 0)"
    if [[ "$high_risk" -ge 3 ]]; then
      mode="dry"
      vet_score=80
    elif [[ "$high_risk" -ge 1 && "$vet_score" -lt 75 ]]; then
      vet_score=75
    fi
  fi

  # 5. avg_rollback_rate > 0.3
  if [[ -f "$STATE_DIR/metrics-weekly.json" ]]; then
    local avg_rollback
    avg_rollback="$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
print(d.get('avg_rollback_rate', 0))
" "$STATE_DIR/metrics-weekly.json" 2>/dev/null || echo 0)"
    if awk "BEGIN { exit !($avg_rollback > 0.3) }" 2>/dev/null; then
      mode="dry"
      vet_score=85
    fi
  fi

  echo "$mode $vet_score"
}

extract_value() {
  local key="$1"
  local line="$2"
  echo "$line" | tr ';' ' ' | sed -n "s/.*${key}=\([^ ]*\).*/\1/p"
}

weekly_nvme_smart_line() {
  local marker_file="$STATE_DIR/nvme-smart-last-run.ts"
  local now_ts last_ts age_seconds
  now_ts="$(date +%s)"
  last_ts=0

  if [[ -f "$marker_file" ]]; then
    last_ts="$(cat "$marker_file" 2>/dev/null || echo 0)"
  fi
  [[ "$last_ts" =~ ^[0-9]+$ ]] || last_ts=0

  age_seconds=$((now_ts - last_ts))
  if [[ $last_ts -gt 0 && $age_seconds -lt 604800 ]]; then
    local age_days
    age_days=$((age_seconds / 86400))
    echo "NVMe SMART: weekly-check nicht faellig (vor ${age_days}d zuletzt)"
    return 0
  fi

  if ! command -v smartctl >/dev/null 2>&1; then
    log_audit "HEARTBEAT" "-" "nvme-smart skipped smartctl-missing"
    echo "NVMe SMART: smartctl fehlt"
    return 0
  fi

  local output
  output="$(smartctl -a /dev/nvme0n1 2>&1 || true)"
  if command -v sudo >/dev/null 2>&1; then
    if [[ -z "$output" ]] || echo "$output" | grep -Eqi "permission denied|failed:"; then
      output="$(sudo -n smartctl -a /dev/nvme0n1 2>&1 || true)"
    fi
  fi

  if [[ -z "$output" ]]; then
    log_audit "HEARTBEAT" "-" "nvme-smart failed no-output"
    echo "$now_ts" > "$marker_file"
    echo "NVMe SMART: keine Daten lesbar"
    return 0
  fi

  local status="warn"
  if echo "$output" | grep -Eqi "PASSED"; then
    status="passed"
  fi
  if echo "$output" | grep -Eqi "FAILED|CRITICAL"; then
    status="failed"
  fi

  local critical_line temp_line
  critical_line="$(echo "$output" | grep -Eim1 "Critical Warning" | xargs || true)"
  temp_line="$(echo "$output" | grep -Eim1 "Temperature:" | xargs || true)"
  [[ -n "$critical_line" ]] || critical_line="Critical Warning: n/a"
  [[ -n "$temp_line" ]] || temp_line="Temperature: n/a"

  echo "$now_ts" > "$marker_file"
  log_audit "HEARTBEAT" "-" "nvme-smart status=${status} ${critical_line} ${temp_line}"
  echo "NVMe SMART: ${status}; ${critical_line}; ${temp_line}"
}

weekly_shell_tests_line() {
  local marker_file="$STATE_DIR/shell-tests-last-run.ts"
  local now_ts last_ts age_seconds
  now_ts="$(date +%s)"
  last_ts=0

  if [[ -f "$marker_file" ]]; then
    last_ts="$(cat "$marker_file" 2>/dev/null || echo 0)"
  fi
  [[ "$last_ts" =~ ^[0-9]+$ ]] || last_ts=0

  age_seconds=$((now_ts - last_ts))
  if [[ $last_ts -gt 0 && $age_seconds -lt 604800 ]]; then
    local age_days
    age_days=$((age_seconds / 86400))
    echo "Shell-Tests: weekly-run nicht faellig (vor ${age_days}d zuletzt)"
    return 0
  fi

  if ! command -v bats >/dev/null 2>&1; then
    log_audit "HEARTBEAT" "-" "shell-tests skipped bats-missing"
    echo "Shell-Tests: bats fehlt"
    return 0
  fi

  local out rc summary
  set +e
  out="$(run_with_timeout "$HEARTBEAT_TASK_TIMEOUT" bats /home/steges/scripts/tests/health-check.bats /home/steges/scripts/tests/backup.bats 2>&1)"
  rc=$?
  set -e
  summary="$(echo "$out" | tail -n 1 | xargs || true)"
  [[ -n "$summary" ]] || summary="no-summary"

  echo "$now_ts" > "$marker_file"
  if [[ $rc -eq 0 ]]; then
    log_audit "HEARTBEAT" "-" "shell-tests ok ${summary}"
    append_action_log "heartbeat" "weekly_shell_tests" "ok" "heartbeat"
    echo "Shell-Tests: ok; ${summary}"
  else
    log_audit "HEARTBEAT" "-" "shell-tests failed rc=${rc} ${summary}"
    append_action_log "heartbeat" "weekly_shell_tests" "failed(rc=${rc})" "heartbeat"
    echo "Shell-Tests: failed(rc=${rc}); ${summary}"
  fi
}

weekly_scout_line() {
  local marker_file="$STATE_DIR/scout-last-run.ts"
  local now_ts last_ts age_seconds
  now_ts="$(date +%s)"
  last_ts=0

  if [[ -f "$marker_file" ]]; then
    last_ts="$(cat "$marker_file" 2>/dev/null || echo 0)"
  fi
  [[ "$last_ts" =~ ^[0-9]+$ ]] || last_ts=0

  age_seconds=$((now_ts - last_ts))
  if [[ $last_ts -gt 0 && $age_seconds -lt 604800 ]]; then
    local age_days
    age_days=$((age_seconds / 86400))
    echo "Scout: weekly-run nicht faellig (vor ${age_days}d zuletzt)"
    return 0
  fi

  local out rc total pending_review
  set +e
  out="$(run_with_timeout "$HEARTBEAT_TASK_TIMEOUT" /home/steges/scripts/skills scout --dry-run 5 2>&1)"
  rc=$?
  set -e

  echo "$now_ts" > "$marker_file"
  total="$(echo "$out" | sed -n 's/^- total: \([0-9][0-9]*\).*/\1/p' | tail -n 1)"
  pending_review="$(echo "$out" | sed -n 's/^- pending-review: \([0-9][0-9]*\).*/\1/p' | tail -n 1)"
  [[ -n "$total" ]] || total="n/a"
  [[ -n "$pending_review" ]] || pending_review="0"

  local auto_vetted=0
  if [[ $rc -eq 0 ]]; then
    mapfile -t auto_vet_candidates < <(python3 - "$STATE_DIR/known-skills.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
  rows = json.load(f)

for slug, data in sorted(rows.items()):
  try:
    score = float(data.get('scout_score', 0))
  except Exception:
    score = 0
  status = str(data.get('status', ''))
  if status == 'discovered' and score > 7:
    print(slug)
PY
)

    for slug in "${auto_vet_candidates[@]}"; do
      if [[ -z "$slug" ]]; then
        continue
      fi
      set +e
      "/home/steges/agent/skills/skill-forge/scripts/vet.sh" "$slug" 80 >/dev/null 2>&1
      local vet_rc=$?
      set -e
      if [[ $vet_rc -eq 0 ]]; then
        auto_vetted=$((auto_vetted + 1))
        append_action_log "heartbeat" "weekly_scout_auto_vet" "ok(${slug})" "heartbeat"
      else
        append_action_log "heartbeat" "weekly_scout_auto_vet" "failed(${slug},rc=${vet_rc})" "heartbeat"
      fi
    done
  fi

  if [[ $rc -eq 0 ]]; then
    log_audit "HEARTBEAT" "-" "scout weekly dry-run total=${total} pending_review=${pending_review} auto_vetted=${auto_vetted}"
    append_action_log "heartbeat" "weekly_scout_dry_run" "ok(total=${total},pending_review=${pending_review},auto_vetted=${auto_vetted})" "heartbeat"
    if [[ "$pending_review" != "0" ]]; then
      echo "Scout: ok; total=${total}; pending-review=${pending_review}; auto-vetted=${auto_vetted} (interessante Kandidaten vorhanden)"
    else
      echo "Scout: ok; total=${total}; pending-review=${pending_review}; auto-vetted=${auto_vetted}"
    fi
  else
    log_audit "HEARTBEAT" "-" "scout weekly dry-run failed rc=${rc}"
    append_action_log "heartbeat" "weekly_scout_dry_run" "failed(rc=${rc})" "heartbeat"
    echo "Scout: failed(rc=${rc})"
  fi
}

weekly_learnings_line() {
  local marker_file="$STATE_DIR/learnings-last-run.ts"
  local now_ts last_ts age_seconds
  now_ts="$(date +%s)"
  last_ts=0

  if [[ -f "$marker_file" ]]; then
    last_ts="$(cat "$marker_file" 2>/dev/null || echo 0)"
  fi
  [[ "$last_ts" =~ ^[0-9]+$ ]] || last_ts=0

  age_seconds=$((now_ts - last_ts))
  if [[ $last_ts -gt 0 && $age_seconds -lt 604800 ]]; then
    local age_days
    age_days=$((age_seconds / 86400))
    echo "Learnings: weekly-run nicht faellig (vor ${age_days}d zuletzt)"
    return 0
  fi

  local out rc status entry_count first_entry
  set +e
  out="$(run_with_timeout "$HEARTBEAT_TASK_TIMEOUT" /home/steges/scripts/skills learn weekly --json 2>&1)"
  rc=$?
  set -e

  echo "$now_ts" > "$marker_file"

  if [[ $rc -eq 0 ]]; then
    status="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("status", "ok"))' <<< "$out" 2>/dev/null || echo ok)"
    entry_count="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("entry_count", 0))' <<< "$out" 2>/dev/null || echo 0)"
    first_entry="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read()); entries=data.get("entries", []); print(entries[0].get("id", "none") if entries else "none")' <<< "$out" 2>/dev/null || echo none)"
    log_audit "HEARTBEAT" "-" "learn weekly status=${status} entry_count=${entry_count} first=${first_entry}"
    append_action_log "heartbeat" "weekly_learnings" "${status}(entries=${entry_count},first=${first_entry})" "heartbeat"
    echo "Learnings: ${status}; entries=${entry_count}; first=${first_entry}"
  else
    log_audit "HEARTBEAT" "-" "learn weekly failed rc=${rc}"
    append_action_log "heartbeat" "weekly_learnings" "failed(rc=${rc})" "heartbeat"
    echo "Learnings: failed(rc=${rc})"
  fi
}

weekly_vuln_watch_line() {
  local marker_file="$STATE_DIR/vuln-watch-last-run.ts"
  local now_ts last_ts age_seconds
  now_ts="$(date +%s)"
  last_ts=0

  if [[ -f "$marker_file" ]]; then
    last_ts="$(cat "$marker_file" 2>/dev/null || echo 0)"
  fi
  [[ "$last_ts" =~ ^[0-9]+$ ]] || last_ts=0

  age_seconds=$((now_ts - last_ts))
  if [[ $last_ts -gt 0 && $age_seconds -lt 604800 ]]; then
    local age_days
    age_days=$((age_seconds / 86400))
    echo "Vuln-Watch: weekly-run nicht faellig (vor ${age_days}d zuletzt)"
    return 0
  fi

  local out rc new_count
  set +e
  out="$(run_with_timeout "$HEARTBEAT_TASK_TIMEOUT" /home/steges/scripts/skills vuln-watch --weekly --json 2>&1)"
  rc=$?
  set -e

  echo "$now_ts" > "$marker_file"

  if [[ $rc -eq 0 ]]; then
    new_count="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("new_count", 0))' <<< "$out" 2>/dev/null || echo 0)"
    log_audit "HEARTBEAT" "-" "vuln-watch weekly new=${new_count}"
    append_action_log "heartbeat" "vuln_watch_weekly" "ok(new=${new_count})" "heartbeat"
    echo "Vuln-Watch: ok; new=${new_count}"
  else
    log_audit "HEARTBEAT" "-" "vuln-watch weekly failed rc=${rc}"
    append_action_log "heartbeat" "vuln_watch_weekly" "failed(rc=${rc})" "heartbeat"
    echo "Vuln-Watch: failed(rc=${rc})"
  fi
}

should_run_daily_doc_keeper() {
  python3 - "$STATE_DIR/doc-keeper-state.json" <<'PY'
import json
import sys
from datetime import datetime
from zoneinfo import ZoneInfo

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    state = json.load(f)

tz = ZoneInfo('Europe/Berlin')
now = datetime.now(tz)
today = now.strftime('%Y-%m-%d')
last = state.get('last_daily_run', '')

in_window = 6 <= now.hour <= 10
print('1' if in_window and last != today else '0')
PY
}

should_run_weekly_autodoc() {
  local marker_file="$STATE_DIR/autodoc-weekly-last-run.ts"
  local now_ts last_ts age_seconds
  now_ts="$(date +%s)"
  last_ts=0

  if [[ -f "$marker_file" ]]; then
    last_ts="$(cat "$marker_file" 2>/dev/null || echo 0)"
  fi
  [[ "$last_ts" =~ ^[0-9]+$ ]] || last_ts=0

  age_seconds=$((now_ts - last_ts))
  if [[ $last_ts -gt 0 && $age_seconds -lt 604800 ]]; then
    echo 0
  else
    echo 1
  fi
}

run_doc_keeper_autodoc_profile() {
  local profile="$1"
  local reason="$2"
  run_with_timeout "$HEARTBEAT_AUTODOC_TIMEOUT" \
    /home/steges/scripts/skills rag doc-keeper run \
    --summary-only \
    --reason "$reason" \
    --autodoc \
    --autodoc-profile "$profile" \
    --autodoc-provider "$HEARTBEAT_AUTODOC_PROVIDER" \
    --autodoc-model "$HEARTBEAT_AUTODOC_MODEL"
}

GROWBOX_DISPATCH="/home/steges/agent/skills/growbox/scripts/growbox-dispatch.sh"

main(){
  load_dotenv
  ensure_dirs; init_state_files
  ensure_action_log
  echo "openclaw heartbeat"
  local doc_keeper_autorun="${DOC_KEEPER_AUTORUN:-1}"
  local mode="dry"
  local vet_score=70
  local orchestrate_rc=0
  local doc_keeper_daily="no"
  local doc_keeper_weekly="no"
  local growbox_daily_report="no"
  local growbox_diary="no"

  # Selbstüberwachung: Warnung wenn Heartbeat > 30h nicht gelaufen ist
  local hb_marker="$STATE_DIR/heartbeat-last-run.ts"
  if [[ -f "$hb_marker" ]]; then
    local last_hb now_ts elapsed_hb
    last_hb="$(cat "$hb_marker" 2>/dev/null || echo 0)"
    [[ "$last_hb" =~ ^[0-9]+$ ]] || last_hb=0
    now_ts="$(date +%s)"
    elapsed_hb=$(( now_ts - last_hb ))
    if [[ $last_hb -gt 0 && $elapsed_hb -gt 108000 ]]; then
      local overdue_h=$(( elapsed_hb / 3600 ))
      log_audit "HEARTBEAT" "-" "overdue last_run_age=${overdue_h}h"
      record_task_failure "heartbeat-overdue" "zuletzt vor ${overdue_h}h; erwartet alle 12h"
    fi
  fi

  # Adaptive Entscheidung: decide_orchestrate_params gibt "live|dry VET_SCORE" zurück.
  # Explizites --live überschreibt (manueller Aufruf).
  local decided_mode decided_vet
  read -r decided_mode decided_vet < <(decide_orchestrate_params)
  mode="$decided_mode"
  vet_score="$decided_vet"

  if [[ "${1:-}" == "--live" ]]; then
    mode="live"
    # Manuell übergebener vet_score als 3. Arg hat Vorrang
    [[ -n "${3:-}" ]] && vet_score="$3"
  elif [[ "${1:-}" == "--dry" ]]; then
    mode="dry"
    [[ -n "${2:-}" ]] && vet_score="$2"
  fi

  # Context Guard: warnt wenn Session-Context >80% belegt ist
  local context_check
  context_check="$(python3 "$SKILL_DIR/scripts/context-guard.py" \
    "${OPENCLAW_CONTEXT_USED:-0}" "${OPENCLAW_CONTEXT_MAX:-200000}" 2>/dev/null || true)"
  if echo "$context_check" | grep -q "\[ROTATE_NEEDED\]"; then
    log_audit "HEARTBEAT" "-" "context-guard: rotate recommended"
    append_action_log "context-guard" "rotate_recommended" "triggered" "heartbeat"
    send_telegram_heartbeat "⚠️ OpenClaw Context-Rotate: Session nähert sich dem Limit. Bitte neue Session starten und Handover prüfen." || true
  fi

  log_audit "HEARTBEAT" "-" "decision mode=${mode} vet_score=${vet_score}"

  if [[ "$mode" == "live" ]]; then
    set +e
    "/home/steges/agent/skills/skill-forge/scripts/orchestrate.sh" --live "${2:-15}" --vet-score "$vet_score"
    orchestrate_rc=$?
    set -e
    if [[ $orchestrate_rc -eq 0 ]]; then
      log_audit "HEARTBEAT" "-" "run live"
      append_action_log "heartbeat" "orchestrate_live" "success(vet=${vet_score})" "heartbeat"
    else
      log_audit "HEARTBEAT" "-" "run live failed rc=${orchestrate_rc}"
      append_action_log "heartbeat" "orchestrate_live" "failed(rc=${orchestrate_rc})" "heartbeat"
    fi
  else
    set +e
    "/home/steges/agent/skills/skill-forge/scripts/orchestrate.sh" --vet-score "$vet_score"
    orchestrate_rc=$?
    set -e
    if [[ $orchestrate_rc -eq 0 ]]; then
      log_audit "HEARTBEAT" "-" "run dry"
      append_action_log "heartbeat" "orchestrate_dry" "success(vet=${vet_score})" "heartbeat"
    else
      log_audit "HEARTBEAT" "-" "run dry failed rc=${orchestrate_rc}"
      append_action_log "heartbeat" "orchestrate_dry" "failed(rc=${orchestrate_rc})" "heartbeat"
    fi
  fi

  if [[ "$doc_keeper_autorun" == "1" ]]; then
    if [[ "$(should_run_daily_doc_keeper)" == "1" ]]; then
      doc_keeper_daily="yes"
      set +e
      run_doc_keeper_autodoc_profile "daily" "heartbeat-daily" >/dev/null 2>&1
      local doc_keeper_rc=$?
      set -e
      if [[ $doc_keeper_rc -eq 0 ]]; then
        append_action_log "doc-keeper" "daily_run" "triggered" "heartbeat"
      else
        append_action_log "doc-keeper" "daily_run" "failed(rc=${doc_keeper_rc})" "heartbeat"
        log_audit "HEARTBEAT" "-" "doc-keeper daily failed rc=${doc_keeper_rc}"
        record_task_failure "doc-keeper-daily" "rc=${doc_keeper_rc}"
      fi
    fi

    if [[ "$(should_run_weekly_autodoc)" == "1" ]]; then
      doc_keeper_weekly="yes"
      set +e
      run_doc_keeper_autodoc_profile "weekly" "heartbeat-weekly" >/dev/null 2>&1
      local doc_keeper_weekly_rc=$?
      set -e
      if [[ $doc_keeper_weekly_rc -eq 0 ]]; then
        date +%s > "$STATE_DIR/autodoc-weekly-last-run.ts"
        append_action_log "doc-keeper" "weekly_run" "triggered" "heartbeat"
        log_audit "HEARTBEAT" "-" "doc-keeper weekly autodoc ok"
      else
        append_action_log "doc-keeper" "weekly_run" "failed(rc=${doc_keeper_weekly_rc})" "heartbeat"
        log_audit "HEARTBEAT" "-" "doc-keeper weekly failed rc=${doc_keeper_weekly_rc}"
        record_task_failure "doc-keeper-weekly" "rc=${doc_keeper_weekly_rc}"
      fi
    fi
  fi

  set +e
  local diary_out
  diary_out="$(run_with_timeout "$HEARTBEAT_TASK_TIMEOUT" "$GROWBOX_DISPATCH" diary 2>/dev/null)"
  local diary_rc=$?
  set -e
  if [[ $diary_rc -eq 0 ]]; then
    if echo "$diary_out" | grep -q "^CREATED:"; then
      growbox_diary="created"
      append_action_log "growbox" "daily_diary_entry" "created" "heartbeat"
      log_audit "HEARTBEAT" "-" "growbox diary created"
    else
      growbox_diary="present"
    fi
  else
    growbox_diary="error"
    append_action_log "growbox" "daily_diary_entry" "failed" "heartbeat"
    log_audit "HEARTBEAT" "-" "growbox diary failed"
    record_task_failure "growbox-diary" "rc=${diary_rc}"
  fi

  set +e
  run_with_timeout "$HEARTBEAT_TASK_TIMEOUT" "$GROWBOX_DISPATCH" flush-queue >/dev/null 2>&1
  local flush_rc=$?
  set -e
  if [[ $flush_rc -ne 0 ]]; then
    log_audit "HEARTBEAT" "-" "growbox flush-queue failed rc=${flush_rc}"
    record_task_failure "growbox-flush-queue" "rc=${flush_rc}"
  fi

  if [[ "$("$GROWBOX_DISPATCH" should-report 2>/dev/null || echo 0)" == "1" ]]; then
    growbox_daily_report="yes"
    set +e
    run_with_timeout "$HEARTBEAT_TASK_TIMEOUT" "$GROWBOX_DISPATCH" daily-report >/dev/null 2>&1
    local report_rc=$?
    set -e
    if [[ $report_rc -eq 0 ]]; then
      "$GROWBOX_DISPATCH" mark-sent >/dev/null 2>&1 || true
      append_action_log "growbox" "daily_telegram_report" "sent" "heartbeat"
      log_audit "HEARTBEAT" "-" "growbox daily report sent"
    else
      append_action_log "growbox" "daily_telegram_report" "queued" "heartbeat"
      log_audit "HEARTBEAT" "-" "growbox daily report queued rc=${report_rc}"
      record_task_failure "growbox-daily-report" "rc=${report_rc}"
    fi
  fi

  set +e
  run_with_timeout "$HEARTBEAT_TASK_TIMEOUT" /home/steges/scripts/skills metrics weekly >/dev/null 2>&1
  local metrics_weekly_rc=$?
  set -e
  if [[ $metrics_weekly_rc -eq 0 ]]; then
    append_action_log "heartbeat" "metrics_weekly" "updated" "heartbeat"
  else
    append_action_log "heartbeat" "metrics_weekly" "failed(rc=${metrics_weekly_rc})" "heartbeat"
    log_audit "HEARTBEAT" "-" "metrics weekly failed rc=${metrics_weekly_rc}"
    record_task_failure "metrics-weekly" "rc=${metrics_weekly_rc}"
  fi
  local orchestrate_state="ok"
  if [[ $orchestrate_rc -ne 0 ]]; then
    orchestrate_state="failed(rc=${orchestrate_rc})"
  fi
  local status_line
  status_line="$(heartbeat_status_snapshot)"
  local metrics_line
  metrics_line="$(latest_metrics_line)"
  local freeze
  freeze="$(extract_value "freeze" "$status_line")"
  local known
  known="$(extract_value "known" "$status_line")"
  local active
  active="$(extract_value "active" "$status_line")"
  local canary_running
  canary_running="$(extract_value "canary_running" "$status_line")"
  local pending_status
  pending_status="$(extract_value "pending_blacklist_status" "$status_line")"
  local pending_queue
  pending_queue="$(extract_value "pending_blacklist_queue" "$status_line")"

  local run_id
  run_id="$(extract_value "run_id" "$metrics_line")"
  local live
  live="$(extract_value "live" "$metrics_line")"
  local install_success_rate
  install_success_rate="$(extract_value "install_success_rate" "$metrics_line")"
  local rollback_rate
  rollback_rate="$(extract_value "rollback_rate" "$metrics_line")"
  local decision_s
  decision_s="$(extract_value "decision_s" "$metrics_line")"

  freeze="${freeze:-n/a}"
  known="${known:-n/a}"
  active="${active:-n/a}"
  canary_running="${canary_running:-n/a}"
  pending_status="${pending_status:-n/a}"
  pending_queue="${pending_queue:-n/a}"
  run_id="${run_id:-n/a}"
  live="${live:-n/a}"
  install_success_rate="${install_success_rate:-n/a}"
  rollback_rate="${rollback_rate:-n/a}"
  decision_s="${decision_s:-n/a}"

  local message
  local system_line
  system_line="$(system_runtime_line)"
  local audit_line
  audit_line="$(recent_audit_digest_line)"
  local trend_line
  trend_line="$(weekly_trend_line)"
  local risk_line
  risk_line="$(risk_summary_line)"
  local nvme_line
  nvme_line="$(weekly_nvme_smart_line)"
  local shell_tests_line
  shell_tests_line="$(weekly_shell_tests_line)"
  if [[ "$shell_tests_line" == *"failed("* ]]; then
    record_task_failure "shell-tests" "$shell_tests_line"
  fi
  local scout_line
  scout_line="$(weekly_scout_line)"
  if [[ "$scout_line" == *"failed("* ]]; then
    record_task_failure "scout-weekly" "$scout_line"
  fi
  local learnings_line
  learnings_line="$(weekly_learnings_line)"
  if [[ "$learnings_line" == *"failed("* ]]; then
    record_task_failure "learnings-weekly" "$learnings_line"
  fi
  local vuln_watch_line
  vuln_watch_line="$(weekly_vuln_watch_line)"
  if [[ "$vuln_watch_line" == *"failed("* ]]; then
    record_task_failure "vuln-watch-weekly" "$vuln_watch_line"
  fi

  local failure_summary="none"
  if [[ ${#TASK_FAILURES[@]} -gt 0 ]]; then
    failure_summary="$(printf '%s | ' "${TASK_FAILURES[@]}")"
    failure_summary="${failure_summary% | }"
  fi

  message="🫀 OpenClaw Heartbeat (${mode}|vet=${vet_score}) @ $(hostname)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚦 Laufstatus
• Orchestrate: ${orchestrate_state}
• Doc-Keeper Daily: ${doc_keeper_daily}
• Doc-Keeper Weekly: ${doc_keeper_weekly}
• Growbox Report: ${growbox_daily_report}
• Growbox Diary: ${growbox_diary}
• Incident Freeze: ${freeze}

🖥️ System
• ${system_line}
• ${nvme_line}
• ${shell_tests_line}
• ${scout_line}
• ${learnings_line}
• ${vuln_watch_line}

📦 Skills
• Known: ${known} | Active: ${active} | Canary: ${canary_running}
• Pending Blacklist: status=${pending_status}, queue=${pending_queue}

🚨 Risiko
• ${risk_line}

🕒 24h Digest
• ${audit_line}

📈 Trend vs 7d
• ${trend_line}

⚠️ Fehler
• ${failure_summary}

📊 Metrics
• Run: ${run_id} | Live: ${live}
• Install: ${install_success_rate} | Rollback: ${rollback_rate}
• Decision (s): ${decision_s}"

  send_telegram_heartbeat "$message" || true
  append_action_log "heartbeat" "telegram_summary" "sent_or_skipped" "heartbeat"

  # Daily Health Snapshot: Separate Telegram-Nachricht im Morgenfenster (06-10h Berlin)
  local is_morning
  is_morning="$(python3 -c "
from datetime import datetime
from zoneinfo import ZoneInfo
now = datetime.now(ZoneInfo('Europe/Berlin'))
print('1' if 6 <= now.hour <= 10 else '0')
" 2>/dev/null || echo 0)"
  if [[ "$is_morning" == "1" ]]; then
    local daily_health
    daily_health="$("$SKILL_DIR/../pi-control/scripts/status-full.sh" 2>/dev/null || echo "Daily Health: Status-Report fehlgeschlagen")"
    send_telegram_heartbeat "$daily_health" || true
    append_action_log "heartbeat" "daily_health_snapshot" "sent" "heartbeat"
    log_audit "HEARTBEAT" "-" "daily health snapshot sent"
  fi

  # Self-reflection: append a learning entry when anomalies are detected
  local learnings_file="$SKILL_DIR/.learnings/LEARNINGS.md"
  local today_iso
  today_iso="$(date -u +%Y-%m-%d)"
  if [[ $orchestrate_rc -ne 0 ]]; then
    if [[ -f "$learnings_file" ]] && ! grep -q "^## ${today_iso} – Orchestrate fehlgeschlagen" "$learnings_file"; then
      {
        echo ""
        echo "## ${today_iso} – Orchestrate fehlgeschlagen"
        echo ""
        echo "**Was:** Orchestrate-Lauf mit rc=${orchestrate_rc} beendet."
        echo "**Warum wichtig:** Skills wurden nicht korrekt evaluiert; offene Promotions könnten warten."
        echo "**Vorschlag:** Logs prüfen: \`~/scripts/skill-forge audit --rejected\`"
      } >> "$learnings_file"
      append_action_log "heartbeat" "learning_written" "orchestrate_failed" "heartbeat"
    fi
  fi

  if "$CANVAS_OPS_BRIEF_SCRIPT" >/dev/null 2>&1; then
    append_action_log "heartbeat" "canvas_ops_brief" "updated" "heartbeat"
  else
    append_action_log "heartbeat" "canvas_ops_brief" "failed" "heartbeat"
  fi

  if "$CANVAS_STATE_BRIEF_SCRIPT" >/dev/null 2>&1; then
    append_action_log "heartbeat" "canvas_state_brief" "updated" "heartbeat"
  else
    append_action_log "heartbeat" "canvas_state_brief" "failed" "heartbeat"
  fi

  if "$CANVAS_SKILL_PAGES_BRIEF_SCRIPT" >/dev/null 2>&1; then
    append_action_log "heartbeat" "canvas_skill_pages_brief" "updated" "heartbeat"
  else
    append_action_log "heartbeat" "canvas_skill_pages_brief" "failed" "heartbeat"
  fi

  refresh_action_log_canvas_snapshot

  # Last-run-Timestamp schreiben (für Selbstüberwachung / nightly-check)
  date +%s > "$STATE_DIR/heartbeat-last-run.ts"
  append_action_log "heartbeat" "last_run_ts_updated" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "heartbeat"

  echo "OpenClaw heartbeat metrics snapshot:"
  /home/steges/scripts/skills metrics latest
  return "$orchestrate_rc"
}
main "$@"
