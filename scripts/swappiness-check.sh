#!/bin/bash
# Swappiness Check & Optimierung für NVMe-Systeme

set -euo pipefail

echo "═══════════════════════════════════════════════════════════"
echo "  Swappiness & VM-Parameter Check"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Aktuelle Werte
current_swappiness=$(cat /proc/sys/vm/swappiness)
current_cache_pressure=$(cat /proc/sys/vm/vfs_cache_pressure 2>/dev/null || echo "100")

echo "Aktuelle Einstellungen:"
echo "  vm.swappiness: $current_swappiness"
echo "  vm.vfs_cache_pressure: $current_cache_pressure"
echo ""

# Empfehlung
if [[ "$current_swappiness" -lt 20 ]]; then
  echo "⚠️  Swappiness sehr niedrig ($current_swappiness)"
  echo "   Für NVMe-Systeme empfohlen: 20-30"
  echo "   Niedriger Wert = weniger Swap-Nutzung, mehr RAM-Druck"
  echo ""
  echo "   Temporäre Änderung:"
  echo "     sudo sysctl vm.swappiness=20"
  echo ""
  echo "   Dauerhaft (sysctl.conf):"
  echo "     echo 'vm.swappiness=20' | sudo tee /etc/sysctl.d/99-swap.conf"
  echo "     sudo sysctl --system"
elif [[ "$current_swappiness" -gt 60 ]]; then
  echo "⚠️  Swappiness sehr hoch ($current_swappiness)"
  echo "   Für Server-Betrieb evtl. zu aggressives Swapping"
else
  echo "✅ Swappiness im optimalen Bereich ($current_swappiness)"
fi

echo ""
echo "Speicher-Status:"
free -h | grep -E "(Mem|Swap)"
