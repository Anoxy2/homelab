#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 temp | ram | uptime | load | swap | network | all"
}

read_temp() {
  local t
  if command -v vcgencmd >/dev/null 2>&1 && t="$(vcgencmd measure_temp 2>/dev/null)"; then
    echo "$t"
    return
  fi

  if [[ -r /sys/class/thermal/thermal_zone0/temp ]]; then
    local raw_temp
    raw_temp="$(cat /sys/class/thermal/thermal_zone0/temp)"
    awk -v raw="$raw_temp" 'BEGIN { printf "temp=%.1fC\n", raw / 1000 }'
    return
  fi

  echo "temp=?C"
}

read_load() {
  read -r l1 l5 l15 _ < /proc/loadavg
  echo "Load: ${l1} ${l5} ${l15} (1/5/15min)"
}

read_swap() {
  free -h | awk '/^Swap:/ { printf "Swap: %s used / %s total\n", $3, $2 }'
}

read_network() {
  # Liest RX/TX aus /proc/net/dev, berechnet Delta über 1s
  local iface
  iface="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
  [[ -z "$iface" ]] && iface="eth0"

  local rx1 tx1 rx2 tx2
  rx1="$(awk -v iface="${iface}:" '$1==iface {print $2}' /proc/net/dev 2>/dev/null || echo 0)"
  tx1="$(awk -v iface="${iface}:" '$1==iface {print $10}' /proc/net/dev 2>/dev/null || echo 0)"
  sleep 1
  rx2="$(awk -v iface="${iface}:" '$1==iface {print $2}' /proc/net/dev 2>/dev/null || echo 0)"
  tx2="$(awk -v iface="${iface}:" '$1==iface {print $10}' /proc/net/dev 2>/dev/null || echo 0)"

  python3 -c "
rx = ($rx2 - $rx1) / 1024
tx = ($tx2 - $tx1) / 1024
print(f'Network ($iface): \u2193 {rx:.1f} kB/s \u2191 {tx:.1f} kB/s')
"
}

read_all() {
  local temp ram_line load swap disk
  temp="$(read_temp)"
  ram_line="$(free -h | awk '/^Mem:/ { printf "%s / %s (%s)", $3, $2, $5 }')"
  load="$(read_load)"
  swap="$(read_swap)"
  disk="$(df -h / | awk 'NR==2 { printf "%s / %s (%s)", $3, $2, $5 }')"

  printf '%s\n' \
    "CPU:   ${temp}" \
    "RAM:   ${ram_line}" \
    "Swap:  ${swap#Swap: }" \
    "${load}" \
    "Disk:  ${disk}"
}

action="${1:-}"

case "$action" in
  temp)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    read_temp
    ;;
  ram)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    exec free -h
    ;;
  uptime)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    exec uptime
    ;;
  load)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    read_load
    ;;
  swap)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    read_swap
    ;;
  network)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    read_network
    ;;
  all)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    read_all
    ;;
  *)
    usage
    exit 1
    ;;
esac