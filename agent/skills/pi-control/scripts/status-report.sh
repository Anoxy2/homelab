#!/bin/bash
# status-report.sh — sammelt Systemstatus für /status Telegram-Befehl
# Output: kompaktes Markdown für Telegram
set -euo pipefail

HA_URL="${HA_URL:-http://192.168.2.101:8123}"
HA_TOKEN="${HA_TOKEN:-}"
THRESHOLDS="/home/steges/growbox/THRESHOLDS.md"

# ─── Docker Services ─────────────────────────────────────────────────────────
echo "🖥️ *Services*"
docker ps --format "{{.Names}} {{.Status}}" | while read -r name status; do
    if echo "$status" | grep -q "unhealthy\|Exited\|Restarting"; then
        echo "  ❌ $name — $status"
    elif echo "$status" | grep -q "healthy"; then
        echo "  ✅ $name"
    else
        echo "  🟡 $name — $status"
    fi
done

echo ""

# ─── System-Metriken ─────────────────────────────────────────────────────────
echo "📊 *System*"

# Temperatur
if command -v vcgencmd >/dev/null 2>&1; then
    temp=$(vcgencmd measure_temp 2>/dev/null | sed 's/temp=//' | sed "s/'C//")
    echo "  🌡️ Temp: ${temp}°C"
fi

# Disk
disk=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
echo "  💾 Disk: $disk"

# RAM
ram=$(free -h | awk '/Mem:/ {print $3 " / " $2}')
echo "  🧠 RAM: $ram"

# Uptime
up=$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | cut -d',' -f1-2)
echo "  ⏱️ Uptime: $up"

echo ""

# ─── Growbox-Sensoren ────────────────────────────────────────────────────────
if [[ -n "$HA_TOKEN" ]]; then
    echo "🌱 *Growbox*"
    for entity in sensor.growbox_temperatur sensor.growbox_luftfeuchtigkeit sensor.growbox_co2; do
        val=$(curl -sf \
            -H "Authorization: Bearer $HA_TOKEN" \
            "$HA_URL/api/states/$entity" 2>/dev/null \
            | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('state','?') + ' ' + d.get('attributes',{}).get('unit_of_measurement',''))" 2>/dev/null || echo "n/a")
        label=$(echo "$entity" | sed 's/sensor\.growbox_//' | sed 's/_/ /g')
        echo "  $label: $val"
    done
fi
