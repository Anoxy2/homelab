#!/bin/bash
set -euo pipefail

ROOT="/home/steges"
SM="$ROOT/scripts/skill-forge"
SKILLS="$ROOT/scripts/skills"

assert_exit() {
  local expected="$1"
  shift
  set +e
  "$@" >/tmp/wrapper-test.out 2>/tmp/wrapper-test.err
  local rc=$?
  set -e
  if [[ "$rc" -ne "$expected" ]]; then
    echo "FAIL: expected exit=$expected got=$rc for: $*" >&2
    echo "stdout:" >&2
    cat /tmp/wrapper-test.out >&2 || true
    echo "stderr:" >&2
    cat /tmp/wrapper-test.err >&2 || true
    exit 1
  fi
}

assert_json_file() {
  local path="$1"
  python3 - "$path" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    json.load(f)
PY
}

main() {
  # 1) Contract: both wrappers fail identically on invalid canary verb (usage error).
  assert_exit 2 "$SM" canary
  assert_exit 2 "$SKILLS" canary

  # 2) Contract: canary evaluate returns equivalent JSON through both wrappers.
  "$SM" canary evaluate resilience-check --json > /tmp/sm_canary_contract.json
  "$SKILLS" canary evaluate resilience-check --json > /tmp/skills_canary_contract.json
  assert_json_file /tmp/sm_canary_contract.json
  assert_json_file /tmp/skills_canary_contract.json
  if ! diff -u /tmp/sm_canary_contract.json /tmp/skills_canary_contract.json >/tmp/wrapper-canary.diff; then
    echo "FAIL: canary evaluate wrapper parity mismatch" >&2
    cat /tmp/wrapper-canary.diff >&2 || true
    exit 1
  fi

  # 3) Contract: dispatcher-gated wrapper path is still reachable with valid args.
  "$SM" dispatch scout /home/steges/agent/skills/skill-forge/scripts/scout.sh --summary --json >/tmp/sm_dispatch_contract.json
  assert_json_file /tmp/sm_dispatch_contract.json

  # 4) Contract: semantic scout JSON stays parseable without human header noise.
  "$SKILLS" scout --dry-run --semantic --json > /tmp/skills_scout_semantic_contract.json
  assert_json_file /tmp/skills_scout_semantic_contract.json

  echo "Wrapper contract tests OK"
}

main "$@"