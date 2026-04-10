#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="/home/steges"

# Systemmetriken
metrics_block() {
  local temp load ram swap disk

  # Temp
  if command -v vcgencmd >/dev/null 2>&1 && temp="$(vcgencmd measure_temp 2>/dev/null)"; then
    temp="${temp#temp=}"
  elif [[ -r /sys/class/thermal/thermal_zone0/temp ]]; then
    temp="$(awk '{printf "%.1fC", $1/1000}' /sys/class/thermal/thermal_zone0/temp)"
  else
    temp="?C"
  fi

  # Load
  read -r l1 l5 l15 _ < /proc/loadavg
  load="${l1}/${l5}/${l15}"

  # RAM
  ram="$(free -h | awk '/^Mem:/ { printf "%s/%s (%s)", $3, $2, $5 }')"

  # Swap
  swap="$(free -h | awk '/^Swap:/ { printf "%s/%s", $3, $2 }')"

  # Disk
  disk="$(df -h / | awk 'NR==2 { printf "%s/%s (%s)", $3, $2, $5 }')"

  # Network (schnell, ohne sleep)
  local iface rx1 tx1 rx2 tx2 net_str
  iface="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
  [[ -z "$iface" ]] && iface="eth0"
  rx1="$(awk -v iface="${iface}:" '$1==iface {print $2}' /proc/net/dev 2>/dev/null || echo 0)"
  tx1="$(awk -v iface="${iface}:" '$1==iface {print $10}' /proc/net/dev 2>/dev/null || echo 0)"
  sleep 1
  rx2="$(awk -v iface="${iface}:" '$1==iface {print $2}' /proc/net/dev 2>/dev/null || echo 0)"
  tx2="$(awk -v iface="${iface}:" '$1==iface {print $10}' /proc/net/dev 2>/dev/null || echo 0)"
  net_str="$(python3 -c "
rx=($rx2-$rx1)/1024; tx=($tx2-$tx1)/1024
print(f'\u2193{rx:.1f}kB/s \u2191{tx:.1f}kB/s')
" 2>/dev/null || echo "?")"

  local ts
  ts="$(date '+%Y-%m-%d %H:%M')"
  printf "🖥️  pilab — %s\n" "$ts"
  printf "CPU:   %s | Load: %s\n" "$temp" "$load"
  printf "RAM:   %s | Swap: %s\n" "$ram" "$swap"
  printf "Disk:  %s\n" "$disk"
  printf "Net:   %s\n" "$net_str"
}

# Container-Status
container_block() {
  printf "\n🐳 Container\n"
  (cd "$ROOT_DIR" && docker compose ps --format json 2>/dev/null) | python3 -c "
import json, sys

lines = sys.stdin.read().strip().splitlines()
containers = []
for line in lines:
    try:
        containers.append(json.loads(line))
    except Exception:
        pass

running = sum(1 for c in containers if c.get('State','') == 'running')
total = len(containers)
print(f'  ({running} running / {total} total)')

for c in containers:
    name = c.get('Service', c.get('Name','?'))
    state = c.get('State','?')
    icon = '✅' if state == 'running' else ('❌' if state in ('exited','dead') else '🟡')
    print(f'  {icon} {name}')
" 2>/dev/null || docker compose -f "$ROOT_DIR/docker-compose.yml" ps 2>/dev/null | head -25
}

# Top-3 Container nach CPU
stats_block() {
  printf "\n💾 Stats (Top 3 CPU)\n"
  docker stats --no-stream --format "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | \
    sort -t$'\t' -k2 -rh | head -3 | \
    awk -F'\t' '{printf "  %-30s CPU: %s  RAM: %s\n", $1, $2, $3}'
}

metrics_block
container_block
stats_block
