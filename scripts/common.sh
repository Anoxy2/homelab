#!/bin/bash

# Shared helper functions for maintenance scripts.

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    local level="$1"
    shift
    local msg="$*"
    # Standard: JSON-Lines fuer strukturierte Auswertung; Legacy-Text optional.
    if [[ "${LOG_LEGACY_TEXT:-0}" == "1" ]]; then
        printf '[%s] [%s] %s\n' "$(timestamp)" "$level" "$msg"
        return
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$level" "$msg" "$(timestamp)" <<'PY'
import json
import sys

level, message, ts = sys.argv[1:4]
print(json.dumps({"ts": ts, "level": level, "msg": message}, ensure_ascii=True))
PY
    else
        printf '[%s] [%s] %s\n' "$(timestamp)" "$level" "$msg"
    fi
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@" >&2
}

# Sende Telegram-Nachricht (falls TELEGRAM_BOT_TOKEN und TELEGRAM_CHAT_ID gesetzt)
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