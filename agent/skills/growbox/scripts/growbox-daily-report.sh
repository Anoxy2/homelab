#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "/home/steges/agent/skills/skill-forge/scripts/common.sh"

# shellcheck source=/home/steges/scripts/lib/env.sh
source "/home/steges/scripts/lib/env.sh"

QUEUE_PATH="$STATE_DIR/growbox-message-queue.json"
REPORT_SENT=0

ensure_queue_file() {
    python3 - "$QUEUE_PATH" <<'PY'
import os
import sys

sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import write_json_atomic, read_json_file

path = sys.argv[1]
rows = read_json_file(path, None)
if not isinstance(rows, list):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        write_json_atomic(path, [])
PY
}

queue_send_python() {
    local op="$1"
    local token="$2"
    local chat_id="$3"
    local reason="${4:-}"
    local text_b64="${5:-}"

    python3 - "$QUEUE_PATH" "$op" "$token" "$chat_id" "$reason" "$text_b64" <<'PY'
import base64
import json
import sys
import time
import urllib.parse
import urllib.request

sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import read_json_file, write_json_atomic, utc_now_iso

queue_path, op, token, chat_id, reason, text_b64 = sys.argv[1:7]
rows = read_json_file(queue_path, [])
if not isinstance(rows, list):
        rows = []

def send_with_backoff(text: str) -> tuple[bool, str]:
        if not token or not chat_id:
                return False, 'missing_credentials'
        url = f'https://api.telegram.org/bot{token}/sendMessage'
        delays = [0, 1, 3, 5]
        last_err = 'send_failed'
        for i, delay in enumerate(delays):
                if delay > 0:
                        time.sleep(delay)
                try:
                        body = urllib.parse.urlencode({'chat_id': chat_id, 'text': text}).encode('utf-8')
                        req = urllib.request.Request(url, data=body)
                        with urllib.request.urlopen(req, timeout=10) as resp:
                                code = getattr(resp, 'status', 200)
                                if 200 <= int(code) < 300:
                                        return True, ''
                                last_err = f'http_{code}'
                except Exception as exc:
                        last_err = str(exc)
        return False, last_err

result = {
        'op': op,
        'sent': 0,
        'queued': 0,
        'dropped': 0,
        'remaining': 0,
        'status': 'ok',
}

if op == 'flush':
        kept = []
        for row in rows:
                if not isinstance(row, dict):
                        continue
                text = str(row.get('text', '')).strip()
                if not text:
                        continue
                attempts = int(row.get('attempts', 0))
                if attempts >= 3:
                        result['dropped'] += 1
                        continue
                ok, err = send_with_backoff(text)
                if ok:
                        result['sent'] += 1
                        continue
                attempts += 1
                row['attempts'] = attempts
                row['last_attempt_at'] = utc_now_iso()
                row['last_error'] = err
                if attempts >= 3:
                        result['dropped'] += 1
                else:
                        kept.append(row)
        write_json_atomic(queue_path, kept)
        result['remaining'] = len(kept)
        print(json.dumps(result, ensure_ascii=True))
        raise SystemExit(0)

if op == 'send':
        text = ''
        if text_b64:
                text = base64.b64decode(text_b64.encode('ascii')).decode('utf-8', errors='replace')
        text = text.strip()
        if not text:
                result['status'] = 'invalid_payload'
                print(json.dumps(result, ensure_ascii=True))
                raise SystemExit(2)

        ok, err = send_with_backoff(text)
        if ok:
                result['sent'] = 1
                print(json.dumps(result, ensure_ascii=True))
                raise SystemExit(0)

        rows.append({
                'text': text,
                'reason': reason or 'send_failed',
                'created_at': utc_now_iso(),
                'attempts': 1,
                'last_attempt_at': utc_now_iso(),
                'last_error': err,
        })
        write_json_atomic(queue_path, rows)
        result['queued'] = 1
        result['remaining'] = len(rows)
        result['status'] = 'queued'
        print(json.dumps(result, ensure_ascii=True))
        raise SystemExit(10)

result['status'] = 'invalid_op'
print(json.dumps(result, ensure_ascii=True))
raise SystemExit(2)
PY
}

flush_queue() {
    local token="$1"
    local chat_id="$2"
    ensure_queue_file
    local out
    out="$(queue_send_python "flush" "$token" "$chat_id")"
    local sent dropped remaining
    sent="$(python3 - <<'PY' "$out"
import json,sys
d=json.loads(sys.argv[1])
print(int(d.get('sent',0)))
PY
)"
    dropped="$(python3 - <<'PY' "$out"
