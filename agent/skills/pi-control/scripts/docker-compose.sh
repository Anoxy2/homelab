#!/bin/bash
set -euo pipefail

ROOT_DIR="/home/steges"
RATE_LIMIT_DIR="/tmp/pi-control-restart-rate"
RATE_LIMIT_WINDOW=120  # seconds between restarts of the same service
LOGS_TIMEOUT="${PI_CONTROL_LOGS_TIMEOUT:-30}"

usage() {
  echo "Usage: $0 ps | restart <service> [--dry-run] | logs <service> [tail] | stats | inspect <service> | images"
}

list_services() {
  (cd "$ROOT_DIR" && docker compose config --services)
}

require_service() {
  local service="$1"
  if ! list_services | grep -Fxq "$service"; then
    echo "Unknown compose service: $service" >&2
    exit 1
  fi
}

check_restart_rate_limit() {
  local service="$1"
  mkdir -p "$RATE_LIMIT_DIR"
  local stamp_file="$RATE_LIMIT_DIR/${service}.last"
  if [[ -f "$stamp_file" ]]; then
    local last_restart
    last_restart=$(cat "$stamp_file" 2>/dev/null || echo 0)
    [[ "$last_restart" =~ ^[0-9]+$ ]] || last_restart=0
    local now
    now=$(date +%s)
    local elapsed=$(( now - last_restart ))
    if (( elapsed < RATE_LIMIT_WINDOW )); then
      local remaining=$(( RATE_LIMIT_WINDOW - elapsed ))
      echo "Rate limit: ${service} was restarted ${elapsed}s ago. Wait ${remaining}s." >&2
      exit 1
    fi
  fi
  date +%s > "$stamp_file"
}

action="${1:-}"

case "$action" in
  ps)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    cd "$ROOT_DIR"
    exec docker compose ps
    ;;
  restart)
    [[ $# -ge 2 && $# -le 3 ]] || { usage; exit 1; }
    require_service "$2"
    dry_run="${3:-}"
    if [[ "$dry_run" == "--dry-run" ]]; then
      echo "Dry-run: would restart $2 (no action taken)"
      exit 0
    fi
    [[ -z "$dry_run" ]] || { usage; exit 1; }
    check_restart_rate_limit "$2"
    cd "$ROOT_DIR"
    exec docker compose restart "$2"
    ;;
  logs)
    [[ $# -ge 2 && $# -le 3 ]] || { usage; exit 1; }
    require_service "$2"
    tail_lines="${3:-50}"
    [[ "$tail_lines" =~ ^[0-9]+$ ]] || {
      echo "Tail must be a positive integer" >&2
      exit 1
    }
    if (( tail_lines < 1 || tail_lines > 200 )); then
      echo "Tail must be between 1 and 200" >&2
      exit 1
    fi
    cd "$ROOT_DIR"
    if command -v timeout >/dev/null 2>&1; then
      set +e
      timeout --signal=TERM --kill-after=5 "$LOGS_TIMEOUT" docker compose logs --tail "$tail_lines" "$2"
      rc=$?
      set -e
      if [[ $rc -eq 124 ]]; then
        echo "Logs truncated after ${LOGS_TIMEOUT}s timeout for service: $2" >&2
        exit 0
      fi
      exit "$rc"
    fi
    exec docker compose logs --tail "$tail_lines" "$2"
    ;;
  stats)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    cd "$ROOT_DIR"
    exec docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    ;;
  inspect)
    [[ $# -eq 2 ]] || { usage; exit 1; }
    require_service "$2"
    # Container-Name ermitteln (compose service → container)
    container_name="$(cd "$ROOT_DIR" && docker compose ps -q "$2" 2>/dev/null | head -1)"
    if [[ -z "$container_name" ]]; then
      echo "Service '$2' has no running container" >&2
      exit 1
    fi
    # Env-Keys ohne Values ausgeben (Secrets-Schutz)
    docker inspect "$container_name" | python3 -c "
import json, sys
data = json.load(sys.stdin)[0]
cfg = data.get('Config', {})
host = data.get('HostConfig', {})
net = data.get('NetworkSettings', {})

print('=== Ports ===')
ports = net.get('Ports', {})
for p, bindings in ports.items():
    if bindings:
        for b in bindings:
            print(f'  {p} -> {b[\"HostIp\"]}:{b[\"HostPort\"]}')
    else:
        print(f'  {p} (not published)')

print('=== Volumes ===')
for m in data.get('Mounts', []):
    print(f'  {m.get(\"Source\",\"?\")} -> {m.get(\"Destination\",\"?\")} [{m.get(\"Mode\",\"?\")}]')

print('=== Env Keys (no values) ===')
for e in cfg.get('Env', []):
    key = e.split('=', 1)[0]
    print(f'  {key}')

print('=== Status ===')
state = data.get('State', {})
print(f'  Status:  {state.get(\"Status\",\"?\")}')
print(f'  Started: {state.get(\"StartedAt\",\"?\")[:19]}')
print(f'  Image:   {cfg.get(\"Image\",\"?\")}')
print(f'  Restart: {host.get(\"RestartPolicy\",{}).get(\"Name\",\"?\")}')
"
    ;;
  images)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    exec docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
    ;;
  *)
    usage
    exit 1
    ;;
esac