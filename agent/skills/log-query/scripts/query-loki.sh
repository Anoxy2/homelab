#!/usr/bin/env bash
# query-loki.sh – Loki LogQL Abfrage für OpenClaw
#
# Zweck: OpenClaw kann gezielt Container-Logs aus Loki abrufen, ohne
#        rohe Logs in den RAG-Index zu schreiben.
#
# Usage:
#   query-loki.sh --service <name> [--lines N] [--since <duration>] [--grep <pattern>]
#   query-loki.sh --query '<logql>' [--lines N] [--since <duration>]
#   query-loki.sh --services            # listet verfügbare Container
#
# Beispiele:
#   query-loki.sh --service openclaw --lines 30 --since 1h
#   query-loki.sh --service pihole --since 30m --grep "blocked"
#   query-loki.sh --query '{container="homeassistant"} |= "error"' --lines 20

set -euo pipefail

LOKI_URL="${LOKI_URL:-http://192.168.2.101:3100}"
LINES=50
SINCE="1h"
SERVICE=""
LOGQL=""
GREP_PATTERN=""
LIST_SERVICES=0

usage() {
  grep '^#' "$0" | sed 's/^# \?//' | tail -n +2
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service|-s)   SERVICE="$2"; shift 2 ;;
    --lines|-n)     LINES="$2"; shift 2 ;;
    --since)        SINCE="$2"; shift 2 ;;
    --grep|-g)      GREP_PATTERN="$2"; shift 2 ;;
    --query|-q)     LOGQL="$2"; shift 2 ;;
    --services)     LIST_SERVICES=1; shift ;;
    --help|-h)      usage ;;
    *) echo "Unbekannte Option: $1" >&2; exit 2 ;;
  esac
done

# Loki erreichbar?
if ! curl -sf "${LOKI_URL}/ready" >/dev/null 2>&1; then
  echo "ERROR: Loki nicht erreichbar unter ${LOKI_URL}" >&2
  exit 1
fi

# Verfügbare Services auflisten
if [[ $LIST_SERVICES -eq 1 ]]; then
  echo "Verfügbare Container in Loki:"
  curl -sf "${LOKI_URL}/loki/api/v1/label/container/values" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); [print(' -', v) for v in sorted(d.get('data',[]))]" 2>/dev/null \
    || echo "(Loki-API nicht erreichbar oder keine Daten)"
  exit 0
fi

# LogQL Query aufbauen
if [[ -z "$LOGQL" ]]; then
  if [[ -z "$SERVICE" ]]; then
    echo "ERROR: --service oder --query erforderlich" >&2
    exit 2
  fi
  LOGQL="{container=\"${SERVICE}\"}"
  if [[ -n "$GREP_PATTERN" ]]; then
    LOGQL="${LOGQL} |= \"${GREP_PATTERN}\""
  fi
fi

# Zeitbereich berechnen (start = jetzt - SINCE)
start_ns=$(python3 -c "
import re, time
s = '${SINCE}'
m = re.match(r'^(\d+)(m|h|d)$', s)
if not m:
    print(int((time.time() - 3600) * 1e9))
else:
    n, u = int(m.group(1)), m.group(2)
    secs = n * {'m': 60, 'h': 3600, 'd': 86400}[u]
    print(int((time.time() - secs) * 1e9))
" 2>/dev/null || echo "$(($(date +%s) - 3600))000000000")

end_ns=$(python3 -c "import time; print(int(time.time() * 1e9))" 2>/dev/null || echo "$(date +%s)000000000")

# Loki Query Range API
response=$(curl -sf -G "${LOKI_URL}/loki/api/v1/query_range" \
  --data-urlencode "query=${LOGQL}" \
  --data-urlencode "start=${start_ns}" \
  --data-urlencode "end=${end_ns}" \
  --data-urlencode "limit=${LINES}" \
  --data-urlencode "direction=backward" \
  2>&1) || {
    echo "ERROR: Loki-Abfrage fehlgeschlagen" >&2
    exit 1
  }

# Ausgabe parsen und lesbar formatieren
echo "$response" | python3 -c "
import json, sys
from datetime import datetime, timezone

label = sys.argv[2]
query = sys.argv[3]
raw = sys.stdin.read()

try:
    data = json.loads(raw)
except Exception:
    print('(parse error: ungueltige Loki-Antwort)')
    sys.exit(1)

results = data.get('data', {}).get('result', [])
if not results:
    print(f'Keine Logs fuer: {query}')
    sys.exit(0)

lines = []
for stream in results:
    for ts_ns, msg in stream.get('values', []):
        ts = datetime.fromtimestamp(int(ts_ns) / 1e9, tz=timezone.utc)
        ts_str = ts.strftime('%Y-%m-%d %H:%M:%S')
        lines.append((int(ts_ns), ts_str, msg.rstrip()))

lines.sort(key=lambda x: x[0])
print(f'-- Logs [{label}] ({len(lines)} Zeilen) --')
for _, ts_str, msg in lines:
    print(f'  {ts_str}  {msg}')
" -- "${SERVICE:-query}" "${LOGQL}"