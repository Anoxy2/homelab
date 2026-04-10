#!/bin/bash
# Nightly read-only self-check: health, policy lint, stale canaries, pending-review count
# Designed to run non-destructively; sends a Telegram summary when issues are found.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${NIGHTLY_REPO_ROOT:-/home/steges}"
SM_ROOT="${NIGHTLY_SM_ROOT:-$REPO_ROOT/agent/skills/skill-forge}"
STATE_DIR="${NIGHTLY_STATE_DIR:-$SM_ROOT/.state}"
SKILL_MANAGER_CLI="${NIGHTLY_SKILL_MANAGER_CLI:-$SCRIPT_DIR/skill-forge}"
HEALTH_CHECK_SCRIPT="${NIGHTLY_HEALTH_CHECK_SCRIPT:-$SCRIPT_DIR/health-check.sh}"
HOSTNAME_CMD="${NIGHTLY_HOSTNAME_CMD:-hostname}"

# shellcheck source=/home/steges/scripts/lib/env.sh
source "$SCRIPT_DIR/lib/env.sh"

send_telegram() {
  local msg="$1"
  local token="${TELEGRAM_BOT_TOKEN:-}"
  local chat="${TELEGRAM_CHAT_ID:-}"
  [[ -n "$token" && -n "$chat" ]] || return 0
  curl -sf -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    -d chat_id="$chat" \
    -d parse_mode="HTML" \
    --data-urlencode "text=$msg" >/dev/null || true
}

issues=()
summary_lines=()

# ── 1. Policy lint ────────────────────────────────────────────────────────────
if "$SKILL_MANAGER_CLI" policy lint >/dev/null 2>&1; then
  summary_lines+=("✅ Policy lint: OK")
else
  issues+=("policy-lint-failed")
  summary_lines+=("❌ Policy lint: FAILED")
fi

# ── 2. Stale canaries (running for > 72h) ─────────────────────────────────────
stale_canaries="$(python3 - "$STATE_DIR/canary.json" <<'PY'
import json, sys
from datetime import datetime, timezone, timedelta

path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
except Exception:
    sys.exit(0)

threshold = datetime.now(timezone.utc) - timedelta(hours=72)
stale = []
for slug, v in data.items():
  status = str(v.get('status', v.get('state', '')))
  if status == 'running':
        started = v.get('started_at', '')
        try:
            dt = datetime.fromisoformat(started.replace('Z', '+00:00'))
            if dt < threshold:
                stale.append(slug)
        except Exception:
            pass
print('\n'.join(stale))
PY
)"

if [[ -n "$stale_canaries" ]]; then
  stale_count="$(echo "$stale_canaries" | wc -l | tr -d ' ')"
  issues+=("stale-canaries:${stale_count}")
  summary_lines+=("⚠️  Stale canaries (>72h): ${stale_count} — $(echo "$stale_canaries" | tr '\n' ' ')")
else
  summary_lines+=("✅ Stale canaries: none")
fi

# ── 3. Pending-review count ───────────────────────────────────────────────────
pending_count="$(python3 - "$STATE_DIR/known-skills.json" <<'PY'
import json, sys
try:
    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        data = json.load(f)
    print(sum(1 for v in data.values() if v.get('status') == 'pending-review'))
except Exception:
    print(0)
PY
)"

if (( pending_count > 5 )); then
  issues+=("pending-review:${pending_count}")
  summary_lines+=("⚠️  Pending review: ${pending_count} skills")
elif (( pending_count > 0 )); then
  summary_lines+=("ℹ️  Pending review: ${pending_count} skills")
else
  summary_lines+=("✅ Pending review: 0")
fi

# ── 4. Health check (critical services) ──────────────────────────────────────
set +e
"$HEALTH_CHECK_SCRIPT" >/dev/null 2>&1
health_rc=$?
set -e
if [[ $health_rc -ne 0 ]]; then
  issues+=("health-check-issues")
  summary_lines+=("❌ Health: issues detected")
else
  summary_lines+=("✅ Health: OK")
fi

# ── Summary ───────────────────────────────────────────────────────────────────
load_dotenv

now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
host_name="$("$HOSTNAME_CMD")"
if [[ ${#issues[@]} -gt 0 ]]; then
  issues_str="$(printf '%s, ' "${issues[@]}" | sed 's/, $//')"
  msg="🔍 Nightly Self-Check @ ${host_name} — ${now}
$(printf '%s\n' "${summary_lines[@]}")

Issues: ${issues_str}"
  send_telegram "$msg"
  echo "Nightly check: ${#issues[@]} issues — $issues_str"
  exit 1
else
  msg="🔍 Nightly Self-Check @ ${host_name} — ${now} — All OK
$(printf '%s\n' "${summary_lines[@]}")"
  # Only send Telegram on issues; log locally when clean
  echo "Nightly check: OK"
fi
