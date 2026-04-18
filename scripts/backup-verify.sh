#!/bin/bash
# Wöchentliche Backup-Verifikation: prüft lokale tar.gz + Restic-Snapshots

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_AGE_HOURS="${BACKUP_VERIFY_MAX_AGE_HOURS:-48}"

# shellcheck source=/home/steges/scripts/lib/env.sh
source "$SCRIPT_DIR/lib/env.sh"
load_dotenv

BACKUP_DIR="$HOME/backups"
ERRORS=0

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

# Lokale tar.gz Backups prüfen
check_local_backups() {
  local errors=0
  local latest_backup=""
  local latest_time=0
  
  # Neuestes Backup-Verzeichnis finden
  if [[ -d "$BACKUP_DIR" ]]; then
    latest_backup=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name '20*' | sort | tail -1)
  fi
  
  if [[ -z "$latest_backup" ]]; then
    echo "WARNING: Kein lokales Backup-Verzeichnis gefunden"
    return 1
  fi
  
  echo "Prüfe lokales Backup: $(basename "$latest_backup")"
  
  # Prüfe ob Archive existieren und nicht leer sind
  local archives=0
  local empty_archives=0
  
  for archive in "$latest_backup"/*.tar.gz; do
    if [[ -f "$archive" ]]; then
      ((archives++))
      if [[ ! -s "$archive" ]]; then
        echo "ERROR: Leeres Archiv: $(basename "$archive")"
        ((empty_archives++))
        ((errors++))
      fi
    fi
  done
  
  if [[ $archives -eq 0 ]]; then
    echo "ERROR: Keine tar.gz Archive im Backup-Verzeichnis"
    ((errors++))
  else
    echo "OK: $archives Archive geprüft, $empty_archives leer"
  fi
  
  # Prüfe Alter (nicht älter als MAX_AGE_HOURS)
  local backup_age_hours
  backup_age_hours=$(($(date +%s) - $(stat -c %Y "$latest_backup")) / 3600)
  
  if [[ $backup_age_hours -gt $MAX_AGE_HOURS ]]; then
    echo "WARNING: Backup ist ${backup_age_hours}h alt (Max: ${MAX_AGE_HOURS}h)"
    ((errors++))
  else
    echo "OK: Backup-Alter ${backup_age_hours}h (Max: ${MAX_AGE_HOURS}h)"
  fi
  
  return $errors
}

now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
host_name="$(hostname)"

# ═════════════════════════════════════════════════════════════════════════════
# 1. Lokale tar.gz Backups prüfen
# ═════════════════════════════════════════════════════════════════════════════
local_status="✅ OK"
local_details=""

if ! check_local_backups; then
  ERRORS=$((ERRORS + 1))
  local_status="❌ FEHLER"
  local_details="(siehe Details oben)"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 2. Restic-Snapshots prüfen (falls konfiguriert)
# ═════════════════════════════════════════════════════════════════════════════
restic_status="ℹ️ Nicht konfiguriert"
restic_details=""
snapshot_count=0
age_hours=0

if [[ -n "${RESTIC_REPOSITORY:-}" && -n "${RESTIC_PASSWORD:-}" ]]; then
  if command -v restic >/dev/null 2>&1; then
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
    age_hours="$(echo "$parsed" | cut -d'|' -f3)"
    snap_status="$(echo "$parsed" | cut -d'|' -f4)"
    
    if [[ "$snapshot_count" -eq 0 ]]; then
      restic_status="❌ Keine Snapshots"
      ERRORS=$((ERRORS + 1))
    elif [[ "$snap_status" == "ok" ]]; then
      restic_status="✅ OK (${age_hours}h)"
    else
      restic_status="⚠️ Veraltet (${age_hours}h > ${MAX_AGE_HOURS}h)"
      ERRORS=$((ERRORS + 1))
    fi
  else
    restic_status="❌ restic nicht installiert"
    ERRORS=$((ERRORS + 1))
  fi
fi

# ═════════════════════════════════════════════════════════════════════════════
# 3. Zusammenfassende Telegram-Nachricht
# ═════════════════════════════════════════════════════════════════════════════
overall_icon="✅"
[[ $ERRORS -gt 0 ]] && overall_icon="❌"

msg="${overall_icon} Backup Verify @ ${host_name} — ${now}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<b>Lokale tar.gz:</b> ${local_status} ${local_details}
<b>Restic:</b> ${restic_status}"

if [[ $snapshot_count -gt 0 ]]; then
  msg="${msg}
• Snapshots: ${snapshot_count}"
fi

send_telegram "$msg"
echo "Backup verify: errors=${ERRORS} local=${local_status} restic=${restic_status}"

exit $ERRORS
