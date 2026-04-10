#!/bin/bash

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SM_STATE="/home/steges/agent/skills/skill-forge/.state"
SM_POLICY="/home/steges/agent/skills/skill-forge/policy/rollout-policy.yaml"
CANARY_CRITERIA="/home/steges/agent/skills/skill-forge/policy/canary-criteria.yaml"
AUDIT_LOG="$SM_STATE/audit-log.jsonl"
CANARY_JSON="$SM_STATE/canary.json"
FREEZE_JSON="$SM_STATE/incident-freeze.json"

usage() {
  echo "Usage: canary-dispatch.sh evaluate <slug> [--json]"
}

evaluate_cmd() {
  local slug="$1"
  local json_mode="${2:-}"

    python3 - "$slug" "$CANARY_JSON" "$AUDIT_LOG" "$SM_POLICY" "$CANARY_CRITERIA" "$FREEZE_JSON" "$json_mode" <<'PY'
import json, sys, re
from datetime import datetime, timezone

slug        = sys.argv[1]
canary_path = sys.argv[2]
audit_path  = sys.argv[3]
policy_path = sys.argv[4]
criteria_path = sys.argv[5]
freeze_path = sys.argv[6]
json_mode   = sys.argv[7] == "--json"

# ── Load state ────────────────────────────────────────────────────────────────
try:
    with open(canary_path, 'r', encoding='utf-8') as f:
        canary = json.load(f)
except Exception:
    canary = {}

if slug not in canary:
    result = {"error": f"No canary entry for '{slug}'"}
    print(json.dumps(result, indent=2))
    sys.exit(1)

entry = canary[slug]

freeze_enabled = False
try:
    with open(freeze_path, 'r', encoding='utf-8') as f:
        freeze = json.load(f)
    freeze_enabled = bool(freeze.get('enabled', False))
except Exception:
    freeze_enabled = False

# ── Load policy ───────────────────────────────────────────────────────────────
max_triggers = 5
require_no_high = True
require_no_conflict = True
window_hours = 24
hard_min_hours = 24
decision_table = []
try:
    import yaml
    with open(policy_path, 'r', encoding='utf-8') as f:
        policy = yaml.safe_load(f)
    ptc = policy.get('promote_canary_to_active', {})
    canary_cfg = policy.get('canary', {})
    if 'max_triggers_per_day' in policy.get('canary', {}):
        max_triggers = int(policy['canary']['max_triggers_per_day'])
    if 'window_hours' in canary_cfg:
        window_hours = int(canary_cfg['window_hours'])
    if 'hard_min_hours' in canary_cfg:
        hard_min_hours = int(canary_cfg['hard_min_hours'])
    require_no_high    = ptc.get('require_no_high_or_extreme_events', True)
    require_no_conflict = ptc.get('require_no_trigger_conflict', True)
    decision_table = policy.get('decision_table', [])
except Exception:
    try:
        with open(policy_path, 'r', encoding='utf-8') as f:
            raw = f.read()
        m = re.search(r'max_triggers_per_day:\s*(\d+)', raw)
        if m:
            max_triggers = int(m.group(1))
        if 'require_no_high_or_extreme_events: false' in raw:
            require_no_high = False
        if 'require_no_trigger_conflict: false' in raw:
            require_no_conflict = False
    except Exception:
        pass  # fall back to defaults

# ── Load skill-specific canary criteria (versioned) ───────────────────────────
try:
    import yaml
    with open(criteria_path, 'r', encoding='utf-8') as f:
        criteria = yaml.safe_load(f) or {}

    default_cfg = criteria.get('default', {}) or {}
    skill_cfg = (criteria.get('skills', {}) or {}).get(slug, {}) or {}

    merged = dict(default_cfg)
    merged.update(skill_cfg)

    if 'max_triggers_per_day' in merged:
        max_triggers = int(merged['max_triggers_per_day'])
    if 'require_no_high_or_extreme_events' in merged:
        require_no_high = bool(merged['require_no_high_or_extreme_events'])
    if 'require_no_trigger_conflict' in merged:
        require_no_conflict = bool(merged['require_no_trigger_conflict'])
    if 'window_hours' in merged:
        window_hours = int(merged['window_hours'])
    if 'hard_min_hours' in merged:
        hard_min_hours = int(merged['hard_min_hours'])
except Exception:
    pass

# ── Parse canary window ───────────────────────────────────────────────────────
now = datetime.now(timezone.utc)
started_at = entry.get('started_at', '')
until_str  = entry.get('until', '')
status     = entry.get('status', 'unknown')
evidence   = []

try:
    start = datetime.strptime(started_at, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
    end   = datetime.strptime(until_str,  '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
    total_secs   = (end - start).total_seconds()
    elapsed_secs = (now - start).total_seconds()
    elapsed_h    = elapsed_secs / 3600
    total_h      = total_secs / 3600
    pct_done     = (elapsed_secs / total_secs * 100) if total_secs > 0 else 0
    evidence.append(f"Canary läuft seit {elapsed_h:.1f}h von {total_h:.1f}h ({pct_done:.0f}%)")
    window_expired = now > end
    window_young   = pct_done < 25
except Exception:
    elapsed_h = 0
    total_h   = 0
    pct_done = 0
    window_expired = False
    window_young = True
    evidence.append("Canary-Zeitfenster konnte nicht geparst werden")

# ── Scan audit log ────────────────────────────────────────────────────────────
trigger_count  = 0
high_events    = 0
conflict_count = 0

try:
    with open(audit_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            if rec.get('slug') != slug and rec.get('target') != slug:
                continue
            action = str(rec.get('command', rec.get('action', ''))).upper()
            msg = str(rec.get('message', '')).lower()
            if action in ('TRIGGER', 'ERROR', 'FAIL') or 'failed' in msg:
                trigger_count += 1
            if action in ('EXTREME', 'HIGH') or ' tier=high' in msg or ' tier=extreme' in msg:
                high_events += 1
            if action == 'CONFLICT' or 'conflict' in msg:
                conflict_count += 1
except FileNotFoundError:
    evidence.append("Audit-Log nicht gefunden — keine Event-Daten")
except Exception:
    evidence.append("Audit-Log ist leer/korrupt — Fallback ohne Event-Daten")

if trigger_count > 0:
    evidence.append(f"{trigger_count} TRIGGER/ERROR-Events im Audit-Log")
if high_events > 0:
    evidence.append(f"{high_events} EXTREME/HIGH-Events im Audit-Log")
if conflict_count > 0:
    evidence.append(f"{conflict_count} CONFLICT-Events im Audit-Log")

# ── Evaluate decision table ───────────────────────────────────────────────────
# Conditions evaluated top-to-bottom; first match wins.
def _eval_table(table):
    ctx = {
        'freeze_enabled':       freeze_enabled,
        'status_not_running':   status != 'running',
        'high_events_gt_0':     require_no_high and high_events > 0,
        'conflict_count_gt_0':  require_no_conflict and conflict_count > 0,
        'trigger_gte_max':      trigger_count >= max_triggers,
        'window_young':         window_young,
        'window_expired':       window_expired,
    }
    cond_map = {
        'freeze_enabled':                                     ctx['freeze_enabled'],
        'status != running':                                  ctx['status_not_running'],
        'require_no_high_or_extreme_events AND high_events > 0': ctx['high_events_gt_0'],
        'require_no_trigger_conflict AND conflict_count > 0': ctx['conflict_count_gt_0'],
        'trigger_count >= max_triggers_per_day':              ctx['trigger_gte_max'],
        'window_pct < 25':                                    ctx['window_young'],
        'window_expired':                                     ctx['window_expired'],
        'default':                                            True,
    }
    for row in table:
        cond_key = row.get('condition', '')
        if cond_map.get(cond_key, False):
            return row
    return None

matched_row = _eval_table(decision_table) if decision_table else None

if matched_row:
    recommendation = matched_row.get('recommendation', 'extend')
    confidence     = int(matched_row.get('confidence', 70))
    failure_class  = matched_row.get('failure_class', 'none')
    matched_row_id = matched_row.get('id', 'unknown')
else:
    # Fallback: hardcoded logic when no decision_table available
    recommendation = "promote"
    confidence      = 85
    failure_class   = "none"
    matched_row_id  = "fallback"

    if status != 'running':
        recommendation = "extend"
        confidence     = 40
        failure_class  = "none"
        evidence.append(f"Canary-Status ist '{status}', nicht 'running'")
    elif require_no_high and high_events > 0:
        recommendation = "fail"
        confidence     = 95
        failure_class  = "signal_fail"
    elif require_no_conflict and conflict_count > 0:
        recommendation = "fail"
        confidence     = 90
        failure_class  = "conflict_fail"
    elif trigger_count >= max_triggers:
        recommendation = "fail"
        confidence     = 88
        failure_class  = "policy_fail"
        evidence.append(f"Trigger-Events ({trigger_count}) >= max_triggers_per_day ({max_triggers})")
    elif window_young:
        recommendation = "extend"
        confidence     = 70
        failure_class  = "none"
        evidence.append("Canary-Fenster noch zu jung (< 25% verstrichen)")
    elif window_expired:
        recommendation = "promote"
        confidence     = 90
        failure_class  = "none"
        evidence.append("Canary-Fenster vollständig abgelaufen — keine Alarme")
    else:
        evidence.append("Keine Alarm-Events, Fenster läuft planmäßig")

    if freeze_enabled:
        recommendation = "fail"
        failure_class  = "freeze_fail"
        confidence     = 100
        evidence.append("Incident freeze aktiv")

# ── Approver verdict ──────────────────────────────────────────────────────────
if recommendation == "fail":
    verdict = "No-Go"
elif recommendation == "promote" and confidence >= 70:
    verdict = "Go"
elif recommendation == "extend":
    verdict = "Extend"
else:
    verdict = "Extend"

if freeze_enabled and verdict != "No-Go":
    verdict       = "No-Go"
    failure_class = "freeze_fail"
    evidence.append("Incident freeze aktiv")

evidence_summary = "; ".join(evidence[:3])
rationale_map = {
    "Go":    f"Canary-Evaluator empfiehlt Promote (confidence={confidence}). {evidence_summary}",
    "No-Go": f"Blocking-Event erkannt ({failure_class}). {evidence_summary}",
    "Extend": f"Noch nicht reif für Promote. {evidence_summary}",
}

approver_out = {
    "slug":                      slug,
    "verdict":                   verdict,
    "rationale":                 rationale_map[verdict],
    "evaluator_recommendation":  recommendation,
    "confidence":                confidence,
    "freeze_enabled":            freeze_enabled,
    "failure_class":             failure_class,
    "decision_table_row":        matched_row_id,
    "trigger_count":             trigger_count,
    "high_events":               high_events,
    "conflict_count":            conflict_count,
    "window_pct_done":           round(pct_done, 1),
    "elapsed_hours":             round(elapsed_h, 2),
    "total_hours":               round(total_h, 2),
    "criteria": {
        "window_hours": window_hours,
        "hard_min_hours": hard_min_hours,
        "max_triggers_per_day": max_triggers,
        "require_no_high_or_extreme_events": require_no_high,
        "require_no_trigger_conflict": require_no_conflict,
    },
}

if json_mode:
    print(json.dumps(approver_out, indent=2, ensure_ascii=False))
else:
    print(f"Canary Evaluation: {slug}")
    print(f"  Verdict:        {verdict}")
    print(f"  Recommendation: {recommendation} (confidence={confidence})")
    print(f"  Failure-Class:  {failure_class}")
    print(f"  Decision-Row:   {matched_row_id}")
    print(f"  Window:         {elapsed_h:.1f}h / {total_h:.1f}h ({pct_done:.0f}%)")
    print(f"  Events:         triggers={trigger_count} high={high_events} conflicts={conflict_count}")
    print(f"  Rationale:      {approver_out['rationale']}")
    print("  Evidence:")
    for e in evidence:
        print(f"    - {e}")
PY
}

main() {
  local sub="${1:-}"
  case "$sub" in
    evaluate)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      local slug="$2"
      local json_flag="${3:-}"
      evaluate_cmd "$slug" "$json_flag"
      ;;
    *)
      usage; exit 1 ;;
  esac
}

main "$@"
