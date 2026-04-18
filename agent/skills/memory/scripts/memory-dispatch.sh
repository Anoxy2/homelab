#!/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source "/home/steges/agent/skills/skill-forge/scripts/common.sh"

MEMORY_JSONL="$STATE_DIR/memory.jsonl"
MEMORY_MD="/home/steges/agent/MEMORY.md"
REINDEX_SCRIPT="/home/steges/agent/skills/openclaw-rag/scripts/reindex.sh"

usage() {
  echo "Usage: memory-dispatch.sh remember|recall|search|forget|update|ingest|stats"
}

_migrate_if_empty() {
  [[ -s "$MEMORY_JSONL" ]] && return 0
  [[ -f "$MEMORY_MD" ]] || return 0

  python3 - "$MEMORY_JSONL" "$MEMORY_MD" <<'PY'
import json
import sys
from datetime import datetime, timezone

jsonl_path, md_path = sys.argv[1], sys.argv[2]
with open(md_path, encoding='utf-8') as f:
  raw = f.read().strip()
if not raw:
  raise SystemExit(0)

ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
entry = {
  "id": "mem-migration-00",
  "ts": ts,
  "text": raw,
  "cat": "fact",
  "tags": ["migrated"],
  "actor": "system",
}
with open(jsonl_path, 'a', encoding='utf-8') as f:
  f.write(json.dumps(entry, ensure_ascii=True) + '\n')
print("migrated existing MEMORY.md as mem-migration-00")
PY
}

remember() {
  local text="${1:-}"
  [[ -n "$text" ]] || { echo "Usage: memory remember \"<text>\" [--cat <cat>] [--tags x,y] [--actor <actor>]" >&2; exit 2; }
  shift

  local cat="fact"
  local tags=""
  local actor="openclaw"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cat)
        cat="${2:-}"
        shift 2
        ;;
      --tags)
        tags="${2:-}"
        shift 2
        ;;
      --actor)
        actor="${2:-}"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  python3 - "$MEMORY_JSONL" "$text" "$cat" "$tags" "$actor" <<'PY'
import fcntl
import json
import sys
from datetime import datetime, timezone

jsonl_path, text, cat, tags_raw, actor = sys.argv[1:]
valid_cats = {"decision", "pattern", "config", "incident", "fact"}
if cat not in valid_cats:
  print(f"ERROR: unknown cat '{cat}', valid: {sorted(valid_cats)}", file=sys.stderr)
  raise SystemExit(2)

now = datetime.now(timezone.utc)
entry_id = "mem-" + now.strftime('%Y%m%d-%H%M%S')
ts = now.strftime('%Y-%m-%dT%H:%M:%SZ')
tags = [t.strip() for t in tags_raw.split(',') if t.strip()] if tags_raw else []
entry = {
  "id": entry_id,
  "ts": ts,
  "text": text,
  "cat": cat,
  "tags": tags,
  "actor": actor,
}

lock_path = jsonl_path + '.lock'
with open(lock_path, 'w', encoding='utf-8') as lf:
  fcntl.flock(lf, fcntl.LOCK_EX)
  with open(jsonl_path, 'a', encoding='utf-8') as f:
    f.write(json.dumps(entry, ensure_ascii=True) + '\n')
  fcntl.flock(lf, fcntl.LOCK_UN)

print(f"remembered: {entry_id}")
PY
  log_audit "MEMORY" "-" "remember cat=$cat"
}

recall() {
  local cat=""
  local tag=""
  local since=""
  local json_mode=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cat)
        cat="${2:-}"
        shift 2
        ;;
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

  python3 - "$MEMORY_JSONL" "$cat" "$tag" "$since" "$json_mode" <<'PY'
import json
import os
import sys
from datetime import datetime, timedelta, timezone

jsonl_path, cat, tag, since_str, json_mode = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5] == '1'
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

if cat:
  entries = [e for e in entries if e.get('cat') == cat]
if tag:
  entries = [e for e in entries if tag in e.get('tags', [])]

if json_mode:
  print(json.dumps(entries, ensure_ascii=True, indent=2))
else:
  for e in entries:
    tag_str = f" [{', '.join(e.get('tags', []))}]" if e.get('tags') else ""
    print(f"- [{e.get('id', '?')}] ({e.get('cat', '?')}) {e.get('text', '')}{tag_str}")
PY
}

