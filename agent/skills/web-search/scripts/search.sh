#!/usr/bin/env bash
# search.sh – Web-Suche via SearXNG für OpenClaw
#
# Usage:
#   search.sh "<query>" [--limit N] [--engines <e1,e2>] [--lang <de-DE|en-US|...>]
#   search.sh "<query>" --json                  # strukturierter JSON-Output
#   search.sh --check                           # Erreichbarkeit prüfen
#
# Beispiele:
#   search.sh "Raspberry Pi 5 NVMe SSD benchmark"
#   search.sh "Docker Loki Promtail config" --limit 5 --engines google,github
#   search.sh "CVE-2024-1234" --json
#   search.sh "Home Assistant ESPHome MQTT" --lang en-US

set -euo pipefail

SEARXNG_URL="${SEARXNG_URL:-http://192.168.2.101:8085}"
LIMIT=5
ENGINES=""
LANG="de-DE"
JSON=0
CHECK=0
QUERY=""

usage() {
  grep '^#' "$0" | sed 's/^# \?//' | tail -n +2
  exit 0
}

# Erstes Argument ist die Query (wenn kein Flag)
if [[ $# -gt 0 && "${1:0:2}" != "--" ]]; then
  QUERY="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit|-n)    LIMIT="$2"; shift 2 ;;
    --engines|-e)  ENGINES="$2"; shift 2 ;;
    --lang|-l)     LANG="$2"; shift 2 ;;
    --json)        JSON=1; shift ;;
    --check)       CHECK=1; shift ;;
    --help|-h)     usage ;;
    *) QUERY="${QUERY:+$QUERY }$1"; shift ;;
  esac
done

# Health-Check
if [[ $CHECK -eq 1 ]]; then
  if curl -sf "${SEARXNG_URL}/healthz" >/dev/null 2>&1; then
    echo "SearXNG: erreichbar (${SEARXNG_URL})"
    exit 0
  else
    echo "SearXNG: NICHT erreichbar (${SEARXNG_URL})" >&2
    exit 1
  fi
fi

if [[ -z "$QUERY" ]]; then
  echo "ERROR: Query erforderlich" >&2
  echo "Usage: search.sh \"<query>\" [--limit N] [--engines <e1,e2>] [--json]" >&2
  exit 2
fi

if [[ ! "$LIMIT" =~ ^[0-9]+$ ]] || (( LIMIT < 1 || LIMIT > 20 )); then
  echo "ERROR: --limit muss zwischen 1 und 20 liegen" >&2
  exit 2
fi

# SearXNG JSON-API aufrufen
params="q=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")&format=json&language=${LANG}"
[[ -n "$ENGINES" ]] && params="${params}&engines=${ENGINES}"

response=$(curl -sf -G \
  --data-urlencode "q=${QUERY}" \
  --data-urlencode "format=json" \
  --data-urlencode "language=${LANG}" \
  ${ENGINES:+--data-urlencode "engines=${ENGINES}"} \
  "${SEARXNG_URL}/search" 2>&1) || {
  echo "ERROR: SearXNG-Anfrage fehlgeschlagen (${SEARXNG_URL})" >&2
  exit 1
}

# JSON-Output
if [[ $JSON -eq 1 ]]; then
  echo "$response" | python3 -c "
import json, sys
raw = sys.stdin.read()
try:
    d = json.loads(raw)
except Exception as e:
    print(json.dumps({'error': str(e)}))
    sys.exit(1)
results = d.get('results', [])[:${LIMIT}]
out = {
    'query': d.get('query', ''),
    'number_of_results': d.get('number_of_results', 0),
    'results': [
        {
            'title': r.get('title', ''),
            'url': r.get('url', ''),
            'content': r.get('content', '')[:400],
            'engine': r.get('engine', ''),
            'score': r.get('score', 0),
        }
        for r in results
    ]
}
print(json.dumps(out, ensure_ascii=False, indent=2))
"
  exit 0
fi

# Lesbarer Output
echo "$response" | python3 -c "
import json, sys
raw = sys.stdin.read()
try:
    d = json.loads(raw)
except Exception:
    print('(parse error: ungültige SearXNG-Antwort)')
    sys.exit(1)

query = d.get('query', '')
total = d.get('number_of_results', 0)
results = d.get('results', [])[:${LIMIT}]

print(f'Suche: \"{query}\" — {total:,} Treffer (top {len(results)})')
print()
for i, r in enumerate(results, 1):
    title = r.get('title', '').strip()
    url = r.get('url', '').strip()
    content = r.get('content', '').strip()[:300]
    engine = r.get('engine', '')
    print(f'[{i}] {title}')
    print(f'    {url}')
    if content:
        print(f'    {content}')
    print(f'    [{engine}]')
    print()
"