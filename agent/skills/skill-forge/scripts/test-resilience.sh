#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

main() {
  ensure_dirs
  init_state_files

  local schema_scout="$SM_ROOT/contracts/scout.output.schema.json"

  "$SCRIPT_DIR/policy-lint.sh" >/dev/null

  # Positive contract validation
  "$SCRIPT_DIR/dispatcher.sh" --validate-output "$schema_scout" scout "$SCRIPT_DIR/scout.sh" --summary --json >/dev/null

  # Negative contract validation (expect non-json output)
  if "$SCRIPT_DIR/dispatcher.sh" --validate-output "$schema_scout" scout "$SCRIPT_DIR/scout.sh" --summary >/dev/null 2>&1; then
    echo "FAIL: expected contract output violation"
    exit 1
  fi

  # Freeze should block canary promotion
  "$SCRIPT_DIR/incident-freeze.sh" on >/dev/null
  "$SCRIPT_DIR/canary.sh" start resilience-check 1 >/dev/null
  if "$SCRIPT_DIR/canary.sh" promote resilience-check >/dev/null 2>&1; then
    "$SCRIPT_DIR/incident-freeze.sh" off >/dev/null
    echo "FAIL: expected freeze to block canary promotion"
    exit 1
  fi
  "$SCRIPT_DIR/incident-freeze.sh" off >/dev/null

  # Source spike auto-freeze simulation
  python3 - <<'PY'
import json
from datetime import datetime, timezone
p = '/home/steges/agent/skills/skill-forge/.state/known-skills.json'
with open(p, 'r', encoding='utf-8') as f:
    d = json.load(f)
now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
for i in range(3):
    d[f'resilience-extreme-{i}'] = {
        'slug': f'resilience-extreme-{i}',
        'source': 'skills.sh',
        'status': 'pending-blacklist',
        'vetted_at': now
    }
with open(p, 'w', encoding='utf-8') as f:
    json.dump(d, f, indent=2, sort_keys=True)
PY

  local auto
  auto="$("$SCRIPT_DIR/incident-freeze.sh" auto-check || true)"
  if [[ "$auto" != "AUTO_FREEZE_ON" && "$auto" != "ALREADY_FROZEN" ]]; then
    echo "FAIL: expected auto freeze trigger"
    exit 1
  fi

  "$SCRIPT_DIR/incident-freeze.sh" off >/dev/null
  log_audit "TEST" "resilience" "ok"
  echo "Resilience tests OK"
}

main "$@"
