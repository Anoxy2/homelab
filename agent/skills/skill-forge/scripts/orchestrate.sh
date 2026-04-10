#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

usage() {
  echo "Usage: orchestrate.sh [--live [limit]] [--vet-score <n>] [--json]"
}

# ── Tier-adjusted score ───────────────────────────────────────────────────────
tier_adjusted_score_for_slug() {
  local slug="$1"
  local base_score="$2"
  python3 - "$slug" "$base_score" <<'PY'
import json, sys
slug, base = sys.argv[1], int(sys.argv[2])
kp='/home/steges/agent/skills/skill-forge/.state/known-skills.json'
sp='/home/steges/agent/skills/skill-forge/policy/source-trust-policy.yaml'

with open(kp,'r',encoding='utf-8') as f:
    known=json.load(f)
source=known.get(slug,{}).get('source','unknown')

tier='medium'
current=None
with open(sp,'r',encoding='utf-8') as f:
    for raw in f:
        line=raw.rstrip('\n')
        if line.startswith('  ') and line.strip().endswith(':') and not line.strip().startswith('trust_tier'):
            current=line.strip().rstrip(':')
            continue
        if 'trust_tier:' in line and current==source:
            tier=line.split(':',1)[1].strip()
            break

adj = {'high': 8, 'medium': 0, 'low': -8}.get(tier, -4)
score=max(0,min(100, base+adj))
print(score)
print(tier)
PY
}

# ── Acceptance gates ──────────────────────────────────────────────────────────
# NOTE: test-vetting.sh is intentionally NOT called here.
# Reason: skill-forge orchestrate runs under outer flock (STATE_LOCK via
# run_locked_cmd). test-vetting.sh calls vet.sh which calls with_state_lock →
# same lock file → deadlock. Run: ~/scripts/skill-forge test vetting
# separately to verify vetting regression tests.
acceptance_gates() {
  "$SCRIPT_DIR/policy-lint.sh" >/dev/null
}

# ── Step 1: discover ──────────────────────────────────────────────────────────
# Runs scout and collects currently-discovered slugs from state.
# Args: live limit run_id verbose out_file
# Output: JSON → out_file
#   {"kind":"step_discover","run_id":"...","slugs":[...],"count":N}
step_discover() {
  local live="$1" limit="$2" run_id="$3" verbose="$4" out_file="$5"

  if [[ "$live" -eq 1 ]]; then
    if [[ "$verbose" -eq 1 ]]; then
      "$SCRIPT_DIR/dispatcher.sh" scout "$SCRIPT_DIR/scout.sh" --live "$limit" || true
    else
      "$SCRIPT_DIR/dispatcher.sh" scout "$SCRIPT_DIR/scout.sh" --live "$limit" >/dev/null 2>&1 || true
    fi
    "$SCRIPT_DIR/dispatcher.sh" \
      --validate-output "$SM_ROOT/contracts/scout.output.schema.json" \
      scout "$SCRIPT_DIR/scout.sh" --summary --json >/dev/null 2>&1 || true
  else
    "$SCRIPT_DIR/dispatcher.sh" \
      --validate-output "$SM_ROOT/contracts/scout.output.schema.json" \
      scout "$SCRIPT_DIR/scout.sh" --dry-run --json >/dev/null 2>&1 || true
    if [[ "$verbose" -eq 1 ]]; then
      "$SCRIPT_DIR/dispatcher.sh" scout "$SCRIPT_DIR/scout.sh" --dry-run || true
    else
      "$SCRIPT_DIR/dispatcher.sh" scout "$SCRIPT_DIR/scout.sh" --dry-run >/dev/null 2>&1 || true
    fi
  fi

  python3 - "$run_id" "$out_file" <<'PY'
import json, sys
run_id, out_file = sys.argv[1:]
p = '/home/steges/agent/skills/skill-forge/.state/known-skills.json'
with open(p, 'r', encoding='utf-8') as f:
    d = json.load(f)
slugs = sorted(slug for slug, row in d.items() if row.get('status') == 'discovered')
result = {
    'kind': 'step_discover',
    'run_id': run_id,
    'slugs': slugs,
    'count': len(slugs),
}
with open(out_file, 'w', encoding='utf-8') as f:
    json.dump(result, f, indent=2)
PY
}

