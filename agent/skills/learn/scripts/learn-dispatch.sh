#!/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source "/home/steges/agent/skills/skill-forge/scripts/common.sh"

LEARN="$SM_ROOT/.learnings/LEARNINGS.md"
ACTION_LOG="/home/steges/infra/openclaw-data/action-log.jsonl"
KNOWN_SKILLS_PATH="$STATE_DIR/known-skills.json"
RISK_REPORT="$STATE_DIR/skill-risk-report.json"
LEARN_WEEKLY_STATE="$STATE_DIR/learn-weekly.json"
mkdir -p "$SM_ROOT/.learnings"
[[ -f "$LEARN" ]] || cat > "$LEARN" <<'EOF'
# LEARNINGS
EOF

usage() {
  echo "Usage: learn-dispatch.sh show|weekly [--json]|promote <id>|extract <id>"
}

weekly() {
  local json_mode=0
  [[ "${1:-}" == "--json" ]] && json_mode=1

  python3 - "$LEARN" "$AUDIT_LOG" "$ACTION_LOG" "$KNOWN_SKILLS_PATH" "$RISK_REPORT" "$LEARN_WEEKLY_STATE" "$json_mode" <<'PY'
import json
import os
import sys
import tempfile
from collections import Counter
from datetime import datetime, timedelta, timezone

learn_path, audit_path, action_path, known_path, risk_path, state_path, json_mode = sys.argv[1:8]
json_mode = json_mode == '1'
now = datetime.now(timezone.utc)
week_key = now.strftime('%G-W%V')
window_start = now - timedelta(days=7)

def read_json(path, default):
  try:
    with open(path, 'r', encoding='utf-8') as f:
      return json.load(f)
  except Exception:
    return default

def write_json_atomic(path, payload):
  os.makedirs(os.path.dirname(path), exist_ok=True)
  fd, tmp = tempfile.mkstemp(prefix='.tmp-', suffix='.json', dir=os.path.dirname(path))
  try:
    with os.fdopen(fd, 'w', encoding='utf-8') as f:
      json.dump(payload, f, ensure_ascii=True, indent=2)
      f.flush()
      os.fsync(f.fileno())
    os.replace(tmp, path)
  finally:
    if os.path.exists(tmp):
      os.unlink(tmp)

state = read_json(state_path, {})
if state.get('last_week_key') == week_key:
  result = {
    'status': 'skipped',
    'reason': 'already_distilled_this_week',
    'week_key': week_key,
    'entries': state.get('last_entry_ids', []),
  }
  if json_mode:
    print(json.dumps(result, ensure_ascii=True, indent=2))
  else:
    print(f"Weekly learnings: skipped; week={week_key}; entries={len(result['entries'])}")
  raise SystemExit(0)

known = read_json(known_path, {})
risk = read_json(risk_path, {})
pending_review = sorted(
  slug for slug, row in known.items()
  if str(row.get('status', '')) == 'pending-review'
)

audit_failures = Counter()
if os.path.exists(audit_path):
  with open(audit_path, 'r', encoding='utf-8', errors='ignore') as f:
    for raw in f:
      raw = raw.strip()
      if not raw:
        continue
      try:
        obj = json.loads(raw)
      except json.JSONDecodeError:
        continue
      ts = obj.get('ts') or obj.get('timestamp')
      try:
        dt = datetime.strptime(ts, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
      except Exception:
        continue
      if dt < window_start:
        continue
      cmd = str(obj.get('command', obj.get('action', 'unknown'))).lower()
      msg = str(obj.get('message', '')).lower()
      if any(token in msg for token in ('failed', 'blocked', 'timeout', 'reject', 'error', 'rc=')) or cmd in ('reject', 'rollback', 'fail', 'error'):
        audit_failures[cmd] += 1

action_failures = Counter()
if os.path.exists(action_path):
  with open(action_path, 'r', encoding='utf-8', errors='ignore') as f:
    for raw in f:
      raw = raw.strip()
      if not raw:
        continue
      try:
        obj = json.loads(raw)
      except json.JSONDecodeError:
        continue
      ts = obj.get('ts')
      try:
        dt = datetime.strptime(ts, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
      except Exception:
        continue
      if dt < window_start:
        continue
      result = str(obj.get('result', '')).lower()
      action = str(obj.get('action', 'unknown')).lower()
      if 'failed' in result or 'timeout' in result:
        action_failures[action] += 1

top_risks = []
for slug, row in (risk.get('skills') or {}).items():
  try:
    score = int(row.get('risk_score', 0))
  except Exception:
    score = 0
  if score >= 50:
    top_risks.append((slug, score, str(row.get('status', 'unknown'))))
top_risks.sort(key=lambda item: item[1], reverse=True)

suggestions = []
if action_failures:
  action, count = action_failures.most_common(1)[0]
  suggestions.append(f"Haerte den Pfad '{action}' ab: {count} fehlgeschlagene Action-Events in den letzten 7 Tagen.")
if audit_failures:
  cmd, count = audit_failures.most_common(1)[0]
  suggestions.append(f"Pruefe die Fehlerklasse '{cmd}': {count} auffaellige Audit-Events in den letzten 7 Tagen.")
if pending_review:
  preview = ', '.join(pending_review[:3])
  suffix = '' if len(pending_review) <= 3 else f" (+{len(pending_review) - 3} weitere)"
  suggestions.append(f"Baue Pending-Review-Backlog ab: {len(pending_review)} Skills warten auf Review ({preview}{suffix}).")
if top_risks:
  slug, score, status = top_risks[0]
  suggestions.append(f"Priorisiere Risikoabbau fuer '{slug}' (risk_score={score}, status={status}).")
if not suggestions:
  suggestions.append('Keine dominanten Ausfallmuster erkannt; Fokus auf Canary-Reife, Backup-Restore und Policy-Gates beibehalten.')

date_key = now.strftime('%Y%m%d')
entries = []
for idx, text in enumerate(suggestions[:4], start=1):
  entry_id = f'learn-{date_key}-{idx:02d}'
  entries.append({'id': entry_id, 'summary': text})

section_lines = [
  '',
  f'## Weekly Distill {now.strftime("%Y-%m-%d")}',
  f'- week_key: {week_key}',
  f'- window_days: 7',
]
for entry in entries:
  section_lines.append(f"- [{entry['id']}] {entry['summary']}")

with open(learn_path, 'a', encoding='utf-8') as f:
  f.write('\n'.join(section_lines) + '\n')

state = {
  'last_week_key': week_key,
  'last_run_at': now.strftime('%Y-%m-%dT%H:%M:%SZ'),
  'last_entry_ids': [entry['id'] for entry in entries],
}
write_json_atomic(state_path, state)

result = {
  'status': 'ok',
  'week_key': week_key,
  'entry_count': len(entries),
  'entries': entries,
  'signals': {
    'pending_review_count': len(pending_review),
    'top_audit_failure': audit_failures.most_common(1),
    'top_action_failure': action_failures.most_common(1),
    'top_risk': top_risks[:1],
  },
}
if json_mode:
  print(json.dumps(result, ensure_ascii=True, indent=2))
else:
  first = entries[0]['id'] if entries else 'none'
  print(f"Weekly learnings: ok; week={week_key}; entries={len(entries)}; first={first}")
PY
}

main(){
  ensure_dirs; init_state_files
  local sub="${1:-show}"
  case "$sub" in
    show)
      cat "$LEARN"
      ;;
  weekly)
    shift
    weekly "$@"
    log_audit "LEARN" "-" "weekly-distill"
    ;;
    promote)
      [[ $# -eq 2 ]] || { echo "Usage: learn-dispatch.sh promote <id>"; exit 1; }
      echo "- promoted learning id=$2 at $(now_iso)" >> "$LEARN"
      log_audit "LEARN" "-" "promote id=$2"
      echo "Promoted learning: $2"
      ;;
    extract)
      [[ $# -eq 2 ]] || { echo "Usage: learn-dispatch.sh extract <id>"; exit 1; }
      # extract delegiert an authoring-skill via skill-forge author-skill.sh (lifecycle)
      "$SM_ROOT/scripts/author-skill.sh" "learning-$2" --mode scratch --reason "learning extraction $2" >/dev/null
      log_audit "LEARN" "-" "extract id=$2"
      echo "Extracted learning as skill: learning-$2"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}
main "$@"
