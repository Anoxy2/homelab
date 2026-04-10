#!/bin/bash
set -euo pipefail

HA_URL="http://192.168.2.101:8123"
HA_TIMEOUT="${HA_TIMEOUT:-10}"
SM_AUDIT_LOG="/home/steges/agent/skills/skill-forge/.state/audit-log.jsonl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOCKED_ENTITIES_JSON="$SCRIPT_DIR/../config/blocked-entities.json"

usage() {
  echo "Usage: $0 <entity_id>"
}

require_token() {
  [[ -n "${HA_TOKEN:-}" ]] || {
    echo "HA_TOKEN is not set" >&2
    exit 1
  }
}

# Domain-basierte Read-Whitelist (Tier 0 — immer erlaubt)
is_allowed_domain() {
  local domain="${1%%.*}"
  case "$domain" in
    sensor|binary_sensor|weather|input_boolean|input_number|\
    climate|media_player|automation|script|scene|\
    fan|select|number|text_sensor|button|light|switch|\
    cover|lock|alarm_control_panel|input_select|input_text|\
    calendar|camera|device_tracker|person|sun|zone)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Blocked-entities.json prüfen (Hard-Block unabhängig von Tier)
is_blocked_entity() {
  local entity_id="$1"
  [[ -f "$BLOCKED_ENTITIES_JSON" ]] || return 1
  python3 -c "
import json, sys
with open('$BLOCKED_ENTITIES_JSON', 'r') as f:
    d = json.load(f)
sys.exit(0 if '$entity_id' in d.get('blocked', []) else 1)
" 2>/dev/null
}

[[ $# -eq 1 ]] || { usage; exit 1; }
require_token
entity_id="$1"

# Reihenfolge: Blocked > Domain-Whitelist
if is_blocked_entity "$entity_id"; then
  echo "Entity is blocked by config: $entity_id" >&2
  exit 1
fi

is_allowed_domain "$entity_id" || {
  echo "Domain not in read whitelist: ${entity_id%%.*}" >&2
  exit 1
}

# Audit: log read access
ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '{"ts":"%s","command":"HA_READ","entity_id":"%s"}\n' \
  "$ts" "$entity_id" >> "$SM_AUDIT_LOG" 2>/dev/null || true

exec curl -fsS \
  --connect-timeout "$HA_TIMEOUT" \
  --max-time "$HA_TIMEOUT" \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  "$HA_URL/api/states/$entity_id"
