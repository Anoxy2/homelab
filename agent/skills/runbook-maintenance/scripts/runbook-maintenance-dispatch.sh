#!/bin/bash
set -euo pipefail

TASK_TIMEOUT="${RUNBOOK_TASK_TIMEOUT:-60}"

usage() {
  cat <<'EOF'
Usage:
  runbook-maintenance-dispatch.sh weekly-check [--json]
  runbook-maintenance-dispatch.sh checklist [--json]
  runbook-maintenance-dispatch.sh failover <openclaw|pihole-dns|esp32|rag> [--json]
EOF
}

run_with_timeout() {
  local timeout_s="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout --signal=TERM --kill-after=5 "${timeout_s}" "$@"
  else
    "$@"
  fi
}

run_check() {
  local name="$1"
  shift

  local started ended duration rc output
  started="$(date +%s)"

  set +e
  output="$(run_with_timeout "$TASK_TIMEOUT" "$@" 2>&1)"
  rc=$?
  set -e

  ended="$(date +%s)"
  duration=$((ended - started))

  if [[ $rc -eq 0 ]]; then
    printf '%s|ok|%s|%s\n' "$name" "$duration" "$(echo "$output" | tail -n 1 | xargs || echo ok)"
  elif [[ $rc -eq 124 ]]; then
    printf '%s|timeout|%s|task exceeded %ss\n' "$name" "$duration" "$TASK_TIMEOUT"
  else
    printf '%s|failed|%s|%s\n' "$name" "$duration" "$(echo "$output" | tail -n 1 | xargs || echo failed)"
  fi
}

cmd_weekly_check() {
  local json_mode="0"
  if [[ "${1:-}" == "--json" ]]; then
    json_mode="1"
  fi

  local tmp
  tmp="$(mktemp)"

  run_check "policy_lint" /home/steges/scripts/skill-forge policy lint >> "$tmp"
  run_check "skill_manager_status" /home/steges/scripts/skill-forge status >> "$tmp"
  run_check "health_check" /home/steges/scripts/health-check.sh >> "$tmp"
  run_check "compose_ps" docker compose -f /home/steges/docker-compose.yml ps >> "$tmp"
  run_check "audit_rejected" /home/steges/scripts/skill-forge audit --rejected >> "$tmp"

  if [[ "$json_mode" == "1" ]]; then
    python3 - "$tmp" <<'PY'
import json
import sys
from datetime import datetime, timezone

path = sys.argv[1]
rows = []
for line in open(path, 'r', encoding='utf-8'):
  line = line.strip()
  if not line:
    continue
  parts = line.split('|', 3)
  if len(parts) != 4:
    continue
  name, status, duration, detail = parts
  rows.append({
    'task': name,
    'status': status,
    'duration_s': int(duration),
    'detail': detail,
  })

failed = [r for r in rows if r['status'] != 'ok']
print(json.dumps({
  'kind': 'runbook_maintenance_weekly_check',
  'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
  'timeout_s': 60,
  'total': len(rows),
  'failed': len(failed),
  'status': 'ok' if not failed else 'needs_attention',
  'results': rows,
}, ensure_ascii=True, indent=2))
PY
  else
    echo "Runbook maintenance weekly-check"
    echo "- timeout per task: ${TASK_TIMEOUT}s"
    local failures=0
    while IFS='|' read -r name status duration detail; do
      [[ -n "$name" ]] || continue
      echo "- ${name}: ${status} (${duration}s) - ${detail}"
      if [[ "$status" != "ok" ]]; then
        failures=$((failures + 1))
      fi
    done < "$tmp"
    if [[ $failures -eq 0 ]]; then
      echo "- overall: ok"
    else
      echo "- overall: needs_attention (${failures} failed/timeout)"
    fi
  fi

  local failures
  failures="$(awk -F'|' '$2 != "ok" {count++} END {print count+0}' "$tmp")"
  rm -f "$tmp"

  if [[ "$failures" -gt 0 ]]; then
    exit 1
  fi
}

cmd_checklist() {
  local json_mode="0"
  if [[ "${1:-}" == "--json" ]]; then
    json_mode="1"
  fi

  if [[ "$json_mode" == "1" ]]; then
    cat <<'EOF'
{
  "kind": "runbook_maintenance_checklist",
  "sequence": [
    {"step": 1, "action": "policy lint", "command": "~/scripts/skill-forge policy lint", "expected_duration_s": 10},
    {"step": 2, "action": "heartbeat dry-run", "command": "~/scripts/skills heartbeat", "expected_duration_s": 60},
    {"step": 3, "action": "status report", "command": "~/scripts/skill-forge status", "expected_duration_s": 10},
    {"step": 4, "action": "health check", "command": "~/scripts/health-check.sh", "expected_duration_s": 30},
    {"step": 5, "action": "audit rejected", "command": "~/scripts/skill-forge audit --rejected", "expected_duration_s": 15}
  ]
}
EOF
  else
    cat <<'EOF'
Runbook maintenance checklist
1. policy lint (~10s): ~/scripts/skill-forge policy lint
2. heartbeat dry-run (~60s): ~/scripts/skills heartbeat
3. status report (~10s): ~/scripts/skill-forge status
4. health check (~30s): ~/scripts/health-check.sh
5. audit rejected (~15s): ~/scripts/skill-forge audit --rejected
EOF
  fi
}

cmd_failover() {
  local scenario="${1:-}"
  local json_mode="${2:-}"

  case "$scenario" in
    openclaw)
      local path="docs/runbooks/openclaw-nicht-erreichbar.md"
      local summary="OpenClaw gateway/service nicht erreichbar"
      ;;
    pihole-dns)
      local path="docs/runbooks/pihole-dns-ausfall.md"
      local summary="DNS-Ausfall im LAN"
      ;;
    esp32)
      local path="docs/runbooks/esp32-offline.md"
      local summary="Growbox ESP32 offline"
      ;;
    rag)
      local path="docs/runbooks/rag-reindex-failure-recovery.md"
      local summary="RAG Reindex Fehler oder Recovery"
      ;;
    *)
      echo "Unbekanntes Failover-Szenario: $scenario" >&2
      exit 2
      ;;
  esac

  if [[ "$json_mode" == "--json" ]]; then
    printf '{"kind":"runbook_failover","scenario":"%s","summary":"%s","runbook":"%s"}\n' "$scenario" "$summary" "$path"
  else
    echo "Failover scenario: ${scenario}"
    echo "- summary: ${summary}"
    echo "- runbook: ${path}"
  fi
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    weekly-check)
      shift
      cmd_weekly_check "$@"
      ;;
    checklist)
      shift
      cmd_checklist "$@"
      ;;
    failover)
      shift
      [[ -n "${1:-}" ]] || { usage; exit 2; }
      cmd_failover "$@"
      ;;
    "")
      usage
      exit 2
      ;;
    *)
      echo "Unbekannter Subcommand: $cmd" >&2
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
