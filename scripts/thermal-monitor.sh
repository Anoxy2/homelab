#!/bin/bash
# Thermal Throttling Monitor für Raspberry Pi 5
# Loggt vcgencmd get_throttled persistent, Alert bei Throttling

set -euo pipefail

LOG_FILE="/home/steges/logs/thermal-throttling.log"
ALERT_FILE="/tmp/thermal-alert-triggered"
THROTTLED_MASK=0x0

# Throttle Bits (vcgencmd get_throttled):
# 0: Under-voltage detected
# 1: Arm frequency capped
# 2: Currently throttled
# 3: Soft temperature limit active
# 16: Under-voltage has occurred
# 17: Arm frequency capped has occurred
# 18: Throttling has occurred
# 19: Soft temperature limit has occurred

mkdir -p "$(dirname "$LOG_FILE")"

get_throttled_value() {
  vcgencmd get_throttled 2>/dev/null | cut -d'=' -f2 || echo "0x0"
}

get_temperature() {
  vcgencmd measure_temp 2>/dev/null | cut -d'=' -f2 | cut -d"'" -f1 || echo "0"
}

get_cpu_freq() {
  vcgencmd measure_clock arm 2>/dev/null | cut -d'=' -f2 || echo "0"
}

# Throttle-Bits dekodieren
decode_throttled() {
  local hex_value="${1:-0x0}"
  local value=$((hex_value))
  local reasons=""
  
  ((value & 0x1)) && reasons+="UNDER_VOLTAGE "
  ((value & 0x2)) && reasons+="FREQ_CAPPED "
  ((value & 0x4)) && reasons+="THROTTLED "
  ((value & 0x8)) && reasons+="SOFT_TEMP_LIMIT "
  ((value & 0x10000)) && reasons+="UNDER_VOLTAGE_OCCURRED "
  ((value & 0x20000)) && reasons+="FREQ_CAPPED_OCCURRED "
  ((value & 0x40000)) && reasons+="THROTTLED_OCCURRED "
  ((value & 0x80000)) && reasons+="SOFT_TEMP_LIMIT_OCCURRED "
  
  echo "${reasons:-NONE}"
}

# Prüfe ob aktuell throttled oder history
is_throttling() {
  local hex_value="${1:-0x0}"
  local value=$((hex_value))
  # Aktuell throttled (Bits 0-3) oder jemals aufgetreten (Bits 16-19)
  ((value & 0xF || value & 0xF0000))
}

# Haupt-Monitoring
throttled_hex=$(get_throttled_value)
temp=$(get_temperature)
cpu_freq=$(get_cpu_freq)
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
decoded=$(decode_throttled "$throttled_hex")

# Log-Eintrag
log_entry="$timestamp | Temp: ${temp}°C | Freq: ${cpu_freq} Hz | Throttled: $throttled_hex | Status: $decoded"
echo "$log_entry" >> "$LOG_FILE"

# Auf Throttling prüfen und Alert triggern
if is_throttling "$throttled_hex"; then
  if [[ ! -f "$ALERT_FILE" ]]; then
    # Neues Throttling-Event
    touch "$ALERT_FILE"
    echo "[ALERT] Thermal Throttling erkannt!"
    echo "  Details: $decoded"
    echo "  Temperatur: ${temp}°C"
    echo "  Frequenz: ${cpu_freq} Hz"
    
    # Optional: Telegram-Alert (falls konfiguriert)
    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
      message="🌡️ RPi5 Thermal Throttling!%0A"
      message+="Temp: ${temp}°C%0A"
      message+="Status: ${decoded}%0A"
      message+="Zeit: ${timestamp}"
      curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" >/dev/null 2>&1 || true
    fi
  fi
else
  # Kein Throttling - Alert-Datei entfernen (für nächstes Event)
  rm -f "$ALERT_FILE"
fi

# Log-Rotation (nur letzte 1000 Zeilen behalten)
if [[ $(wc -l < "$LOG_FILE") -gt 1000 ]]; then
  tail -n 1000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

exit 0