# ── Step 2: vet ───────────────────────────────────────────────────────────────
# Vets each discovered slug. Per-skill errors are captured and non-fatal.
# Args: discover_file vet_score run_id out_file
# Output: JSON → out_file
#   {"kind":"step_vet","run_id":"...","results":[...],"vetted_count":N,"blocked_count":N,"error_count":N}
step_vet() {
  local discover_file="$1" vet_score="$2" run_id="$3" out_file="$4"

  local tmp_results
  tmp_results="$(mktemp)"
  echo '[]' > "$tmp_results"

  local vetted_count=0 blocked_count=0 error_count=0

  while IFS= read -r slug; do
    [[ -z "$slug" ]] && continue

    local tiered effective_score tier vet_status

    # Compute tier-adjusted score (per-skill, non-fatal)
    if tiered="$(tier_adjusted_score_for_slug "$slug" "$vet_score" 2>&1)"; then
      effective_score="$(printf '%s\n' "$tiered" | sed -n '1p')"
      tier="$(printf '%s\n' "$tiered" | sed -n '2p')"
    else
      error_count=$((error_count + 1))
      python3 - "$slug" "$tmp_results" <<'PY'
import json, sys
slug, rf = sys.argv[1:]
with open(rf) as f: arr = json.load(f)
arr.append({'slug': slug, 'status': 'error', 'score': None, 'tier': None, 'error': 'tier_score_failed'})
with open(rf, 'w', encoding='utf-8') as f: json.dump(arr, f)
PY
      continue
    fi

    # Run vetting (non-fatal — per-skill errors captured)
    "$SCRIPT_DIR/dispatcher.sh" \
      --validate-output "$SM_ROOT/contracts/vetter.output.schema.json" \
      vetter "$SCRIPT_DIR/vet.sh" "$slug" "$effective_score" --json >/dev/null 2>&1 || true

    # Read resulting status from state
    vet_status="$(python3 - "$slug" <<'PY'
import json, sys
slug = sys.argv[1]
p = '/home/steges/agent/skills/skill-forge/.state/known-skills.json'
with open(p, 'r', encoding='utf-8') as f:
    d = json.load(f)
print(d.get(slug, {}).get('status', 'unknown'))
PY
)"

    if [[ "$vet_status" == "vetted" ]]; then
      vetted_count=$((vetted_count + 1))
      log_audit "ORCHESTRATE" "$slug" "vetted tier=$tier score=$effective_score"
    else
      blocked_count=$((blocked_count + 1))
      log_audit "ORCHESTRATE" "$slug" "vetted-blocked status=$vet_status tier=$tier score=$effective_score"
    fi

    python3 - "$slug" "$vet_status" "$effective_score" "$tier" "$tmp_results" <<'PY'
import json, sys
slug, status, score_s, tier, rf = sys.argv[1:]
score = int(score_s) if score_s.isdigit() else None
with open(rf) as f: arr = json.load(f)
arr.append({'slug': slug, 'status': status, 'score': score, 'tier': tier, 'error': None})
with open(rf, 'w', encoding='utf-8') as f: json.dump(arr, f)
PY
  done < <(python3 - "$discover_file" <<'PY'
import json, sys
with open(sys.argv[1]) as f: d = json.load(f)
for slug in d.get('slugs', []):
    print(slug)
PY
)

  python3 - "$run_id" "$vetted_count" "$blocked_count" "$error_count" "$tmp_results" "$out_file" <<'PY'
