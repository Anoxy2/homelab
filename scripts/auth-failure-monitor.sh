#!/bin/bash
set -euo pipefail

HOURS=24
JSON=0
THRESHOLD=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hours)
      HOURS="${2:-24}"
      shift 2
      ;;
    --threshold)
      THRESHOLD="${2:-5}"
      shift 2
      ;;
    --json)
      JSON=1
      shift
      ;;
    *)
      echo "Usage: auth-failure-monitor.sh [--hours N] [--threshold N] [--json]" >&2
      exit 2
      ;;
  esac
done

[[ "$HOURS" =~ ^[0-9]+$ ]] || { echo "Invalid --hours" >&2; exit 2; }
[[ "$THRESHOLD" =~ ^[0-9]+$ ]] || { echo "Invalid --threshold" >&2; exit 2; }

python3 - "$HOURS" "$THRESHOLD" "$JSON" <<'PY'
import json
import re
import subprocess
import sys
from datetime import datetime, timezone

hours = int(sys.argv[1])
threshold = int(sys.argv[2])
json_mode = sys.argv[3] == '1'

services = [
    'openclaw',
    'mosquitto',
    'homeassistant',
    'grafana',
    'pihole',
    'caddy',
]

patterns = [
    r'auth(entication)? failed',
    r'unauthori[sz]ed',
    r'invalid token',
    r'invalid user',
    r'login failed',
    r'forbidden',
    r'\b401\b',
    r'\b403\b',
]
rx = re.compile('|'.join(patterns), re.IGNORECASE)

counts = {s: 0 for s in services}
hits = []

for svc in services:
    cmd = ['docker', 'compose', 'logs', '--since', f'{hours}h', svc]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except Exception:
        continue
    text = (proc.stdout or '') + '\n' + (proc.stderr or '')
    for line in text.splitlines():
        if rx.search(line):
            counts[svc] += 1
            if len(hits) < 30:
                hits.append({'service': svc, 'line': line[:240]})

total = sum(counts.values())
status = 'ok' if total < threshold else 'alert'
payload = {
    'generated_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'window_hours': hours,
    'threshold': threshold,
    'status': status,
    'total_matches': total,
    'counts': counts,
    'sample_hits': hits,
}

if json_mode:
    print(json.dumps(payload, ensure_ascii=True, indent=2))
else:
    print(f"Auth Failure Monitor ({hours}h)")
    print(f"- status: {status}")
    print(f"- threshold: {threshold}")
    print(f"- total_matches: {total}")
    for svc in services:
        print(f"- {svc}: {counts[svc]}")

if status == 'alert':
    raise SystemExit(1)
PY
