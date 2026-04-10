#!/bin/bash
set -euo pipefail
# check-tier.sh — Gibt den Safety-Tier einer Entity zurück
# Output: "blocked" | "tier0-read" | "tier1-write" | "tier2-blocked" | "tier3-blocked" | "unknown"
# Exit: 0 immer (nur informativer Output)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOCKED_JSON="$SCRIPT_DIR/../config/blocked-entities.json"

usage() { echo "Usage: $0 <entity_id>"; }
[[ $# -eq 1 ]] || { usage; exit 1; }

entity_id="$1"
domain="${entity_id%%.*}"

# Hard-blocked
if [[ -f "$BLOCKED_JSON" ]]; then
  if python3 -c "
import json, sys
with open('$BLOCKED_JSON') as f:
    d = json.load(f)
sys.exit(0 if '$entity_id' in d.get('blocked', []) else 1)
" 2>/dev/null; then
    echo "blocked (hard-blocked in config/blocked-entities.json)"
    exit 0
  fi
fi

case "$domain" in
  # Tier 2 (Sensitive — blockiert ohne explizite Freigabe)
  lock|alarm_control_panel|cover)
    echo "tier2-blocked (security-critical: $domain)"
    ;;
  # Tier 3 (Platform — immer blockiert)
  config|homeassistant)
    echo "tier3-blocked (platform domain: $domain)"
    ;;
  # Tier 1 (Low-risk writes erlaubt)
  light|switch|input_boolean|scene|fan|select|number)
    echo "tier1-write (low-risk writes allowed)"
    ;;
  # Tier 0 (Nur lesen)
  sensor|binary_sensor|weather|input_number|climate|media_player|\
  automation|script|text_sensor|button|input_select|input_text|\
  calendar|camera|device_tracker|person|sun|zone)
    echo "tier0-read (read-only domain)"
    ;;
  *)
    echo "unknown (domain '$domain' not in whitelist)"
    ;;
esac