import json, sys
run_id, vetted, blocked, errors, rf, out = sys.argv[1:]
with open(rf) as f: results = json.load(f)
result = {
    'kind': 'step_vet',
    'run_id': run_id,
    'results': results,
    'vetted_count': int(vetted),
    'blocked_count': int(blocked),
    'error_count': int(errors),
}
with open(out, 'w', encoding='utf-8') as f: json.dump(result, f, indent=2)
PY
  rm -f "$tmp_results"
}

# ── Step 3: canary ────────────────────────────────────────────────────────────
# For each vetted skill, checks conflicts and starts a canary run.
# Conflict-detected skills also enter canary (tracked but flagged).
# Per-skill errors are captured and non-fatal.
# Args: vet_file run_id out_file
# Output: JSON → out_file
#   {"kind":"step_canary","run_id":"...","results":[...],"started_count":N,"conflict_count":N,"error_count":N}
step_canary() {
  local vet_file="$1" run_id="$2" out_file="$3"

  local tmp_results
  tmp_results="$(mktemp)"
  echo '[]' > "$tmp_results"

  local started_count=0 conflict_count=0 error_count=0

  while IFS= read -r slug; do
    [[ -z "$slug" ]] && continue

    local action
    if "$SCRIPT_DIR/conflict-check.sh" "$slug" >/dev/null 2>&1; then
      # No conflict: start canary
      if "$SCRIPT_DIR/canary.sh" start "$slug" 24 >/dev/null 2>&1; then
        action="started"
        started_count=$((started_count + 1))
        log_audit "ORCHESTRATE" "$slug" "canary-start"
      else
        action="error"
        error_count=$((error_count + 1))
        log_audit "ORCHESTRATE" "$slug" "canary-start-failed"
      fi
    else
      # Conflict detected: still enter canary for tracking, mark as conflict
      action="conflict"
      conflict_count=$((conflict_count + 1))
      "$SCRIPT_DIR/canary.sh" start "$slug" 24 >/dev/null 2>&1 || true
      log_audit "ORCHESTRATE" "$slug" "conflict-detected"
    fi

    python3 - "$slug" "$action" "$tmp_results" <<'PY'
import json, sys
slug, action, rf = sys.argv[1:]
with open(rf) as f: arr = json.load(f)
arr.append({'slug': slug, 'action': action, 'error': None})
with open(rf, 'w', encoding='utf-8') as f: json.dump(arr, f)
PY
  done < <(python3 - "$vet_file" <<'PY'
import json, sys
with open(sys.argv[1]) as f: d = json.load(f)
for r in d.get('results', []):
    if r.get('status') == 'vetted':
        print(r['slug'])
PY
)

  python3 - "$run_id" "$started_count" "$conflict_count" "$error_count" "$tmp_results" "$out_file" <<'PY'
import json, sys
run_id, started, conflicts, errors, rf, out = sys.argv[1:]
with open(rf) as f: results = json.load(f)
result = {
    'kind': 'step_canary',
    'run_id': run_id,
    'results': results,
    'started_count': int(started),
    'conflict_count': int(conflicts),
    'error_count': int(errors),
}
with open(out, 'w', encoding='utf-8') as f: json.dump(result, f, indent=2)
PY
  rm -f "$tmp_results"
}

