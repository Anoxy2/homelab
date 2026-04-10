#!/bin/bash
set -euo pipefail

ENV_FILE="/home/steges/.env"
OUT_MD="/home/steges/docs/monitoring/time-series-baseline.md"
OUT_JSON="/home/steges/infra/openclaw-data/time-series-baseline.json"
HA_URL_DEFAULT="http://192.168.2.101:8123"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

HA_BASE="${HA_URL:-$HA_URL_DEFAULT}"
HA_TOKEN_VALUE="${HA_TOKEN:-}"

if [[ -z "$HA_TOKEN_VALUE" ]]; then
  echo "HA_TOKEN missing in $ENV_FILE" >&2
  exit 1
fi

python3 - "$HA_BASE" "$HA_TOKEN_VALUE" "$OUT_MD" "$OUT_JSON" <<'PY'
import json
import os
import time
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
import tempfile
import sys

base_url = sys.argv[1].rstrip('/')
token = sys.argv[2]
out_md = sys.argv[3]
out_json = sys.argv[4]

preferred_entities = [
    'sensor.growbox_temperatur',
    'sensor.growbox_luftfeuchtigkeit',
    'sensor.raspberry_pi_cpu_temperature',
]
windows = [
    ('24h', timedelta(hours=24)),
    ('7d', timedelta(days=7)),
    ('30d', timedelta(days=30)),
]

def atomic_write(path: str, content: str):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.tmp-', dir=os.path.dirname(path))
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            f.write(content)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)

states_req = urllib.request.Request(f"{base_url}/api/states")
states_req.add_header('Authorization', f'Bearer {token}')
states_req.add_header('Content-Type', 'application/json')
with urllib.request.urlopen(states_req, timeout=30) as resp:
    all_states = json.loads(resp.read().decode('utf-8', errors='ignore'))

available_sensors = [s.get('entity_id', '') for s in all_states if str(s.get('entity_id', '')).startswith('sensor.')]
entities = [e for e in preferred_entities if e in available_sensors]
if not entities:
    entities = available_sensors[:3]

results = []
for label, delta in windows:
    start_dt = datetime.now(timezone.utc) - delta
    start = start_dt.strftime('%Y-%m-%dT%H:%M:%SZ')
    for entity in entities:
        url = f"{base_url}/api/history/period/{start}?filter_entity_id={urllib.parse.quote(entity)}"
        req = urllib.request.Request(url)
        req.add_header('Authorization', f'Bearer {token}')
        req.add_header('Content-Type', 'application/json')

        t0 = time.perf_counter()
        status = 0
        payload_len = 0
        error = ''
        events = 0
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                status = int(resp.getcode())
                body = resp.read()
                payload_len = len(body)
                try:
                    data = json.loads(body.decode('utf-8', errors='ignore'))
                    if isinstance(data, list) and data:
                        first = data[0]
                        if isinstance(first, list):
                            events = len(first)
                        elif isinstance(first, dict):
                            events = len(data)
                    elif isinstance(data, list):
                        events = len(data)
                except Exception:
                    pass
        except Exception as exc:
            error = str(exc)
        latency_ms = round((time.perf_counter() - t0) * 1000.0, 2)

        results.append({
            'window': label,
            'entity_id': entity,
            'status': status,
            'latency_ms': latency_ms,
            'payload_bytes': payload_len,
            'events': events,
            'error': error,
        })

summary = {}
for label, _ in windows:
    rows = [r for r in results if r['window'] == label]
    if not rows:
        continue
    ok_rows = [r for r in rows if r['status'] == 200]
    summary[label] = {
        'requests': len(rows),
        'ok': len(ok_rows),
        'errors': len(rows) - len(ok_rows),
        'avg_latency_ms': round(sum(r['latency_ms'] for r in rows) / len(rows), 2),
        'avg_payload_bytes': round(sum(r['payload_bytes'] for r in rows) / len(rows), 2),
    }

report = {
    'generated_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'base_url': base_url,
    'entities': entities,
    'windows': [w for w, _ in windows],
    'summary': summary,
    'results': results,
}
atomic_write(out_json, json.dumps(report, ensure_ascii=True, indent=2) + '\n')

lines = []
lines.append('# Time-Series Baseline')
lines.append('')
lines.append(f"- generated_at: {report['generated_at']}")
lines.append(f"- base_url: {base_url}")
lines.append('')
lines.append('## Summary')
lines.append('')
lines.append('| Window | Requests | OK | Errors | Avg Latency (ms) | Avg Payload (bytes) |')
lines.append('|---|---:|---:|---:|---:|---:|')
for w in ['24h', '7d', '30d']:
    s = summary.get(w, {'requests':0,'ok':0,'errors':0,'avg_latency_ms':0,'avg_payload_bytes':0})
    lines.append(f"| {w} | {s['requests']} | {s['ok']} | {s['errors']} | {s['avg_latency_ms']} | {s['avg_payload_bytes']} |")

lines.append('')
lines.append('## Detail')
lines.append('')
lines.append('| Window | Entity | Status | Events | Latency (ms) | Payload (bytes) | Error |')
lines.append('|---|---|---:|---:|---:|---:|---|')
for r in results:
    err = r['error'].replace('|', '/').replace('\n', ' ')
    lines.append(f"| {r['window']} | {r['entity_id']} | {r['status']} | {r['events']} | {r['latency_ms']} | {r['payload_bytes']} | {err} |")

atomic_write(out_md, '\n'.join(lines) + '\n')
print(out_md)
print(out_json)
PY
