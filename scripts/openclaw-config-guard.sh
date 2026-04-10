#!/bin/bash
# Guarded writer for OpenClaw config operations.
# Prevents concurrent config writes and retries EBUSY failures.

set -euo pipefail

LOCK_FILE="${OPENCLAW_CONFIG_LOCK_FILE:-/home/steges/infra/openclaw-data/openclaw-config-write.lock}"
AUDIT_LOG="${OPENCLAW_CONFIG_AUDIT_LOG:-/home/steges/infra/openclaw-data/logs/config-audit.jsonl}"
MAX_RETRIES="${OPENCLAW_CONFIG_MAX_RETRIES:-5}"
BACKOFF_SECONDS="${OPENCLAW_CONFIG_BACKOFF_SECONDS:-1}"

usage() {
  cat <<'EOF'
Usage:
  openclaw-config-guard.sh run -- <command> [args...]
  openclaw-config-guard.sh login-github-copilot
  openclaw-config-guard.sh ebusy-rate [hours]
  openclaw-config-guard.sh compare [baseline_hours] [recent_hours]

Commands:
  run -- <command...>
      Runs a command under an exclusive lock and retries on EBUSY errors.

  login-github-copilot
      Convenience wrapper for:
      docker exec openclaw openclaw models auth login-github-copilot

  ebusy-rate [hours]
      Reads config-audit.jsonl and prints EBUSY rate for the last N hours (default: 24).

  compare [baseline_hours] [recent_hours]
      Compares two windows in config-audit.jsonl:
      - baseline window: now-(baseline+recent) .. now-recent
      - recent window:   now-recent .. now
      Defaults: baseline=168h, recent=24h
EOF
}

ensure_lock_dir() {
  mkdir -p "$(dirname "$LOCK_FILE")"
}

