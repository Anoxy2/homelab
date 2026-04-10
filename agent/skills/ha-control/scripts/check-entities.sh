#!/bin/bash
# check-entities.sh – Vergleicht die ha-control Whitelist mit live HA-Entities (drift detection).
# Benötigt: HA_TOKEN gesetzt. HA muss erreichbar sein.
set -euo pipefail

HA_URL="http://192.168.2.101:8123"
HA_TIMEOUT="${HA_TIMEOUT:-10}"

usage() {
  echo "Usage: $0 [--json]"
  echo "  --json   Strukturierte JSON-Ausgabe statt Klartext"
}

require_token() {
  [[ -n "${HA_TOKEN:-}" ]] || {
    echo "HA_TOKEN is not set" >&2
    exit 1
  }
}

json_mode=false
[[ "${1:-}" == "--json" ]] && json_mode=true

require_token

# ── Whitelist (muss synchron mit get-state.sh und call-service.sh gehalten werden) ──
WHITELIST=(
  sensor.growbox_temperatur
  sensor.growbox_luftfeuchtigkeit
  sensor.growbox_lufeter_0_rpm
  sensor.growbox_lufeter_1_rpm
  sensor.growbox_lufeter_2_rpm
  sensor.growbox_lufeter_3_rpm
  fan.growbox_lufeter_0
  fan.growbox_lufeter_1
  fan.growbox_lufeter_2
  fan.growbox_lufeter_3
  select.growbox_betriebsmodus
  number.growbox_alle_lufeter_master
  text_sensor.growbox_status
  button.growbox_neustart
)

# ── Live-Entity-IDs von HA laden ──────────────────────────────────────────────
live_entities_json="$(curl -fsS \
  --connect-timeout "$HA_TIMEOUT" \
  --max-time "$HA_TIMEOUT" \
  -H "Authorization: Bearer $HA_TOKEN" \
  -H "Content-Type: application/json" \
  "$HA_URL/api/states" 2>/dev/null)" || {
  echo "HA nicht erreichbar oder Token ungültig" >&2
  exit 1
}

live_ids="$(echo "$live_entities_json" | python3 -c "
import json, sys
states = json.load(sys.stdin)
for s in states:
    print(s['entity_id'])
" 2>/dev/null)" || {
  echo "HA-Antwort konnte nicht geparst werden" >&2
  exit 1
}

# ── Drift-Analyse ─────────────────────────────────────────────────────────────
missing=()
for entity in "${WHITELIST[@]}"; do
  if ! echo "$live_ids" | grep -qF "$entity"; then
    missing+=("$entity")
  fi
done

# ── Ausgabe ───────────────────────────────────────────────────────────────────
total="${#WHITELIST[@]}"
missing_count="${#missing[@]}"
ok_count=$(( total - missing_count ))

if $json_mode; then
  python3 -c "
import json, sys
missing = sys.argv[1].split('\n') if sys.argv[1] else []
missing = [m for m in missing if m]
total = int(sys.argv[2])
print(json.dumps({
  'whitelist_total': total,
  'ok': total - len(missing),
  'missing_count': len(missing),
  'missing': missing,
  'status': 'drift' if missing else 'ok',
}, indent=2))
" "$(IFS=$'\n'; echo "${missing[*]:-}")" "$total"
else
  echo "HA Entity-Whitelist Check"
  echo "  Whitelist-Einträge: $total"
  echo "  In HA vorhanden:    $ok_count"
  echo "  Fehlen in HA:       $missing_count"
  if [[ $missing_count -gt 0 ]]; then
    echo "  DRIFT erkannt:"
    for e in "${missing[@]}"; do
      echo "    - $e"
    done
    exit 2
  else
    echo "  Status: OK – keine Drift"
  fi
fi
