#!/bin/bash
# test-allowlist.sh – Verifies pi-control docker-compose.sh deny-by-default behaviour.
# Must be run with a valid compose environment (ROOT_DIR docker-compose.yml exists).
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/docker-compose.sh"
PASS=0
FAIL=0

ok()   { echo "PASS: $1"; PASS=$(( PASS + 1 )); }
fail() { echo "FAIL: $1"; FAIL=$(( FAIL + 1 )); }

# ── Test: unknown action is rejected ─────────────────────────────────────────
if "$SCRIPT" exec-arbitrary 2>/dev/null; then
  fail "unknown action 'exec-arbitrary' should be denied"
else
  ok "unknown action denied"
fi

# ── Test: unknown service name is rejected ────────────────────────────────────
if "$SCRIPT" restart not-a-real-service-xyz 2>/dev/null; then
  fail "unknown service 'not-a-real-service-xyz' should be denied"
else
  ok "unknown service denied"
fi

# ── Test: dry-run on unknown service is also rejected ────────────────────────
if "$SCRIPT" restart not-a-real-service-xyz --dry-run 2>/dev/null; then
  fail "unknown service with --dry-run should be denied"
else
  ok "unknown service denied even with --dry-run"
fi

# ── Test: dry-run on known service succeeds without docker call ───────────────
known_service=""
{ known_service=$(cd /home/steges && docker compose config --services 2>/dev/null | head -1); } || true
if [[ -n "$known_service" ]]; then
  out=$("$SCRIPT" restart "$known_service" --dry-run 2>&1)
  if echo "$out" | grep -q "Dry-run"; then
    ok "dry-run on '$known_service' returns dry-run message"
  else
    fail "dry-run on '$known_service' did not return expected message (got: $out)"
  fi
else
  echo "SKIP: could not determine known service name"
fi

# ── Test: invalid extra arg is rejected ───────────────────────────────────────
if "$SCRIPT" restart 2>/dev/null; then
  fail "restart with no service should be denied"
else
  ok "restart with no service denied"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]]
