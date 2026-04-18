#!/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source "/home/steges/agent/skills/skill-forge/scripts/common.sh"

LEARNINGS_MD="/home/steges/agent/LEARNINGS.md"
LEARNINGS_JSONL="$STATE_DIR/learnings.jsonl"
LEARN_WEEKLY_STATE="$STATE_DIR/learn-weekly.json"
ACTION_LOG="/home/steges/infra/openclaw-data/action-log.jsonl"
KNOWN_SKILLS_PATH="$STATE_DIR/known-skills.json"
RISK_REPORT="$STATE_DIR/skill-risk-report.json"

usage() {
  echo "Usage: learn-dispatch.sh show|observe|search|weekly [--json]|promote <id>|extract <id>"
}

observe() {
  local text="${1:-}"
  [[ -n "$text" ]] || { echo "Usage: learn observe \"<text>\" [--tags a,b]" >&2; exit 2; }
  shift
  local tags=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tags)
        tags="${2:-}"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  python3 - "$LEARNINGS_JSONL" "$LEARNINGS_MD" "$text" "$tags" <<'PY'
import fcntl
import json
import sys
from datetime import datetime, timezone

jsonl_path, md_path, text, tags_raw = sys.argv[1:]
now = datetime.now(timezone.utc)
ts = now.strftime('%Y-%m-%dT%H:%M:%SZ')
entry_id = f"learn-{now.strftime('%Y%m%d%H%M%S')}"
tags = [t.strip() for t in tags_raw.split(',') if t.strip()] if tags_raw else []

entry = {
  "id": entry_id,
  "ts": ts,
  "text": text,
  "tags": tags,
  "source": "observe",
  "promoted": False,
}

lock_path = jsonl_path + '.lock'
with open(lock_path, 'w', encoding='utf-8') as lf:
  fcntl.flock(lf, fcntl.LOCK_EX)
  with open(jsonl_path, 'a', encoding='utf-8') as f:
    f.write(json.dumps(entry, ensure_ascii=True) + '\n')
  fcntl.flock(lf, fcntl.LOCK_UN)

tag_str = f" [{', '.join(tags)}]" if tags else ""
with open(md_path, 'a', encoding='utf-8') as f:
  f.write(f"\n- [{entry_id}] {text}{tag_str}\n")

print(f"observed: {entry_id}")
PY
  log_audit "LEARN" "-" "observe"
}

show_filtered() {
  local tag=""
  local since=""
  local json_mode=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tag)
        tag="${2:-}"
        shift 2
        ;;
      --since)
        since="${2:-}"
        shift 2
        ;;
      --json)
        json_mode=1
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  python3 - "$LEARNINGS_JSONL" "$tag" "$since" "$json_mode" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone, timedelta

jsonl_path, tag, since_str, json_mode = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == '1'
entries = []
if os.path.exists(jsonl_path):
  with open(jsonl_path, encoding='utf-8') as f:
    for line in f:
      line = line.strip()
      if not line:
        continue
      try:
        entries.append(json.loads(line))
      except Exception:
        pass

if since_str:
  try:
    days = int(since_str.rstrip('d'))
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    filtered = []
    for e in entries:
      ts = e.get('ts', '')
      dt = datetime.strptime(ts, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
      if dt >= cutoff:
        filtered.append(e)
    entries = filtered
  except Exception:
    pass

if tag:
  entries = [e for e in entries if tag in e.get('tags', [])]

if json_mode:
  print(json.dumps(entries, ensure_ascii=True, indent=2))
else:
  for e in entries:
    tag_str = f" [{', '.join(e.get('tags', []))}]" if e.get('tags') else ''
    prom = ' [promoted]' if e.get('promoted') else ''
    print(f"- [{e.get('id', '?')}] {e.get('ts', '')} {e.get('text', '')}{tag_str}{prom}")
PY
}

search_learn() {
  local query="${1:-}"
  local json_mode=0
  [[ "${2:-}" == "--json" ]] && json_mode=1
  [[ -n "$query" ]] || { echo "Usage: learn search \"<keyword>\" [--json]" >&2; exit 2; }

  python3 - "$LEARNINGS_JSONL" "$query" "$json_mode" <<'PY'
import json
import os
import sys

jsonl_path, query, json_mode = sys.argv[1], sys.argv[2].lower(), sys.argv[3] == '1'
entries = []
if os.path.exists(jsonl_path):
  with open(jsonl_path, encoding='utf-8') as f:
    for line in f:
      line = line.strip()
      if not line:
        continue
      try:
        e = json.loads(line)
      except Exception:
        continue
      text = e.get('text', '').lower()
      tags = [str(t).lower() for t in e.get('tags', [])]
      if query in text or any(query in t for t in tags):
        entries.append(e)

if json_mode:
  print(json.dumps(entries, ensure_ascii=True, indent=2))
else:
  for e in entries:
    print(f"- [{e.get('id', '?')}] {e.get('text', '')}")
print(f"# {len(entries)} match(es) for '{query}'", file=sys.stderr)
PY
}

