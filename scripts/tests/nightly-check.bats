#!/usr/bin/env bats

setup() {
  export TEST_ROOT
  TEST_ROOT="$(mktemp -d)"
  export TEST_BIN="$TEST_ROOT/bin"
  export TEST_SCRIPTS="$TEST_ROOT/scripts"
  export TEST_REPO="$TEST_ROOT/repo"
  export TEST_SM_ROOT="$TEST_REPO/agent/skills/skill-manager"
  export TEST_STATE="$TEST_SM_ROOT/.state"

  mkdir -p "$TEST_BIN" "$TEST_SCRIPTS" "$TEST_STATE"

  cat > "$TEST_SCRIPTS/skill-manager" <<'SH'
#!/bin/bash
if [[ "${1:-}" == "policy" && "${2:-}" == "lint" ]]; then
  if [[ "${POLICY_LINT_FAIL:-0}" == "1" ]]; then
    exit 1
  fi
  exit 0
fi
exit 2
SH

  cat > "$TEST_SCRIPTS/health-check.sh" <<'SH'
#!/bin/bash
if [[ "${HEALTH_FAIL:-0}" == "1" ]]; then
  echo "FAIL OpenClaw"
  exit 1
fi
echo "Result: 3 OK, 0 FAIL"
exit 0
SH

  cat > "$TEST_BIN/hostname" <<'SH'
#!/bin/bash
echo nightly-test-host
SH

  cat > "$TEST_BIN/curl" <<'SH'
#!/bin/bash
exit 0
SH

  chmod +x "$TEST_SCRIPTS/skill-manager" "$TEST_SCRIPTS/health-check.sh" "$TEST_BIN/hostname" "$TEST_BIN/curl"

  printf '%s
' '{}' > "$TEST_STATE/known-skills.json"
  printf '%s
' '{}' > "$TEST_STATE/canary.json"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "nightly-check returns 0 when policy lint, health, and canaries are clean" {
  run env \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    NIGHTLY_REPO_ROOT="$TEST_REPO" \
    NIGHTLY_SM_ROOT="$TEST_SM_ROOT" \
    NIGHTLY_STATE_DIR="$TEST_STATE" \
    NIGHTLY_SKILL_MANAGER_CLI="$TEST_SCRIPTS/skill-manager" \
    NIGHTLY_HEALTH_CHECK_SCRIPT="$TEST_SCRIPTS/health-check.sh" \
    NIGHTLY_HOSTNAME_CMD="$TEST_BIN/hostname" \
    /home/steges/scripts/nightly-check.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nightly check: OK"* ]]
}

@test "nightly-check returns 1 for stale canaries and pending-review backlog" {
  cat > "$TEST_STATE/canary.json" <<'JSON'
{
  "stale-skill": {
    "status": "running",
    "started_at": "2026-04-01T00:00:00Z",
    "until": "2026-04-02T00:00:00Z"
  }
}
JSON
  cat > "$TEST_STATE/known-skills.json" <<'JSON'
{
  "skill-a": {"status": "pending-review"},
  "skill-b": {"status": "pending-review"},
  "skill-c": {"status": "pending-review"},
  "skill-d": {"status": "pending-review"},
  "skill-e": {"status": "pending-review"},
  "skill-f": {"status": "pending-review"}
}
JSON

  run env \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    NIGHTLY_REPO_ROOT="$TEST_REPO" \
    NIGHTLY_SM_ROOT="$TEST_SM_ROOT" \
    NIGHTLY_STATE_DIR="$TEST_STATE" \
    NIGHTLY_SKILL_MANAGER_CLI="$TEST_SCRIPTS/skill-manager" \
    NIGHTLY_HEALTH_CHECK_SCRIPT="$TEST_SCRIPTS/health-check.sh" \
    NIGHTLY_HOSTNAME_CMD="$TEST_BIN/hostname" \
    /home/steges/scripts/nightly-check.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"stale-canaries:1"* ]]
  [[ "$output" == *"pending-review:6"* ]]
}
