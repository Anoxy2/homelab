#!/bin/bash
# CPU Governor Check & Optimierung für Server-Betrieb

set -euo pipefail

echo "═══════════════════════════════════════════════════════════"
echo "  CPU Governor Status & Optimierung"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Aktueller Governor
current_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
echo "Aktueller Governor: $current_governor"

# Verfügbare Governors
available_governors=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null || echo "unknown")
echo "Verfügbare Governors: $available_governors"
echo ""

# Empfehlung
if [[ "$current_governor" == "performance" ]]; then
  echo "✅ Optimal: 'performance' Governor aktiv (maximale Leistung für Server)"
else
  echo "⚠️  Optimierung empfohlen:"
  echo "   Für Container-Server-Betrieb: 'performance' statt '$current_governor'"
  echo ""
  echo "   Änderung (temporär bis Reboot):"
  echo "     echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
  echo ""
  echo "   Dauerhaft (über /etc/sysfs.conf oder systemd):"
  echo "     /home/steges/scripts/cpu-governor-set.sh"
fi

# Aktuelle Frequenzen
echo ""
echo "Aktuelle CPU-Frequenzen:"
for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
  cpu_num=$(basename "$cpu" | sed 's/cpu//')
  freq=$(cat "$cpu/cpufreq/scaling_cur_freq" 2>/dev/null || echo "N/A")
  if [[ "$freq" != "N/A" && -n "$freq" ]]; then
    freq_mhz=$((freq / 1000))
    echo "  CPU ${cpu_num}: ${freq_mhz} MHz"
  fi
done

# Temperatur
echo ""
temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
if [[ "$temp_raw" != "0" ]]; then
  temp_c=$((temp_raw / 1000))
  echo "CPU Temperatur: ${temp_c}°C"
fi

# Throttling-Status (falls vcgencmd verfügbar)
if command -v vcgencmd >/dev/null 2>&1; then
  echo ""
  throttled=$(vcgencmd get_throttled 2>/dev/null | cut -d'=' -f2 || echo "N/A")
  echo "Throttling Status: $throttled"
  if [[ "$throttled" != "0x0" && "$throttled" != "N/A" ]]; then
    echo "⚠️  Throttling erkannt! Temperatur/Spannung prüfen."
  else
    echo "✅ Kein Throttling"
  fi
fi

exit 0
