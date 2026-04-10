#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "/home/steges/agent/skills/skill-forge/scripts/common.sh"

# shellcheck source=/home/steges/scripts/lib/env.sh
source "/home/steges/scripts/lib/env.sh"

main() {
  load_dotenv

  local tz="Europe/Berlin"
  local today_file
  today_file="$(TZ="$tz" date +%d.%m.%Y).md"
  local diary_dir="/home/steges/growbox/diary"
  local diary_path="$diary_dir/$today_file"

  mkdir -p "$diary_dir"
  if [[ -f "$diary_path" ]]; then
    echo "SKIP: diary already exists ($diary_path)"
    return 0
  fi

  local ha_token="${HA_TOKEN:-}"
  local ha_base="${HA_BASE_URL:-http://192.168.2.101:8123}"
  local snapshot
  snapshot="$(python3 - "$ha_base" "$ha_token" <<'PY'
import json
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

ha_base = sys.argv[1].rstrip('/')
ha_token = sys.argv[2]
ACTION_LOG = '/home/steges/infra/openclaw-data/action-log.jsonl'


def fetch_state(entity: str):
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


def detect_triggers_24h():
    triggers = []
    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    try:
        with open(ACTION_LOG, 'r', encoding='utf-8', errors='ignore') as f:
            rows = [line.strip() for line in f if line.strip()]
    except Exception:
        rows = []

    for raw in rows:
        try:
            row = json.loads(raw)
        except Exception:
            continue
        ts = row.get('ts', '')
        try:
            dt = datetime.strptime(ts, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
        except Exception:
            continue
        if dt < cutoff:
            continue
        action = str(row.get('action', '')).lower()
        result = str(row.get('result', '')).lower()

        if 'growbox' in action and 'temp' in action:
            triggers.append('Temp-Alarm')
        if 'growbox' in action and ('humidity' in action or 'hum' in action):
            triggers.append('Humidity-Alarm')
        if 'esp32' in action or ('offline' in action and 'growbox' in action):
            triggers.append('ESP32 offline')
        if 'manual' in action:
            triggers.append('manuelle Aktion')
        if 'growbox' in action and ('alert' in action or 'alarm' in action or 'failed' in result):
            triggers.append('Growbox-Ereignis')

    if not triggers:
        triggers = ['keine besonderen Trigger in den letzten 24h erkannt']
    dedup = []
    seen = set()
    for t in triggers:
        if t in seen:
            continue
        seen.add(t)
        dedup.append(t)
    return dedup

snapshot = {
    'temp_c': fetch_state('sensor.growbox_temperatur'),
    'humidity_pct': fetch_state('sensor.growbox_luftfeuchtigkeit'),
    'co2_ppm': fetch_state('sensor.growbox_co2'),
    'esp32_uptime': fetch_state('sensor.growbox_esp_uptime'),
    'triggers': detect_triggers_24h(),
}
print(json.dumps(snapshot, ensure_ascii=True))
PY
)"

  local temp hum co2 uptime triggers_md
  temp="$(python3 - <<'PY' "$snapshot"
import json,sys
d=json.loads(sys.argv[1]); print(d.get('temp_c') or 'n/a')
PY
)"
  hum="$(python3 - <<'PY' "$snapshot"
import json,sys
d=json.loads(sys.argv[1]); print(d.get('humidity_pct') or 'n/a')
PY
)"
  co2="$(python3 - <<'PY' "$snapshot"
import json,sys
d=json.loads(sys.argv[1]); print(d.get('co2_ppm') or 'n/a')
PY
)"
  uptime="$(python3 - <<'PY' "$snapshot"
import json,sys
d=json.loads(sys.argv[1]); print(d.get('esp32_uptime') or 'n/a')
PY
)"
  triggers_md="$(python3 - <<'PY' "$snapshot"
import json,sys
d=json.loads(sys.argv[1]);
for t in d.get('triggers',[]):
    print(f"- {t}")
PY
)"

  cat > "$diary_path" <<EOF
# Growbox Diary - $(TZ="$tz" date +%d.%m.%Y)

## Timestamp
- erstellt_am: $(TZ="$tz" date +"%d.%m.%Y %H:%M:%S %Z")
- erstellt_durch: OpenClaw Heartbeat

## Trigger-Kontext (24h)
${triggers_md}

## Sensor-Snapshot
- temperatur_c: ${temp}
- humidity_pct: ${hum}
- co2_ppm: ${co2}
- esp32_uptime: ${uptime}

## Kurznotiz
Automatischer Tages-Eintrag erstellt, weil fuer heute noch kein Diary-Eintrag vorhanden war.
EOF

  echo "CREATED: $diary_path"
}

main "$@"
