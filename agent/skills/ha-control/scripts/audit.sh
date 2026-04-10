#!/bin/bash
set -euo pipefail
# audit.sh — Read-only HA Diagnostics. Kein Write-Pfad.

HA_URL="http://192.168.2.101:8123"
HA_TIMEOUT="${HA_TIMEOUT:-15}"

usage() {
  echo "Usage: $0 <subcommand> [options]"
  echo ""
  echo "Subcommands (alle read-only):"
  echo "  health                       HA Core Health-Check"
  echo "  states [--domain <domain>]   Alle Entity-States"
  echo "  history <entity_id>          24h State-History"
  echo "  logs [--count N]             HA Logbook (default: 30)"
  echo "  automations                  Alle Automationen + Status"
}

require_token() {
  [[ -n "${HA_TOKEN:-}" ]] || { echo "HA_TOKEN is not set" >&2; exit 1; }
}

ha_get() {
  local path="$1"
  curl -fsS \
    --connect-timeout "$HA_TIMEOUT" \
    --max-time "$HA_TIMEOUT" \
    -H "Authorization: Bearer $HA_TOKEN" \
    -H "Content-Type: application/json" \
    "$HA_URL$path"
}

require_token

subcmd="${1:-}"
shift || true

case "$subcmd" in
  health)
    echo "=== Home Assistant Health ==="
    ha_get "/api/" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'Version:   {d.get(\"version\", \"?\")}')
print(f'Message:   {d.get(\"message\", \"ok\")}')
" 2>/dev/null || echo "HA nicht erreichbar"
    ;;

  states)
    domain_filter=""
    for arg in "$@"; do
      case "$arg" in
        --domain) : ;;
        -*) ;;
        *) domain_filter="$arg" ;;
      esac
    done
    tmp="$(mktemp)"
    ha_get "/api/states" -o "$tmp" 2>/dev/null || { rm -f "$tmp"; echo "HA nicht erreichbar" >&2; exit 1; }
    # shellcheck disable=SC2002
    python3 - "$tmp" "$domain_filter" <<'PY'
import json, sys
path, dom_filter = sys.argv[1], sys.argv[2]
with open(path) as f:
    states = json.load(f)
filtered = [s for s in states if not dom_filter or s['entity_id'].startswith(dom_filter + '.')]
filtered.sort(key=lambda x: x['entity_id'])
print(f"{'Entity ID':<45} {'State':<20} {'Last changed'}")
print('-' * 90)
for s in filtered[:80]:
    eid = s.get('entity_id', '?')
    state = s.get('state', '?')
    changed = s.get('last_changed', '?')[:16]
    print(f"{eid:<45} {state:<20} {changed}")
if len(filtered) > 80:
    print(f"\n[{len(filtered)-80} weitere nicht angezeigt]")
PY
    rm -f "$tmp"
    ;;

  history)
    [[ $# -ge 1 ]] || { echo "Usage: $0 history <entity_id>" >&2; exit 1; }
    entity_id="$1"
    since="$(date -u -d '24 hours ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || \
             python3 -c 'from datetime import datetime,timedelta,timezone; print((datetime.now(timezone.utc)-timedelta(hours=24)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
    tmp="$(mktemp)"
    ha_get "/api/history/period/${since}?filter_entity_id=${entity_id}&minimal_response=1" > "$tmp" 2>/dev/null || {
      rm -f "$tmp"; echo "HA nicht erreichbar" >&2; exit 1
    }
    python3 - "$tmp" "$entity_id" <<'PY'
import json, sys
path, eid = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
if not data or not data[0]:
    print(f"Keine History für {eid} in den letzten 24h")
    sys.exit(0)
print(f"History: {eid} (letzte 24h, max 30 Einträge)")
print(f"{'Zeitpunkt':<25} {'State'}")
print('-' * 50)
for entry in data[0][-30:]:
    ts = entry.get('last_changed', entry.get('lu', '?'))[:16]
    state = entry.get('state', '?')
    print(f"{ts:<25} {state}")
PY
    rm -f "$tmp"
    ;;

  logs)
    count=30
    for arg in "$@"; do
      case "$arg" in
        --count) : ;;
        [0-9]*) count="$arg" ;;
      esac
    done
    tmp="$(mktemp)"
    ha_get "/api/logbook?limit=${count}" > "$tmp" 2>/dev/null || {
      rm -f "$tmp"; echo "HA nicht erreichbar" >&2; exit 1
    }
    python3 - "$tmp" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    entries = json.load(f)
print(f"Logbook (letzte {len(entries)} Einträge):")
print(f"{'Zeit':<25} {'Domain':<20} {'Message'}")
print('-' * 80)
for e in entries:
    ts = e.get('when', '?')[:16]
    domain = e.get('domain', e.get('entity_id', '?'))[:18]
    msg = e.get('message', e.get('name', '?'))[:50]
    print(f"{ts:<25} {domain:<20} {msg}")
PY
    rm -f "$tmp"
    ;;

  automations)
    tmp="$(mktemp)"
    ha_get "/api/states" > "$tmp" 2>/dev/null || {
      rm -f "$tmp"; echo "HA nicht erreichbar" >&2; exit 1
    }
    python3 - "$tmp" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    states = json.load(f)
autos = [s for s in states if s.get('entity_id','').startswith('automation.')]
autos.sort(key=lambda x: x['entity_id'])
print(f"Automationen ({len(autos)} total):")
print(f"{'Entity ID':<45} {'State':<10} {'Name'}")
print('-' * 80)
for a in autos:
    eid = a.get('entity_id', '?')
    state = a.get('state', '?')
    name = a.get('attributes', {}).get('friendly_name', '')
    icon = '✅' if state == 'on' else '⏸️ '
    print(f"{icon} {eid:<43} {state:<10} {name}")
PY
    rm -f "$tmp"
    ;;

  ""|--help|-h)
    usage
    exit 0
    ;;
  *)
    echo "Unknown subcommand: $subcmd" >&2
    usage
    exit 1
    ;;
esac
