#!/bin/bash
set -euo pipefail

HA_URL="http://192.168.2.101:8123"
HA_TIMEOUT="${HA_TIMEOUT:-15}"

usage() {
  echo "Usage: $0 [domain] [--json]"
  echo "  domain: light, switch, sensor, climate, ... (leer = alle)"
  echo "  --json: JSON-Output statt Tabelle"
}

require_token() {
  [[ -n "${HA_TOKEN:-}" ]] || { echo "HA_TOKEN is not set" >&2; exit 1; }
}

require_token

domain_filter=""
json_mode=0
for arg in "$@"; do
  case "$arg" in
    --json) json_mode=1 ;;
    --help|-h) usage; exit 0 ;;
    -*) usage; exit 1 ;;
    *) domain_filter="$arg" ;;
  esac
done

tmp="$(mktemp)"
if ! curl -fsS \
    --connect-timeout "$HA_TIMEOUT" \
    --max-time "$HA_TIMEOUT" \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    "$HA_URL/api/states" \
    -o "$tmp" 2>/dev/null; then
  rm -f "$tmp"
  echo "HA request failed" >&2
  exit 1
fi

python3 - "$tmp" "$domain_filter" "$json_mode" <<'PY'
import json, sys

path, domain_filter, json_mode = sys.argv[1], sys.argv[2], sys.argv[3] == '1'

with open(path) as f:
    states = json.load(f)

results = []
for s in states:
    eid = s.get('entity_id', '')
    dom = eid.split('.')[0] if '.' in eid else ''
    if domain_filter and dom != domain_filter:
        continue
    name = s.get('attributes', {}).get('friendly_name', '')
    state = s.get('state', '?')
    results.append({'entity_id': eid, 'domain': dom, 'state': state, 'friendly_name': name})

results.sort(key=lambda x: x['entity_id'])

LIMIT = 50
truncated = len(results) > LIMIT
shown = results[:LIMIT]

if json_mode:
    print(json.dumps(shown, ensure_ascii=False))
    if truncated:
        sys.stderr.write(f"[truncated: showing {LIMIT}/{len(results)}]\n")
else:
    print(f"{'Entity ID':<45} {'State':<20} {'Name'}")
    print('-' * 90)
    for r in shown:
        print(f"{r['entity_id']:<45} {r['state']:<20} {r['friendly_name']}")
    if truncated:
        print(f"\n[{len(results) - LIMIT} weitere Entities nicht angezeigt — Domain-Filter nutzen]")
PY

rm -f "$tmp"
