#!/bin/bash
set -euo pipefail

# Safety-Tier-System:
#   Tier 1 (LOW-RISK):  fan, select, number (Growbox), light, switch, input_boolean, scene
#   Tier 2 (SENSITIVE): climate, lock, cover, alarm_control_panel → BLOCKIERT
#   Tier 3 (PLATFORM):  config, restart, reload → IMMER BLOCKIERT

HA_URL="http://192.168.2.101:8123"
HA_TIMEOUT="${HA_TIMEOUT:-10}"
SM_AUDIT_LOG="/home/steges/agent/skills/skill-forge/.state/audit-log.jsonl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOCKED_ENTITIES_JSON="$SCRIPT_DIR/../config/blocked-entities.json"

usage() {
  echo "Usage: $0 <domain> <service> <entity_id> <value>"
  echo ""
  echo "Growbox (Tier 1 — whitelisted entities):"
  echo "  $0 fan set_percentage fan.growbox_lufeter_0 60"
  echo "  $0 select select_option select.growbox_betriebsmodus Nacht"
  echo "  $0 number set_value number.growbox_alle_lufeter_master 75"
  echo ""
  echo "Tier 1 — light/switch/input_boolean/scene:"
  echo "  $0 light turn_on light.living_room 0"
  echo "  $0 switch toggle switch.desk_lamp 0"
  echo "  $0 scene turn_on scene.evening 0"
}

require_token() {
  [[ -n "${HA_TOKEN:-}" ]] || {
    echo "HA_TOKEN is not set" >&2
    exit 1
  }
}

is_allowed_fan() {
  case "$1" in
    fan.growbox_lufeter_0|fan.growbox_lufeter_1|fan.growbox_lufeter_2|fan.growbox_lufeter_3)
      return 0 ;;
    *) return 1 ;;
  esac
}

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

[[ $# -eq 4 ]] || { usage; exit 1; }
require_token

domain="$1"
service="$2"
entity_id="$3"
value="$4"
payload=""

# Hard-blocked entities
if is_blocked_entity "$entity_id"; then
  echo "Entity is blocked by config: $entity_id" >&2
  exit 1
fi

# Tier-2/3: immer blockiert
case "$domain" in
  lock|alarm_control_panel)
    echo "Tier-2 domain '$domain' is blocked (security-critical)" >&2
    exit 1
    ;;
  cover)
    echo "Tier-2 domain '$domain' is blocked (security-critical covers require manual override)" >&2
    exit 1
    ;;
  config|homeassistant)
    echo "Tier-3 platform domain '$domain' is always blocked" >&2
    exit 1
    ;;
esac

case "$domain/$service" in
  # ── Growbox Whitelist (Tier 1 — strikte Entity-Validierung) ──────────────
  fan/set_percentage)
    is_allowed_fan "$entity_id" || {
      echo "Fan entity not allowed: $entity_id" >&2
      exit 1
    }
    [[ "$value" =~ ^[0-9]+$ ]] || { echo "Percentage must be an integer" >&2; exit 1; }
    (( value >= 0 && value <= 100 )) || { echo "Percentage must be 0-100" >&2; exit 1; }
    payload="{\"entity_id\":\"$entity_id\",\"percentage\":$value}"
    ;;
  select/select_option)
    [[ "$entity_id" == "select.growbox_betriebsmodus" ]] || {
      echo "Select entity not allowed: $entity_id" >&2
      exit 1
    }
    case "$value" in
      "Manuell"|"Auto (Temperatur)"|"Nacht") ;;
      *) echo "Option not allowed: $value" >&2; exit 1 ;;
    esac
    payload="{\"entity_id\":\"$entity_id\",\"option\":\"$value\"}"
    ;;
  number/set_value)
    [[ "$entity_id" == "number.growbox_alle_lufeter_master" ]] || {
      echo "Number entity not allowed: $entity_id" >&2
      exit 1
    }
    [[ "$value" =~ ^[0-9]+$ ]] || { echo "Value must be an integer" >&2; exit 1; }
    (( value >= 0 && value <= 100 )) || { echo "Value must be 0-100" >&2; exit 1; }
    payload="{\"entity_id\":\"$entity_id\",\"value\":$value}"
    ;;

  # ── Tier 1: light ────────────────────────────────────────────────────────
  light/turn_on|light/turn_off|light/toggle)
    [[ "$entity_id" == light.* ]] || { echo "Entity must be light.*" >&2; exit 1; }
    if [[ "$service" == "turn_on" && "$value" =~ ^[0-9]+$ && "$value" -le 255 ]]; then
      payload="{\"entity_id\":\"$entity_id\",\"brightness\":$value}"
    else
      payload="{\"entity_id\":\"$entity_id\"}"
    fi
    ;;

  # ── Tier 1: switch ───────────────────────────────────────────────────────
  switch/turn_on|switch/turn_off|switch/toggle)
    [[ "$entity_id" == switch.* ]] || { echo "Entity must be switch.*" >&2; exit 1; }
    payload="{\"entity_id\":\"$entity_id\"}"
    ;;

  # ── Tier 1: input_boolean ────────────────────────────────────────────────
  input_boolean/turn_on|input_boolean/turn_off|input_boolean/toggle)
    [[ "$entity_id" == input_boolean.* ]] || { echo "Entity must be input_boolean.*" >&2; exit 1; }
    payload="{\"entity_id\":\"$entity_id\"}"
    ;;

  # ── Tier 1: scene ────────────────────────────────────────────────────────
  scene/turn_on)
    [[ "$entity_id" == scene.* ]] || { echo "Entity must be scene.*" >&2; exit 1; }
    payload="{\"entity_id\":\"$entity_id\"}"
    ;;

  *)
    echo "Service not allowed: $domain/$service" >&2
    exit 1
    ;;
esac

tmp_body="$(mktemp)"
set +e
http_code="$(curl -sS \
  --connect-timeout "$HA_TIMEOUT" \
  --max-time "$HA_TIMEOUT" \
  -X POST \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$payload" \
  -o "$tmp_body" \
  -w "%{http_code}" \
  "$HA_URL/api/services/$domain/$service")"
curl_rc=$?
set -e

if [[ $curl_rc -ne 0 ]]; then
  rm -f "$tmp_body"
  echo "HA request failed (network/timeout)" >&2
  exit 1
fi

case "$http_code" in
  2*)
    cat "$tmp_body"
    rm -f "$tmp_body"
    ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf '{"ts":"%s","command":"HA_WRITE","domain":"%s","service":"%s","entity_id":"%s","http_code":"%s"}\n' \
      "$ts" "$domain" "$service" "$entity_id" "$http_code" >> "$SM_AUDIT_LOG" 2>/dev/null || true
    ;;
  401|403)
    rm -f "$tmp_body"
    echo "HA auth error (HTTP $http_code): token invalid or insufficient permissions" >&2
    exit 1
    ;;
  5*)
    rm -f "$tmp_body"
    echo "HA server error (HTTP $http_code): retry later" >&2
    exit 1
    ;;
  *)
    rm -f "$tmp_body"
    echo "HA request rejected (HTTP $http_code)" >&2
    exit 1
    ;;
esac
