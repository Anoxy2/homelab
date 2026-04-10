#!/bin/bash
# growbox-dispatch.sh — Growbox Skill Dispatcher
#
# Usage:
#   growbox-dispatch.sh diary
#   growbox-dispatch.sh daily-report
#   growbox-dispatch.sh flush-queue
#   growbox-dispatch.sh should-report    → stdout "1" oder "0"
#   growbox-dispatch.sh mark-sent
#   growbox-dispatch.sh status

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SM_STATE="/home/steges/agent/skills/skill-forge/.state"
REPORT_STATE="$SM_STATE/growbox-report-state.json"

# shellcheck source=/home/steges/scripts/lib/env.sh
source "/home/steges/scripts/lib/env.sh"

usage() {
  cat <<'EOF'
Usage:
  growbox-dispatch.sh diary
  growbox-dispatch.sh daily-report
  growbox-dispatch.sh flush-queue
  growbox-dispatch.sh should-report
  growbox-dispatch.sh mark-sent
  growbox-dispatch.sh status
EOF
}

cmd_should_report() {
  python3 - "$REPORT_STATE" <<'PY'
import json
import os
import sys
from datetime import datetime
from zoneinfo import ZoneInfo

path = sys.argv[1]
if not os.path.exists(path):
    state = {'last_daily_report': ''}
else:
    with open(path, 'r', encoding='utf-8') as f:
        state = json.load(f)

tz = ZoneInfo('Europe/Berlin')
now = datetime.now(tz)
today = now.strftime('%Y-%m-%d')
last = state.get('last_daily_report', '')
in_window = now.hour == 20
print('1' if in_window and last != today else '0')
PY
}

cmd_mark_sent() {
  python3 - "$REPORT_STATE" <<'PY'
import json
import os
import sys
from datetime import datetime
from zoneinfo import ZoneInfo

path = sys.argv[1]
os.makedirs(os.path.dirname(path), exist_ok=True)
tz = ZoneInfo('Europe/Berlin')
today = datetime.now(tz).strftime('%Y-%m-%d')
with open(path, 'w', encoding='utf-8') as f:
    json.dump({'last_daily_report': today}, f, ensure_ascii=True)
print("marked")
PY
}

cmd_diary() {
  load_dotenv
  exec "$SKILL_DIR/scripts/growbox-diary.sh" "$@"
}

cmd_daily_report() {
  load_dotenv
  exec "$SKILL_DIR/scripts/growbox-daily-report.sh" "$@"
}

cmd_flush_queue() {
  load_dotenv
  exec "$SKILL_DIR/scripts/growbox-daily-report.sh" --flush-queue-only
}

cmd_status() {
  load_dotenv
  local ha_token="${HA_TOKEN:-}"
  local ha_base="${HA_BASE_URL:-http://192.168.2.101:8123}"

  python3 - "$ha_base" "$ha_token" <<'PY'
import json, sys, urllib.parse, urllib.request

ha_base = sys.argv[1].rstrip('/')
ha_token = sys.argv[2]

def fetch_state(entity):
    if not ha_token:
        return None
    try:
        req = urllib.request.Request(
            f"{ha_base}/api/states/{urllib.parse.quote(entity, safe='')}",
            headers={'Authorization': f'Bearer {ha_token}', 'Content-Type': 'application/json'},
        )
        with urllib.request.urlopen(req, timeout=8) as resp:
            data = json.loads(resp.read().decode('utf-8'))
        return str(data.get('state', '')).strip() or None
    except Exception:
        return None

entities = {
    'temp': 'sensor.growbox_temperatur',
    'humidity': 'sensor.growbox_luftfeuchtigkeit',
    'co2': 'sensor.growbox_co2',
    'esp32_uptime': 'sensor.growbox_esp_uptime',
}
result = {k: fetch_state(v) for k, v in entities.items()}
print(json.dumps(result, indent=2, ensure_ascii=False))
PY
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    diary)           shift; cmd_diary "$@" ;;
    daily-report)    shift; cmd_daily_report "$@" ;;
    flush-queue)     shift; cmd_flush_queue "$@" ;;
    should-report)   cmd_should_report ;;
    mark-sent)       cmd_mark_sent ;;
    status)          cmd_status ;;
    "") usage; exit 2 ;;
    *) echo "Unbekannter Subcommand: $cmd" >&2; usage >&2; exit 2 ;;
  esac
}

main "$@"