run_with_lock_and_retry() {
  local -a command_args=("$@")
  local attempt=1

  [[ ${#command_args[@]} -gt 0 ]] || {
    echo "Missing command for run." >&2
    exit 2
  }

  ensure_lock_dir

  if ! command -v flock >/dev/null 2>&1; then
    echo "flock not found; running command without lock." >&2
    exec "${command_args[@]}"
  fi

  exec {lock_fd}>"$LOCK_FILE"
  flock "$lock_fd"

  while (( attempt <= MAX_RETRIES )); do
    local tmp
    tmp="$(mktemp)"

    set +e
    "${command_args[@]}" >"$tmp" 2>&1
    local rc=$?
    set -e

    cat "$tmp"

    if [[ $rc -eq 0 ]]; then
      rm -f "$tmp"
      flock -u "$lock_fd"
      exec {lock_fd}>&-
      return 0
    fi

    if grep -qi "\bebusy\b" "$tmp" && (( attempt < MAX_RETRIES )); then
      echo "openclaw-config-guard: EBUSY detected (attempt ${attempt}/${MAX_RETRIES}), retrying..." >&2
      rm -f "$tmp"
      sleep "$BACKOFF_SECONDS"
      attempt=$((attempt + 1))
      continue
    fi

    rm -f "$tmp"
    flock -u "$lock_fd"
    exec {lock_fd}>&-
    return "$rc"
  done

  flock -u "$lock_fd"
  exec {lock_fd}>&-
  return 1
}

print_ebusy_rate() {
  local hours="${1:-24}"
  python3 - "$AUDIT_LOG" "$hours" <<'PY'
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone

path = sys.argv[1]
hours = int(sys.argv[2])

if not os.path.exists(path):
    print(json.dumps({
        'window_hours': hours,
        'total_events': 0,
        'ebusy_events': 0,
        'ebusy_rate': 0.0,
        'note': 'audit-log missing'
    }, indent=2))
    raise SystemExit(0)

cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)

total = 0
ebusy = 0

with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    for ln in f:
        ln = ln.strip()
        if not ln:
            continue
        try:
            obj = json.loads(ln)
        except json.JSONDecodeError:
            continue

        ts = obj.get('ts')
        if not ts:
            continue
        try:
            dt = datetime.strptime(ts, '%Y-%m-%dT%H:%M:%S.%fZ').replace(tzinfo=timezone.utc)
        except ValueError:
            try:
                dt = datetime.strptime(ts, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
            except ValueError:
                continue
        if dt < cutoff:
            continue

        if obj.get('event') != 'config.write':
            continue

        total += 1
        msg = str(obj.get('errorMessage', '')) + ' ' + str(obj.get('errorCode', ''))
        if re.search(r'\bebusy\b', msg, re.IGNORECASE):
            ebusy += 1

rate = (ebusy / total) if total else 0.0
print(json.dumps({
    'window_hours': hours,
    'total_events': total,
    'ebusy_events': ebusy,
    'ebusy_rate': round(rate, 6)
}, indent=2))
PY
}

compare_windows() {
  local baseline_hours="${1:-168}"
  local recent_hours="${2:-24}"

  python3 - "$AUDIT_LOG" "$baseline_hours" "$recent_hours" <<'PY'
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone

path = sys.argv[1]
baseline_h = int(sys.argv[2])
recent_h = int(sys.argv[3])

out = {
    'baseline_hours': baseline_h,
    'recent_hours': recent_h,
    'baseline': {'total_events': 0, 'ebusy_events': 0, 'ebusy_rate': 0.0},
    'recent': {'total_events': 0, 'ebusy_events': 0, 'ebusy_rate': 0.0},
}

if not os.path.exists(path):
    out['note'] = 'audit-log missing'
    print(json.dumps(out, indent=2))
    raise SystemExit(0)

now = datetime.now(timezone.utc)
recent_start = now - timedelta(hours=recent_h)
baseline_start = recent_start - timedelta(hours=baseline_h)

def parse_ts(ts: str):
    for fmt in ('%Y-%m-%dT%H:%M:%S.%fZ', '%Y-%m-%dT%H:%M:%SZ'):
        try:
            return datetime.strptime(ts, fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    return None

with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    for ln in f:
        ln = ln.strip()
        if not ln:
            continue
        try:
            obj = json.loads(ln)
        except json.JSONDecodeError:
            continue

        if obj.get('event') != 'config.write':
            continue

        dt = parse_ts(str(obj.get('ts', '')))
        if dt is None:
            continue

        msg = str(obj.get('errorMessage', '')) + ' ' + str(obj.get('errorCode', ''))
        is_ebusy = bool(re.search(r'\bebusy\b', msg, re.IGNORECASE))

        if recent_start <= dt <= now:
            out['recent']['total_events'] += 1
            if is_ebusy:
                out['recent']['ebusy_events'] += 1
        elif baseline_start <= dt < recent_start:
            out['baseline']['total_events'] += 1
            if is_ebusy:
                out['baseline']['ebusy_events'] += 1

for key in ('baseline', 'recent'):
    total = out[key]['total_events']
    eb = out[key]['ebusy_events']
    out[key]['ebusy_rate'] = round((eb / total) if total else 0.0, 6)

out['delta_ebusy_rate'] = round(out['recent']['ebusy_rate'] - out['baseline']['ebusy_rate'], 6)
out['improved_or_equal'] = out['delta_ebusy_rate'] <= 0

print(json.dumps(out, indent=2))
PY
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    run)
      shift
      [[ "${1:-}" == "--" ]] || { usage; exit 2; }
      shift
      run_with_lock_and_retry "$@"
      ;;
    login-github-copilot)
      run_with_lock_and_retry docker exec openclaw openclaw models auth login-github-copilot
      ;;
    ebusy-rate)
      shift
      print_ebusy_rate "${1:-24}"
      ;;
    compare)
      shift
      compare_windows "${1:-168}" "${2:-24}"
      ;;
    --help|-h|help|"")
      usage
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

main "$@"