mem_search() {
  local query="${1:-}"
  local json_mode=0
  [[ "${2:-}" == "--json" ]] && json_mode=1
  [[ -n "$query" ]] || { echo "Usage: memory search \"<query>\" [--json]" >&2; exit 2; }

  python3 - "$MEMORY_JSONL" "$query" "$json_mode" <<'PY'
import json
import os
import sys

jsonl_path, query, json_mode = sys.argv[1], sys.argv[2].lower(), sys.argv[3] == '1'
hits = []
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
        hits.append(e)

if json_mode:
  print(json.dumps(hits, ensure_ascii=True, indent=2))
else:
  for e in hits:
    print(f"- [{e.get('id', '?')}] ({e.get('cat', '?')}) {e.get('text', '')}")
print(f"# {len(hits)} match(es)", file=sys.stderr)
PY
}

forget() {
  local id="${1:-}"
  [[ -n "$id" ]] || { echo "Usage: memory forget <id>" >&2; exit 2; }

  python3 - "$MEMORY_JSONL" "$id" <<'PY'
import json
import os
import sys
import tempfile

jsonl_path, target_id = sys.argv[1], sys.argv[2]
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
      found = True
      continue
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
print(f"forgotten: {target_id}")
PY
  log_audit "MEMORY" "-" "forget id=$id"
}

mem_update() {
  local id="${1:-}"
  local new_text="${2:-}"
  [[ -n "$id" && -n "$new_text" ]] || { echo "Usage: memory update <id> \"<new text>\"" >&2; exit 2; }

  python3 - "$MEMORY_JSONL" "$id" "$new_text" <<'PY'
import json
import os
import sys
import tempfile
from datetime import datetime, timezone

jsonl_path, target_id, new_text = sys.argv[1], sys.argv[2], sys.argv[3]
entries = []
found = False
ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
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
      e['text'] = new_text
      e['updated_at'] = ts
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
print(f"updated: {target_id}")
PY
  log_audit "MEMORY" "-" "update id=$id"
}

mem_ingest() {
  python3 - "$MEMORY_JSONL" "$MEMORY_MD" <<'PY'
import json
import os
import sys
import tempfile
from collections import defaultdict

jsonl_path, md_path = sys.argv[1], sys.argv[2]
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

by_cat = defaultdict(list)
for e in entries:
  by_cat[e.get('cat', 'fact')].append(e)

lines = [
  '# Memory\n',
  f"_Generated from memory.jsonl - {len(entries)} entries_\n",
]
cat_order = ['decision', 'pattern', 'config', 'incident', 'fact']
for cat in cat_order:
  if cat not in by_cat:
    continue
  lines.append(f"\n## {cat.capitalize()}\n")
  for e in by_cat[cat]:
    tag_str = f" [{', '.join(e.get('tags', []))}]" if e.get('tags') else ''
    lines.append(f"- [{e.get('id', '?')}] {e.get('text', '')}{tag_str}\n")

fd, tmp = tempfile.mkstemp(prefix='.tmp-', suffix='.md', dir=os.path.dirname(md_path))
try:
  with os.fdopen(fd, 'w', encoding='utf-8') as f:
    f.writelines(lines)
    f.flush()
    os.fsync(f.fileno())
  os.replace(tmp, md_path)
finally:
  if os.path.exists(tmp):
    os.unlink(tmp)

print(f"regenerated MEMORY.md ({len(entries)} entries)")
PY

  if [[ -x "$REINDEX_SCRIPT" ]]; then
    "$REINDEX_SCRIPT"
    log_audit "MEMORY" "-" "ingest reindex"
    echo "reindex complete"
  else
    echo "WARN: reindex.sh not found at $REINDEX_SCRIPT" >&2
  fi
}

mem_stats() {
  local json_mode=0
  [[ "${1:-}" == "--json" ]] && json_mode=1

  python3 - "$MEMORY_JSONL" "$json_mode" <<'PY'
import json
import os
import sys
from collections import Counter

jsonl_path, json_mode = sys.argv[1], sys.argv[2] == '1'
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

counts = Counter(e.get('cat', '?') for e in entries)
if json_mode:
  print(json.dumps({"total": len(entries), "by_cat": dict(counts)}, ensure_ascii=True, indent=2))
else:
  print(f"Total: {len(entries)}")
  for cat, count in sorted(counts.items()):
    print(f"  {cat}: {count}")
PY
}

main() {
  ensure_dirs
  init_state_files
  [[ -f "$MEMORY_JSONL" ]] || : > "$MEMORY_JSONL"
  _migrate_if_empty

  local sub="${1:-}"
  case "$sub" in
    remember)
      shift
      remember "$@"
      ;;
    recall)
      shift
      recall "$@"
      ;;
    search)
      shift
      mem_search "$@"
      ;;
    forget)
      shift
      forget "${1:-}"
      ;;
    update)
      shift
      mem_update "${1:-}" "${2:-}"
      ;;
    ingest)
      mem_ingest
      ;;
    stats)
      shift
      mem_stats "${1:-}"
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

main "$@"