# ── Step 4: promote ───────────────────────────────────────────────────────────
# Attempts to promote each canary-started skill to active.
# Fresh canaries will fail with EXIT_POLICY=4 (too young) — this is expected
# and not counted as an error. Skill stays in canary until next orchestrate run
# after the minimum canary window has elapsed.
# Args: canary_file run_id out_file
# Output: JSON → out_file
#   {"kind":"step_promote","run_id":"...","results":[...],"promoted_count":N,"skipped_count":N,"error_count":N}
step_promote() {
  local canary_file="$1" run_id="$2" out_file="$3"

  local tmp_results
  tmp_results="$(mktemp)"
  echo '[]' > "$tmp_results"

  local promoted_count=0 skipped_count=0 error_count=0

  while IFS= read -r slug; do
    [[ -z "$slug" ]] && continue

    local action exit_code
    set +e
    "$SCRIPT_DIR/canary.sh" promote "$slug" >/dev/null 2>&1
    exit_code=$?
    set -e

    case "$exit_code" in
      0)
        action="promoted"
        promoted_count=$((promoted_count + 1))
        log_audit "ORCHESTRATE" "$slug" "promoted active"
        ;;
      4)
        # EXIT_POLICY: canary minimum age not reached — expected for fresh canaries
        action="too_young"
        skipped_count=$((skipped_count + 1))
        ;;
      5)
        # EXIT_FREEZE: incident freeze active, skip promote
        action="frozen"
        skipped_count=$((skipped_count + 1))
        ;;
      *)
        action="failed"
        error_count=$((error_count + 1))
        log_audit "ORCHESTRATE" "$slug" "promote-failed exit=$exit_code"
        ;;
    esac

    python3 - "$slug" "$action" "$tmp_results" <<'PY'
import json, sys
slug, action, rf = sys.argv[1:]
with open(rf) as f: arr = json.load(f)
arr.append({'slug': slug, 'action': action, 'error': None})
with open(rf, 'w', encoding='utf-8') as f: json.dump(arr, f)
PY
  done < <(python3 - "$canary_file" <<'PY'
import json, sys
with open(sys.argv[1]) as f: d = json.load(f)
for r in d.get('results', []):
    if r.get('action') == 'started':
        print(r['slug'])
PY
)

  python3 - "$run_id" "$promoted_count" "$skipped_count" "$error_count" "$tmp_results" "$out_file" <<'PY'
import json, sys
run_id, promoted, skipped, errors, rf, out = sys.argv[1:]
with open(rf) as f: results = json.load(f)
result = {
    'kind': 'step_promote',
    'run_id': run_id,
    'results': results,
    'promoted_count': int(promoted),
    'skipped_count': int(skipped),
    'error_count': int(errors),
}
with open(out, 'w', encoding='utf-8') as f: json.dump(result, f, indent=2)
PY
  rm -f "$tmp_results"
}

# ── Step 5: post_check ────────────────────────────────────────────────────────
# Maintenance checks: freeze auto-check, blacklist-promote, health, budget.
# Args: run_id verbose out_file
# Output: JSON → out_file
#   {"kind":"step_post_check","run_id":"...","health_ok":bool,"budget_ok":bool}
step_post_check() {
  local run_id="$1" verbose="$2" out_file="$3"

  "$SCRIPT_DIR/incident-freeze.sh" auto-check >/dev/null 2>&1 || true
  "$SCRIPT_DIR/blacklist-promote.sh" >/dev/null 2>&1 || true

  local health_ok=1 budget_ok=1
  if [[ "$verbose" -eq 1 ]]; then
    "$SCRIPT_DIR/health.sh" || health_ok=0
    "$SCRIPT_DIR/budget.sh" || budget_ok=0
  else
    "$SCRIPT_DIR/health.sh" >/dev/null 2>&1 || health_ok=0
    "$SCRIPT_DIR/budget.sh" >/dev/null 2>&1 || budget_ok=0
  fi

  python3 - "$run_id" "$health_ok" "$budget_ok" "$out_file" <<'PY'
import json, sys
run_id, health, budget, out = sys.argv[1:]
result = {
    'kind': 'step_post_check',
    'run_id': run_id,
    'health_ok': health == '1',
    'budget_ok': budget == '1',
}
with open(out, 'w', encoding='utf-8') as f: json.dump(result, f, indent=2)
PY
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  ensure_dirs
  init_state_files
  acceptance_gates

  local live=0 limit=20 vet_score=70 json_output=0
  local start_ms
  start_ms="$(date +%s%3N)"
  local run_id
  run_id="orchestrate-$(date +%s)"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --live)
        live=1
        if [[ -n "${2:-}" && "${2:-}" =~ ^[0-9]+$ ]]; then
          limit="$2"; shift
        fi
        shift ;;
      --vet-score)
        vet_score="${2:-70}"; shift 2 ;;
      --json)
        json_output=1; shift ;;
      *)
        usage; exit 1 ;;
    esac
  done

  # Propagate run_id for audit log correlation across all subcommands
  export SKILL_MANAGER_RUN_ID="$run_id"

  # Incident freeze → read-only summary mode
  if [[ "$(is_incident_freeze_on)" == "1" ]]; then
    if [[ "$json_output" -eq 1 ]]; then
      python3 - "$vet_score" <<'PY'