weekly() {
  local json_mode=0
  [[ "${1:-}" == "--json" ]] && json_mode=1

  local result
  result="$(python3 - "$LEARNINGS_MD" "$AUDIT_LOG" "$ACTION_LOG" "$KNOWN_SKILLS_PATH" "$RISK_REPORT" "$LEARN_WEEKLY_STATE" "$LEARNINGS_JSONL" "$json_mode" <<'PY'
import json
import os
import sys
import tempfile
from collections import Counter
from datetime import datetime, timedelta, timezone
import fcntl

learn_path, audit_path, action_path, known_path, risk_path, state_path, jsonl_path, json_mode = sys.argv[1:9]
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

lock_path = jsonl_path + '.lock'
with open(lock_path, 'w', encoding='utf-8') as lf:
  fcntl.flock(lf, fcntl.LOCK_EX)
  with open(jsonl_path, 'a', encoding='utf-8') as jf:
    for entry in entries:
      jf.write(json.dumps({
        'id': entry['id'],
        'ts': now.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'text': entry['summary'],
        'tags': ['weekly-distill'],
        'source': 'weekly-distill',
        'promoted': False,
      }, ensure_ascii=True) + '\n')
  fcntl.flock(lf, fcntl.LOCK_UN)

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
)"

  if [[ "$json_mode" == "1" ]]; then
    echo "$result"
  else
    python3 - <<'PY' "$result"
import json, sys
data = json.loads(sys.argv[1])
if data.get('status') == 'skipped':
    print(f"Weekly learnings: skipped; week={data.get('week_key')}; entries={len(data.get('entries', []))}")
else:
    entries = data.get('entries', [])
    first = entries[0].get('id') if entries else 'none'
    print(f"Weekly learnings: ok; week={data.get('week_key')}; entries={len(entries)}; first={first}")
PY
  fi
}

promote() {
  local id="${1:-}"
  [[ -n "$id" ]] || { echo "Usage: learn promote <id>" >&2; exit 2; }

  python3 - "$LEARNINGS_JSONL" "$id" <<'PY'
import json
import os
import sys
import tempfile

jsonl_path, target_id = sys.argv[1], sys.argv[2]
if not os.path.exists(jsonl_path):
  print(f"ERROR: {jsonl_path} not found", file=sys.stderr)
  raise SystemExit(1)

entries = []
found = False
with open(jsonl_path, encoding='utf-8') as f:
  for line in f:
    line = line.strip()
    if not line:
      continue
    try:
      e = json.loads(line)
    except Exception:
      continue
    if e.get('id') == target_id:
      e['promoted'] = True
      found = True
    entries.append(e)

if not found:
  print(f"ERROR: id {target_id} not found", file=sys.stderr)
  raise SystemExit(1)

fd, tmp = tempfile.mkstemp(prefix='.tmp-', suffix='.jsonl', dir=os.path.dirname(jsonl_path))
try:
  with os.fdopen(fd, 'w', encoding='utf-8') as f:
    for e in entries:
      f.write(json.dumps(e, ensure_ascii=True) + '\n')
    f.flush()
    os.fsync(f.fileno())
  os.replace(tmp, jsonl_path)
finally:
  if os.path.exists(tmp):
    os.unlink(tmp)

print(f"promoted: {target_id}")
PY
  log_audit "LEARN" "-" "promote id=$id"
}

main(){
  ensure_dirs; init_state_files
  [[ -f "$LEARNINGS_JSONL" ]] || : > "$LEARNINGS_JSONL"

  local old_learnings="$SM_ROOT/.learnings/LEARNINGS.md"
  if [[ -f "$old_learnings" && ! -f "$LEARNINGS_MD" ]]; then
    cp "$old_learnings" "$LEARNINGS_MD"
  fi
  [[ -f "$LEARNINGS_MD" ]] || printf '# LEARNINGS\n' > "$LEARNINGS_MD"

  local sub="${1:-show}"
  case "$sub" in
    show)
      shift
      show_filtered "$@"
      ;;
    observe)
      shift
      observe "$@"
      ;;
    search)
      shift
      search_learn "$@"
      ;;
    weekly)
      shift
      weekly "$@"
      log_audit "LEARN" "-" "weekly-distill"
      ;;
    promote)
      [[ $# -eq 2 ]] || { echo "Usage: learn-dispatch.sh promote <id>"; exit 2; }
      promote "$2"
      ;;
    extract)
      [[ $# -eq 2 ]] || { echo "Usage: learn-dispatch.sh extract <id>"; exit 2; }
      "$SM_ROOT/scripts/author-skill.sh" "learning-$2" --mode scratch --reason "learning extraction $2" >/dev/null
      log_audit "LEARN" "-" "extract id=$2"
      echo "Extracted learning as skill: learning-$2"
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}
main "$@"
