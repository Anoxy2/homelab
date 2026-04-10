#!/bin/bash
# phase-thresholds.sh — liest aktuelle Grow-Phase aus GROW.md und gibt passende Thresholds aus
# Nutzung: phase-thresholds.sh [--json]
set -euo pipefail

GROW_FILE="/home/steges/growbox/GROW.md"
THRESHOLDS_FILE="/home/steges/growbox/THRESHOLDS.md"
JSON_MODE=0
[[ "${1:-}" == "--json" ]] && JSON_MODE=1

# Phase aus GROW.md extrahieren (1. Treffer: "- **phase:** flower" im Agent-Status Block)
phase_raw=$(grep -im1 '^\s*-\s*\*\*phase:\*\*' "$GROW_FILE" 2>/dev/null \
    | sed 's/.*\*\*phase:\*\*[[:space:]]*//' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]') || phase_raw=""

# Mapping EN → DE Phasennamen
case "$phase_raw" in
    flower|bloom|blt*)   phase_de="Blüte" ;;
    veg|vegetation|veg*) phase_de="Vegetation" ;;
    seedling|keim*)      phase_de="Keimung" ;;
    flush|sp*blte|late*) phase_de="Spätblüte" ;;
    *)                   phase_de="Vegetation" ;;  # fallback
esac

# Thresholds aus THRESHOLDS.md extrahieren (Zeile mit passender Phase)
extract_threshold() {
    local section="$1"
    local phase="$2"
    grep -A20 "^## $section" "$THRESHOLDS_FILE" 2>/dev/null \
        | grep "| $phase " | head -1 \
        | awk -F'|' '{gsub(/[[:space:]]/,"",$2); gsub(/[[:space:]]/,"",$3); gsub(/[[:space:]]/,"",$4); print $3}'
}

temp_warn=$(extract_threshold "Temperatur" "$phase_de" || echo "?")
temp_crit=$(extract_threshold "Temperatur" "$phase_de" 2>/dev/null | awk -F'|' '{print $4}' || echo "?")
rh_warn=$(extract_threshold "Luftfeuchtigkeit" "$phase_de" || echo "?")

# Für einfachere Ausgabe direkt aus THRESHOLDS.md parsen
temp_line=$(grep "| $phase_de " <(grep -A20 "^## Temperatur" "$THRESHOLDS_FILE") | head -1)
rh_line=$(grep "| $phase_de " <(grep -A20 "^## Luftfeuchtigkeit" "$THRESHOLDS_FILE") | head -1)

temp_optimal=$(echo "$temp_line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}')
temp_warn_range=$(echo "$temp_line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$4); print $4}')
temp_crit_range=$(echo "$temp_line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$5); print $5}')
rh_optimal=$(echo "$rh_line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}')
rh_warn_range=$(echo "$rh_line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$4); print $4}')

if [[ $JSON_MODE -eq 1 ]]; then
    python3 -c "
import json
print(json.dumps({
    'phase_raw': '${phase_raw}',
    'phase_de': '${phase_de}',
    'temperature': {
        'optimal': '${temp_optimal}',
        'warning': '${temp_warn_range}',
        'critical': '${temp_crit_range}',
    },
    'humidity': {
        'optimal': '${rh_optimal}',
        'warning': '${rh_warn_range}',
    },
}, ensure_ascii=False, indent=2))
"
else
    echo "Phase: ${phase_raw} → ${phase_de}"
    echo "Temperatur: optimal ${temp_optimal} | warn ${temp_warn_range} | krit ${temp_crit_range}"
    echo "Luftfeuchtigkeit: optimal ${rh_optimal} | warn ${rh_warn_range}"
fi