import json, sys
from datetime import datetime, timezone
vet_score = int(sys.argv[1])
print(json.dumps({
    'kind': 'orchestrate_run',
    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'live': False,
    'vet_score': vet_score,
    'summary': {'promoted': 0, 'blocked': 0, 'conflicts': 0},
}, indent=2))
PY
    else
      echo "Incident freeze active: orchestrate runs read-only summary mode."
      "$SCRIPT_DIR/dispatcher.sh" scout "$SCRIPT_DIR/scout.sh" --dry-run || true
    fi
    exit 0
  fi

  local verbose=$(( 1 - json_output ))
  # tmp_dir must be global (not local): EXIT trap fires after main() returns,
  # at which point local variables are out of scope → set -u would error.
  tmp_dir="$(mktemp -d)"
  trap '[[ -n "${tmp_dir:-}" ]] && rm -rf "$tmp_dir"' EXIT

  # ── Steps (each writes JSON to a temp file) ───────────────────────────────
  step_discover   "$live" "$limit" "$run_id" "$verbose" "$tmp_dir/discover.json"
  step_vet        "$tmp_dir/discover.json" "$vet_score" "$run_id" "$tmp_dir/vet.json"
  step_canary     "$tmp_dir/vet.json" "$run_id" "$tmp_dir/canary.json"
  step_promote    "$tmp_dir/canary.json" "$run_id" "$tmp_dir/promote.json"
  step_post_check "$run_id" "$verbose" "$tmp_dir/post.json"

  # ── Metrics & audit ──────────────────────────────────────────────────────
  local end_ms duration_ms
  end_ms="$(date +%s%3N)"
  duration_ms=$((end_ms - start_ms))
  "$SCRIPT_DIR/metrics.sh" record "$run_id" "$live" "$vet_score" "$duration_ms" >/dev/null
  log_audit "ORCHESTRATE" "-" "complete live=$live limit=$limit vet_score=$vet_score"

  # ── JSON output ──────────────────────────────────────────────────────────
  if [[ "$json_output" -eq 1 ]]; then
    python3 - "$live" "$vet_score" \
      "$tmp_dir/vet.json" \
      "$tmp_dir/canary.json" \
      "$tmp_dir/promote.json" \
      "$tmp_dir/post.json" <<'PY'
import json, sys
from datetime import datetime, timezone
live = sys.argv[1] == '1'
vet_score = int(sys.argv[2])
vet_d     = json.load(open(sys.argv[3]))
canary_d  = json.load(open(sys.argv[4]))
promote_d = json.load(open(sys.argv[5]))
post_d    = json.load(open(sys.argv[6]))
print(json.dumps({
    'kind': 'orchestrate_run',
    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'live': live,
    'vet_score': vet_score,
    'summary': {
        'promoted':  promote_d.get('promoted_count', 0),
        'blocked':   vet_d.get('blocked_count', 0),
        'conflicts': canary_d.get('conflict_count', 0),
    },
    'steps': {
        'vet':        vet_d,
        'canary':     canary_d,
        'promote':    promote_d,
        'post_check': post_d,
    },
}, indent=2))
PY
  fi
}

main "$@"
