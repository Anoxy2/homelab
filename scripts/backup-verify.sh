#!/bin/bash
# Wöchentliche Backup-Verifikation: prüft ob Restic-Snapshot vorhanden und aktuell

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_AGE_HOURS="${BACKUP_VERIFY_MAX_AGE_HOURS:-48}"

# shellcheck source=/home/steges/scripts/lib/env.sh
source "$SCRIPT_DIR/lib/env.sh"
load_dotenv

send_telegram() {
  local msg="$1"
  local token="${TELEGRAM_BOT_TOKEN:-}"
  local chat="${TELEGRAM_CHAT_ID:-}"
  [[ -n "$token" && -n "$chat" ]] || return 0
  curl -sf -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    -d chat_id="$chat" \
    -d parse_mode="HTML" \
    --data-urlencode "text=$msg" >/dev/null || true
}

now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
host_name="$(hostname)"

if [[ -z "${RESTIC_REPOSITORY:-}" || -z "${RESTIC_PASSWORD:-}" ]]; then
  send_telegram "💾 Backup Verify @ ${host_name} — ${now}
ℹ️ Restic nicht konfiguriert (RESTIC_REPOSITORY oder RESTIC_PASSWORD fehlt) — Backup übersprungen"
  echo "Restic not configured, skipping"
  exit 0
fi

if ! command -v restic >/dev/null 2>&1; then
  send_telegram "💾 Backup Verify @ ${host_name} — ${now}
❌ restic nicht installiert"
  echo "ERROR: restic not installed"
  exit 1
fi

snapshots_json="$(restic snapshots --json --last 2>/dev/null || echo '[]')"

parsed="$(echo "$snapshots_json" | python3 - "${MAX_AGE_HOURS}" <<'PY'
import json, sys
from datetime import datetime, timezone

data = json.load(sys.stdin)
max_age = float(sys.argv[1])

count = len(data)
if count == 0:
    print(f"0||9999|stale")
    sys.exit(0)

ts = data[-1].get('time', '')
try:
    dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
    age = round((datetime.now(timezone.utc) - dt).total_seconds() / 3600, 1)
    last_time = ts[:19].replace('T', ' ') + ' UTC'
except Exception:
    age = 9999
    last_time = ''

status = "ok" if age <= max_age else "stale"
print(f"{count}|{last_time}|{age}|{status}")
PY
)"

snapshot_count="$(echo "$parsed" | cut -d'|' -f1)"
last_snapshot_time="$(echo "$parsed" | cut -d'|' -f2)"
age_hours="$(echo "$parsed" | cut -d'|' -f3)"
snap_status="$(echo "$parsed" | cut -d'|' -f4)"

if [[ "$snapshot_count" -eq 0 ]]; then
  send_telegram "💾 Backup Verify @ ${host_name} — ${now}
❌ Kein Restic-Snapshot gefunden!"
  echo "ERROR: no snapshots found"
  exit 1
fi

max_age="${MAX_AGE_HOURS}"

if [[ "$snap_status" == "ok" ]]; then
  status_icon="✅"
  status_text="OK"
else
  status_icon="⚠️"
  status_text="VERALTET (>${max_age}h)"
fi

msg="💾 Backup Verify @ ${host_name} — ${now}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Snapshots gesamt: ${snapshot_count}
• Letztes Backup:  ${last_snapshot_time:-unbekannt}
• Alter:           ${age_hours}h (Max: ${max_age}h)

${status_icon} Status: ${status_text}"

send_telegram "$msg"
echo "Backup verify: snapshots=${snapshot_count} age=${age_hours}h status=${status_text}"
