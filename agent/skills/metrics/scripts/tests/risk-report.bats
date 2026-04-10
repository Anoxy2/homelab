#!/usr/bin/env bats
# Tests für metrics-dispatch.sh risk-report Subkommando

DISPATCH="/home/steges/agent/skills/metrics/scripts/metrics-dispatch.sh"

setup() {
  TMPDIR="$(mktemp -d)"
  export METRICS_STATE_DIR="$TMPDIR"
  mkdir -p "$TMPDIR/vetter-reports"

  # known-skills.json: zwei Skills mit unterschiedlichem Status
  cat > "$TMPDIR/known-skills.json" <<'EOF'
{
  "alpha": { "status": "active",         "vetting_score": 80, "quality_tier": "A" },
  "beta":  { "status": "pending-review", "vetting_score": 50, "quality_tier": "B" }
}
EOF

  # audit-log.jsonl: beta hat einen REJECT
  cat > "$TMPDIR/audit-log.jsonl" <<'EOF'
{"ts":"2026-04-01T10:00:00Z","actor":"system","command":"REJECT","target":"beta","result":"ok","reason":"test","run_id":"r1","message":"rejected"}
{"ts":"2026-04-01T10:01:00Z","actor":"system","command":"PASS","target":"alpha","result":"ok","reason":"test","run_id":"r2","message":"passed"}
EOF

  # vetter report für beta mit HIGH risk
  cat > "$TMPDIR/vetter-reports/beta.json" <<'EOF'
{"slug":"beta","verdict":"REJECT","risk_tier":"HIGH","scores":{"final_score":42},"timestamp":"2026-04-01T10:00:00Z"}
EOF
  # vetter report für alpha mit LOW risk
  cat > "$TMPDIR/vetter-reports/alpha.json" <<'EOF'
{"slug":"alpha","verdict":"PASS","risk_tier":"LOW","scores":{"final_score":85},"timestamp":"2026-04-01T09:00:00Z"}
EOF

  # Leere metrics/state-Dateien anlegen (braucht ensure_dirs/init_state_files)
  touch "$TMPDIR/metrics.jsonl"
  touch "$TMPDIR/metrics-weekly.json"
  echo '{}' > "$TMPDIR/canary.json"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "risk-report: Ausgabe enthält beide Skills" {
  run "$DISPATCH" risk-report
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'alpha' in d['skills']; assert 'beta' in d['skills']"
}

@test "risk-report: beta hat höheren risk_score als alpha" {
  run "$DISPATCH" risk-report
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
alpha_score = d['skills']['alpha']['risk_score']
beta_score  = d['skills']['beta']['risk_score']
assert beta_score > alpha_score, f'beta={beta_score} sollte > alpha={alpha_score} sein'
"
}

@test "risk-report: skill-risk-report.json wird geschrieben" {
  run "$DISPATCH" risk-report
  [[ "$status" -eq 0 ]]
  [[ -f "$TMPDIR/skill-risk-report.json" ]]
  python3 -c "import json; d=json.load(open('$TMPDIR/skill-risk-report.json')); assert 'alpha' in d['skills']"
}
