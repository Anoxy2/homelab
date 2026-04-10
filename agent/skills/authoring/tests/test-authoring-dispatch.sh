#!/bin/bash
set -euo pipefail

SCRIPT="/home/steges/agent/skills/authoring/scripts/authoring-dispatch.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

SM_ROOT="$TMP_ROOT/sm"
STATE_DIR="$SM_ROOT/.state"
SKILLS_ROOT="$TMP_ROOT/skills"
AUDIT_LOG="$STATE_DIR/audit-log.jsonl"

mkdir -p "$SM_ROOT/templates/skill" "$SM_ROOT/catalog" "$STATE_DIR" "$SKILLS_ROOT/existing-skill"
printf '%s
' '---' 'name: {{NAME}}' 'description: {{DESCRIPTION}}' '---' '' '# {{NAME}}' '' '## Purpose' '{{PURPOSE}}' '' '## Trigger' '{{TRIGGER}}' > "$SM_ROOT/templates/skill/SKILL.template.md"
printf '%s
' '{"templates":[],"tested_skills":[{"name":"skill-forge","health":90}]}' > "$SM_ROOT/catalog/tested-skills.json"
printf '%s
' '{}' > "$STATE_DIR/known-skills.json"
printf '%s
' '[]' > "$STATE_DIR/author-queue.json"
printf '%s
' '{"enabled":false,"changed_at":null,"reason":""}' > "$STATE_DIR/incident-freeze.json"
: > "$AUDIT_LOG"

PASS=0
FAIL=0
ok() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

chmod +x "$SCRIPT"

AUTHORING_SM_ROOT="$SM_ROOT" \
AUTHORING_STATE_DIR="$STATE_DIR" \
AUTHORING_SKILLS_ROOT="$SKILLS_ROOT" \
AUTHORING_AUDIT_LOG="$AUDIT_LOG" \
"$SCRIPT" "Sample Skill" --mode template --reason "template draft" >/tmp/authoring-test.out 2>/tmp/authoring-test.err || {
  cat /tmp/authoring-test.err >&2
  fail "initial draft creation failed"
}

if [[ -d "$SKILLS_ROOT/sample-skill/agents" && -d "$SKILLS_ROOT/sample-skill/contracts" && -d "$SKILLS_ROOT/sample-skill/scripts" && -f "$SKILLS_ROOT/sample-skill/SKILL.md" ]]; then
  ok "draft scaffold contains expected directories and SKILL.md"
else
  fail "draft scaffold missing expected directories or SKILL.md"
fi

if [[ -f "$SKILLS_ROOT/sample-skill/contracts/default.output.schema.json" && -x "$SKILLS_ROOT/sample-skill/scripts/sample-skill-dispatch.sh" ]]; then
  ok "default contract and executable dispatch skeleton created"
else
  fail "default contract or dispatch skeleton missing"
fi

python3 - "$STATE_DIR/known-skills.json" "$STATE_DIR/author-queue.json" <<'PY' >/tmp/authoring-assert.out || exit 1
import json, sys
known_path, queue_path = sys.argv[1:3]
with open(known_path, 'r', encoding='utf-8') as f:
    known = json.load(f)
with open(queue_path, 'r', encoding='utf-8') as f:
    queue = json.load(f)
row = known['sample-skill']
assert row['display_name'] == 'Sample Skill'
assert row['authoring_mode'] == 'template'
assert row['authoring_quality_score'] == 90
assert row['authoring_quality_tier'] == 'high'
assert queue[-1]['slug'] == 'sample-skill'
assert queue[-1]['quality_score'] == 90
print('ok')
PY
if [[ $? -eq 0 ]]; then
  ok "known-skills and author-queue contain slug + quality metadata"
else
  fail "known-skills or author-queue metadata incorrect"
fi

set +e
AUTHORING_SM_ROOT="$SM_ROOT" \
AUTHORING_STATE_DIR="$STATE_DIR" \
AUTHORING_SKILLS_ROOT="$SKILLS_ROOT" \
AUTHORING_AUDIT_LOG="$AUDIT_LOG" \
"$SCRIPT" "Sample_Skill" --mode template --reason "collision check" >/tmp/authoring-dupe.out 2>/tmp/authoring-dupe.err
rc=$?
set -e
if [[ $rc -ne 0 ]] && grep -q "Normalized slug collision" /tmp/authoring-dupe.err; then
  ok "normalized slug collision rejected"
else
  fail "normalized slug collision was not rejected"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