import json,sys
d=json.loads(sys.argv[1])
print(int(d.get('dropped',0)))
PY
)"
    remaining="$(python3 - <<'PY' "$out"
import json,sys
d=json.loads(sys.argv[1])
print(int(d.get('remaining',0)))
PY
)"

    if (( sent > 0 || dropped > 0 )); then
        log_audit "GROWBOX" "-" "queue_flush sent=${sent} dropped=${dropped} remaining=${remaining}"
        echo "Growbox queue flush: sent=${sent} dropped=${dropped} remaining=${remaining}"
    fi
}

send_or_queue_report() {
    local token="$1"
    local chat_id="$2"
    local reason="$3"
    local report_text="$4"
    local encoded
    encoded="$(printf '%s' "$report_text" | base64 -w0)"
    if queue_send_python "send" "$token" "$chat_id" "$reason" "$encoded" >/dev/null; then
        REPORT_SENT=1
        return 0
    fi
    REPORT_SENT=0
    return 10
}

main() {
  load_dotenv

  local token="${TELEGRAM_BOT_TOKEN:-}"
  local chat_id="${TELEGRAM_CHAT_ID:-${OPENCLAW_TELEGRAM_CHAT_ID:-}}"
  local ha_token="${HA_TOKEN:-}"
  local ha_base="${HA_BASE_URL:-http://192.168.2.101:8123}"
    local flush_only=0

    if [[ "${1:-}" == "--flush-queue-only" ]]; then
        flush_only=1
    fi

    if [[ -n "$token" && -n "$chat_id" ]]; then
        flush_queue "$token" "$chat_id"
    fi

    if [[ "$flush_only" -eq 1 ]]; then
        echo "Growbox queue flush completed"
        return 0
    fi

  local payload
  payload="$(python3 - "$ha_base" "$ha_token" <<'PY'
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path
from datetime import datetime, timedelta, timezone

ha_base = sys.argv[1].rstrip('/')
ha_token = sys.argv[2]

TEMP_ENTITY = 'sensor.growbox_temperatur'
HUM_ENTITY = 'sensor.growbox_luftfeuchtigkeit'
UPTIME_ENTITY = 'sensor.growbox_esp_uptime'
ACTION_LOG = '/home/steges/infra/openclaw-data/action-log.jsonl'
PHOTO_DIR = Path('/home/steges/growbox/diary/photos')
HA_FAILURES = 0


def fetch_json(url: str, token: str):
    global HA_FAILURES
    delays = [0, 1, 3, 5]
    last_exc = None
    for delay in delays:
        if delay > 0:
            time.sleep(delay)
        req = urllib.request.Request(url)
        if token:
            req.add_header('Authorization', f'Bearer {token}')
        req.add_header('Content-Type', 'application/json')
        try:
            with urllib.request.urlopen(req, timeout=8) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except Exception as exc:
            last_exc = exc
    HA_FAILURES += 1
    raise last_exc if last_exc else RuntimeError('ha_request_failed')


def history_min_max(entity: str):
    if not ha_token:
        return None, None
    now = datetime.now(timezone.utc)
    start = (now - timedelta(hours=24)).isoformat().replace('+00:00', 'Z')
    q = urllib.parse.urlencode({'filter_entity_id': entity, 'minimal_response': '1'})
    url = f"{ha_base}/api/history/period/{start}?{q}"
    try:
        data = fetch_json(url, ha_token)
    except Exception:
        return None, None
    if not isinstance(data, list) or not data or not isinstance(data[0], list):
        return None, None
    vals = []
    for row in data[0]:
        try:
            vals.append(float(str(row.get('state', '')).replace(',', '.')))
        except Exception:
            continue
    if not vals:
        return None, None
    return min(vals), max(vals)


def current_state(entity: str):
    if not ha_token:
        return None
    try:
        data = fetch_json(f"{ha_base}/api/states/{urllib.parse.quote(entity, safe='')}", ha_token)
        return str(data.get('state', '')).strip() or None
    except Exception:
        return None


def alarm_count_24h():
    try:
        with open(ACTION_LOG, 'r', encoding='utf-8', errors='ignore') as f:
            rows = [line.strip() for line in f if line.strip()]
    except Exception:
        return 0

    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    count = 0
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
        if ('growbox' in action and ('alert' in action or 'alarm' in action or 'bad' in result or 'failed' in result)):
            count += 1
    return count


def photo_status():
    if not PHOTO_DIR.exists():
        return {'days_since_last_photo': None, 'photo_hint': 'Fotoordner fehlt'}

    candidates = []
    for ext in ('*.jpg', '*.jpeg', '*.png'):
        candidates.extend(PHOTO_DIR.glob(ext))
    if not candidates:
        return {'days_since_last_photo': None, 'photo_hint': 'kein Foto vorhanden'}

    last = max(candidates, key=lambda p: p.stat().st_mtime)
    last_dt = datetime.fromtimestamp(last.stat().st_mtime, timezone.utc)
    days = (datetime.now(timezone.utc) - last_dt).days
    if days > 7:
        hint = f'Foto-Hinweis: seit {days} Tagen kein neues Growbox-Foto'
    else:
        hint = f'Foto-Status: letztes Foto vor {days} Tagen'
    return {'days_since_last_photo': days, 'photo_hint': hint}


temp_min, temp_max = history_min_max(TEMP_ENTITY)
hum_min, hum_max = history_min_max(HUM_ENTITY)
uptime = current_state(UPTIME_ENTITY)
alarms = alarm_count_24h()
photo = photo_status()

print(json.dumps({
    'temp_min': temp_min,
    'temp_max': temp_max,
    'hum_min': hum_min,
    'hum_max': hum_max,
    'alarms': alarms,
    'esp32_uptime': uptime,
    'photo_hint': photo.get('photo_hint'),
    'ha_failures': HA_FAILURES,
}, ensure_ascii=True))
PY
)"

  local temp_min temp_max hum_min hum_max alarms uptime photo_hint
  temp_min="$(python3 - <<'PY' "$payload"
