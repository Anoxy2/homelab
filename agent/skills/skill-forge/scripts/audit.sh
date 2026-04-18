#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

main() {
  ensure_dirs
  init_state_files

  if [[ "${1:-}" == "--top-failures" ]]; then
  python3 - "$AUDIT_LOG" <<'PY'
import json
import os
import collections
import sys

counter = collections.Counter()

for path in sys.argv[1:]:
  if not os.path.exists(path):
    continue
  with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    for raw in f:
      line = raw.strip()
      if not line:
        continue
      if line.startswith('{'):
        try:
          obj = json.loads(line)
        except json.JSONDecodeError:
          continue
        if str(obj.get('result', '')).lower() == 'failed':
          counter[str(obj.get('command', 'UNKNOWN')).upper()] += 1
      else:
        parts = [p.strip() for p in line.split('|', 3)]
        if len(parts) < 4:
          continue
        action, msg = parts[1].upper(), parts[3].lower()
        if action in {'REJECT', 'CONTRACT', 'ROLLBACK'} or ' failed ' in f" {msg} ":
          counter[action] += 1

for action, count in counter.most_common(10):
  print(f"{action}\t{count}")
PY
  exit 0
  fi

  if [[ "${1:-}" == "--blocked-promotions" ]]; then
  python3 - "$AUDIT_LOG" <<'PY'
import json
import os
import sys

count = 0

for path in sys.argv[1:]:
  if not os.path.exists(path):
    continue
  with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    for raw in f:
      line = raw.strip()
      if not line:
        continue
      if line.startswith('{'):
        try:
          obj = json.loads(line)
        except json.JSONDecodeError:
          continue
        cmd = str(obj.get('command', '')).upper()
        msg = str(obj.get('message', '')).lower()
        if cmd in {'CANARY', 'ORCHESTRATE'} and 'blocked' in msg:
          count += 1
      else:
        low = line.lower()
        if ('canary' in low or 'orchestrate' in low) and 'blocked' in low:
          count += 1

print(count)
PY
  exit 0
  fi

  if [[ "${1:-}" == "--frequent-rejects" ]]; then
  python3 - "$AUDIT_LOG" <<'PY'
import json
import os
import collections
import sys

counter = collections.Counter()

for path in sys.argv[1:]:
  if not os.path.exists(path):
    continue
  with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    for raw in f:
      line = raw.strip()
      if not line:
        continue
      if line.startswith('{'):
        try:
          obj = json.loads(line)
        except json.JSONDecodeError:
          continue
        if str(obj.get('command', '')).upper() == 'REJECT':
          target = str(obj.get('target', '-')).strip() or '-'
          counter[target] += 1
      else:
        parts = [p.strip() for p in line.split('|', 3)]
        if len(parts) >= 3 and parts[1].upper() == 'REJECT':
          target = parts[2] or '-'
          counter[target] += 1

for target, count in counter.most_common(20):
  print(f"{target}\t{count}")
PY
  exit 0
  fi

  if [[ "${1:-}" == "--ebusy-baseline" ]]; then
  local hours="${2:-24}"
  python3 - "$AUDIT_LOG" "$hours" <<'PY'
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone

paths = [sys.argv[1]]
hours = int(sys.argv[2])
cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)

total = 0
ebusy = 0

for path in paths:
  if not os.path.exists(path):
    continue
  with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    for raw in f:
      line = raw.strip()
      if not line:
        continue

      ts = None
      message = ""
      if line.startswith('{'):
        try:
          obj = json.loads(line)
        except json.JSONDecodeError:
          continue
        ts = obj.get('ts', '')
        message = str(obj.get('message', ''))
      else:
        parts = [p.strip() for p in line.split('|', 3)]
        if len(parts) < 4:
          continue
        ts = parts[0]
        message = parts[3]

      try:
        dt = datetime.strptime(ts, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
      except Exception:
        continue
      if dt < cutoff:
        continue

      total += 1
      if re.search(r'\bebusy\b', message, re.IGNORECASE):
        ebusy += 1

rate = (ebusy / total) if total else 0.0
print(json.dumps({
  'window_hours': hours,
  'audit_events': total,
  'ebusy_events': ebusy,
  'ebusy_rate': round(rate, 6)
}, ensure_ascii=True, indent=2))
PY
  exit 0
  fi

  if [[ "${1:-}" == "--rejected" ]]; then
  python3 - "$AUDIT_LOG" <<'PY'
import json
import os
import sys

for path in sys.argv[1:]:
  if not os.path.exists(path):
    continue
  with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    for idx, raw in enumerate(f, start=1):
      line = raw.strip()
      if not line:
        continue
      if line.startswith('{'):
        try:
          obj = json.loads(line)
        except json.JSONDecodeError:
          continue
        action = str(obj.get('command', '')).upper()
        if action == 'REJECT':
          print(f"{path}:{idx}:{line}")
      else:
        parts = [p.strip() for p in line.split('|', 3)]
        if len(parts) >= 2 and parts[1] == 'REJECT':
          print(f"{path}:{idx}:{line}")
PY
    exit 0
  fi

  local limit="${2:-80}"
  python3 - "$AUDIT_LOG" "$limit" <<'PY'
import os
import sys

paths = [sys.argv[1]]
limit = int(sys.argv[2])
lines = []

for path in paths:
  if not os.path.exists(path):
    continue
  with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    for raw in f:
      line = raw.rstrip('\n')
      if line.strip():
        lines.append(line)

for row in lines[-limit:]:
  print(row)
PY
}

main "$@"
