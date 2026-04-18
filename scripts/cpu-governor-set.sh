#!/bin/bash
# CPU Governor auf 'performance' setzen (für Server-Betrieb)
# Usage: sudo ./cpu-governor-set.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Root-Rechte erforderlich. Verwende: sudo $0"
  exit 1
fi

GOVERNOR="performance"

echo "Setze CPU Governor auf '$GOVERNOR'..."

for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
  if [[ -f "$cpu/cpufreq/scaling_governor" ]]; then
    cpu_num=$(basename "$cpu" | sed 's/cpu//')
    echo "$GOVERNOR" > "$cpu/cpufreq/scaling_governor" 2>/dev/null && \
      echo "  CPU ${cpu_num}: OK" || \
      echo "  CPU ${cpu_num}: Fehlgeschlagen (read-only?)"
  fi
done

echo ""
echo "Neuer Status:"
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