import json,sys
p=json.loads(sys.argv[1]);v=p.get('temp_min');print('n/a' if v is None else f"{v:.1f} C")
PY
)"
  temp_max="$(python3 - <<'PY' "$payload"
import json,sys
p=json.loads(sys.argv[1]);v=p.get('temp_max');print('n/a' if v is None else f"{v:.1f} C")
PY
)"
  hum_min="$(python3 - <<'PY' "$payload"
import json,sys
p=json.loads(sys.argv[1]);v=p.get('hum_min');print('n/a' if v is None else f"{v:.0f} %")
PY
)"
  hum_max="$(python3 - <<'PY' "$payload"
import json,sys
p=json.loads(sys.argv[1]);v=p.get('hum_max');print('n/a' if v is None else f"{v:.0f} %")
PY
)"
  alarms="$(python3 - <<'PY' "$payload"
import json,sys
p=json.loads(sys.argv[1]);print(int(p.get('alarms',0)))
PY
)"
  uptime="$(python3 - <<'PY' "$payload"
import json,sys
p=json.loads(sys.argv[1]);print(p.get('esp32_uptime') or 'n/a')
PY
)"
  photo_hint="$(python3 - <<'PY' "$payload"
import json,sys
p=json.loads(sys.argv[1]);print(p.get('photo_hint') or 'Foto-Status: n/a')
PY
)"
    local ha_failures
    ha_failures="$(python3 - <<'PY' "$payload"
import json,sys
p=json.loads(sys.argv[1]);print(int(p.get('ha_failures', 0) or 0))
PY
)"

  local report
  report="🌿 Growbox Tagesbericht (20:00)
• Temp min/max (24h): ${temp_min} / ${temp_max}
• Humidity min/max (24h): ${hum_min} / ${hum_max}
• Anzahl Alarme (24h): ${alarms}
• ESP32 Uptime: ${uptime}
• ${photo_hint}"

    if [[ -n "$token" && -n "$chat_id" && "$ha_failures" -gt 0 ]]; then
        local ha_warn
        ha_warn="⚠️ Growbox: HA API hatte ${ha_failures} fehlgeschlagene Request(s) beim Tagesbericht."
        send_or_queue_report "$token" "$chat_id" "ha_api_partial_failure" "$ha_warn" || true
    fi

    if [[ -z "$token" || -z "$chat_id" ]]; then
        send_or_queue_report "$token" "$chat_id" "missing_telegram_credentials" "$report" || true
        echo "Growbox daily report queued: missing Telegram token/chat_id"
        return 10
  fi

    if send_or_queue_report "$token" "$chat_id" "daily_report_send_failed" "$report"; then
        echo "Growbox daily report sent"
        return 0
  fi

    echo "Growbox daily report queued"
    return 10
}

main "$@"
