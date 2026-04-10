#!/bin/bash
set -euo pipefail

# vetting-dispatch.sh — vetting skill dispatcher
# Erweitert vet.sh um semantische Agent-Analyse (nur wenn --semantic gesetzt)
# Args: <slug> [--json]
# Erwartet: vetter-report existiert bereits (vet.sh hat vorher gelaufen)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SM_ROOT="/home/steges/agent/skills/skill-forge"
VETTING_ROOT="/home/steges/agent/skills/vetting"
ANALYST_TIMEOUT="${VETTING_ANALYST_TIMEOUT:-20}"
MAX_SKILL_MD_BYTES="${VETTING_MAX_SKILL_MD_BYTES:-200000}"

source "$SM_ROOT/scripts/common.sh"

usage() {
  echo "Usage: vetting-dispatch.sh <slug> [--json]"
}

read_vet_report() {
  local slug="$1"
  local report_path="$SM_ROOT/.state/vetter-reports/${slug}.json"
  [[ -f "$report_path" ]] || { echo "Kein vetter-report für: $slug" >&2; exit 1; }
  cat "$report_path"
}

read_skill_md() {
  local slug="$1"
  # Suche SKILL.md im skills-Verzeichnis
  local skill_md
  skill_md="$(find "$SM_ROOT/../" -maxdepth 3 -name "SKILL.md" -path "*/${slug}/*" 2>/dev/null | head -1)"
  if [[ -z "$skill_md" || ! -f "$skill_md" ]]; then
    echo "(SKILL.md nicht gefunden für slug=$slug)"
    return
  fi
  if [[ ! -r "$skill_md" ]]; then
    echo "(SKILL.md nicht lesbar für slug=$slug)"
    return
  fi
  local size
  size="$(wc -c < "$skill_md" 2>/dev/null || echo 0)"
  if [[ "$size" =~ ^[0-9]+$ ]] && (( size > MAX_SKILL_MD_BYTES )); then
    echo "(SKILL.md zu groß für Analyse: ${size} bytes > ${MAX_SKILL_MD_BYTES})"
    return
  fi
  cat "$skill_md"
}

run_with_timeout() {
  local timeout_s="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout --signal=TERM --kill-after=5 "$timeout_s" "$@"
  else
    "$@"
  fi
}

run_analyst() {
  local slug="$1"
  local vet_report="$2"
  local skill_content="$3"

  # Analyst-Scan: Semantische Analyse von SKILL.md (vetting-dispatch Layer)
  # Flags verwenden: [{id, severity (block|warn|info), reason}]
  # Klar getrennt von vet.sh's static_semantic_flags (Datei-Analyse)
  _run_analyst_py() {
  python3 - "$slug" "$vet_report" <<PY
import json, sys, re

slug = sys.argv[1]
report = json.loads(sys.argv[2])

skill_content = """${skill_content}"""
txt = skill_content.lower()

delta = 0
# flags: [{id, severity (block|warn|info), reason}]
flags = []
rationale_parts = []

# Prompt-Injection (block severity)
if 'ignore previous instructions' in txt or 'system prompt' in txt or 'new role' in txt:
    delta -= 20
    flags.append({'id': 'prompt-injection-like', 'severity': 'block', 'reason': 'Prompt-Injection-artige Formulierungen im SKILL.md gefunden.'})
    rationale_parts.append('Prompt-Injection-artige Formulierungen im SKILL.md gefunden.')

# Purpose-Mismatch (warn severity)
mentions_safe = any(k in txt for k in ('audit', 'lint', 'review', 'validate', 'check', 'monitor'))
mentions_danger = any(k in txt for k in ('delete /', 'rm -rf', 'prune', 'curl http', 'wget http'))
if mentions_safe and mentions_danger:
    delta -= 10
    flags.append({'id': 'purpose-mismatch', 'severity': 'warn', 'reason': 'Skill beschreibt sich als Safety-Tool, enthält aber destruktive Operationen.'})
    rationale_parts.append('Skill beschreibt sich als Safety-Tool, enthält aber potentiell destruktive Operationen.')

# Broad permissions (warn severity)
if ('permissions:' in txt or 'requires:' in txt) and any(k in txt for k in ('all', 'admin', 'root')):
    delta -= 10
    flags.append({'id': 'broad-permissions', 'severity': 'warn', 'reason': 'Skill beansprucht breite Rechte ohne spezifische Begründung.'})
    rationale_parts.append('Skill beansprucht breite Rechte ohne spezifische Begründung.')

# Cross-file-mismatch (info severity)
if 'scripts/' in txt and ('no scripts' in txt or 'without scripts' in txt):
    delta -= 5
    flags.append({'id': 'cross-file-mismatch', 'severity': 'info', 'reason': 'Widerspruch zwischen Script-Referenzen und Script-Ausschluss.'})
    rationale_parts.append('Widerspruch zwischen Script-Referenzen und Script-Ausschluss.')

# Positiv: explizit safety-focused (info)
if all(k in txt for k in ('scope-grenzen', 'verboten', 'kein state-write')):
    delta += 5
    rationale_parts.append('Skill ist explizit safety-focused mit klaren Scope-Grenzen.')
elif all(k in txt for k in ('audit', 'policy', 'zero trust')):
    delta += 3
    rationale_parts.append('Skill referenziert Audit und Policy-Compliance.')

delta = max(-20, min(10, delta))
rationale = ' '.join(rationale_parts) if rationale_parts else 'Keine auffälligen semantischen Muster gefunden.'

result = {
    'slug': slug,
    'semantic_delta': delta,
    'flags': flags,
    'rationale': rationale
}
print(json.dumps(result))
PY
  }

  if command -v timeout >/dev/null 2>&1; then
    timeout --signal=TERM --kill-after=5 "$ANALYST_TIMEOUT" bash -c "$(declare -f _run_analyst_py); _run_analyst_py" || _run_analyst_py
  else
    _run_analyst_py
  fi
}

run_reviewer() {
  local slug="$1"
  local vet_report="$2"
  local analyst_output="$3"

  python3 - "$slug" "$vet_report" "$analyst_output" <<'PY'
import json, sys

slug = sys.argv[1]
report = json.loads(sys.argv[2])
analyst = json.loads(sys.argv[3])

tier = report.get('risk_tier', 'MEDIUM')
vet_verdict = report.get('verdict', 'PASS')
delta = analyst.get('semantic_delta', 0)
flags = analyst.get('flags', [])

# EXTREME ist nicht überbrückbar
if tier == 'EXTREME':
    verdict = 'REJECT'
    rationale = f'EXTREME-Tier aus vet.sh ist absolut. Semantischer Delta ({delta}) ändert das Ergebnis nicht.'
elif delta <= -20:
    verdict = 'REJECT'
    rationale = f'Semantischer Delta {delta} (Flags: {", ".join(flags)}) überschreitet Reject-Schwelle.'
elif tier == 'HIGH' or (vet_verdict == 'PASS' and delta <= -10):
    verdict = 'REVIEW'
    flag_str = ', '.join(flags) if flags else 'keine'
    rationale = f'vet.sh-Tier {tier}, Analyst-Delta {delta} (Flags: {flag_str}). Manuelle Prüfung empfohlen.'
else:
    verdict = 'PASS'
    flag_str = ', '.join(flags) if flags else 'keine'
    rationale = f'vet.sh-Verdict {vet_verdict}, Analyst-Delta {delta} (Flags: {flag_str}). Keine kritischen semantischen Auffälligkeiten.'

result = {
    'reviewer_verdict': verdict,
    'reviewer_rationale': rationale
}
print(json.dumps(result))
PY
}

update_report_with_semantic() {
  local slug="$1"
  local analyst_output="$2"
  local reviewer_output="$3"

  python3 - "$slug" "$analyst_output" "$reviewer_output" <<'PY'
import json, sys

slug = sys.argv[1]
analyst = json.loads(sys.argv[2])
reviewer = json.loads(sys.argv[3])

report_path = f'/home/steges/agent/skills/skill-forge/.state/vetter-reports/{slug}.json'
with open(report_path, 'r', encoding='utf-8') as f:
    report = json.load(f)

report['semantic_review'] = {
    'schema_version': '2',
    'source': 'vetting-dispatch',
    # analyst_flags: [{id, severity (block|warn|info), reason}]
    'analyst_delta': analyst.get('semantic_delta', 0),
    'analyst_flags': analyst.get('flags', []),
    'analyst_rationale': analyst.get('rationale', ''),
    'reviewer_verdict': reviewer.get('reviewer_verdict', 'PASS'),
    'reviewer_rationale': reviewer.get('reviewer_rationale', '')
}

with open(report_path, 'w', encoding='utf-8') as f:
    json.dump(report, f, indent=2)

print(json.dumps(report, indent=2))
PY
}

main() {
  ensure_dirs
  init_state_files

  [[ $# -ge 1 ]] || { usage; exit 1; }
  local slug="$1"
  local json_output=0
  [[ "${2:-}" == "--json" ]] && json_output=1

  local vet_report
  vet_report="$(read_vet_report "$slug")"

  local skill_content
  skill_content="$(read_skill_md "$slug")"

  local analyst_output
  set +e
  analyst_output="$(run_analyst "$slug" "$vet_report" "$skill_content" 2>/dev/null)"
  analyst_rc=$?
  set -e
  if [[ $analyst_rc -ne 0 || -z "$analyst_output" ]]; then
    analyst_output='{"slug":"'"$slug"'","semantic_delta":0,"flags":["analyst-fallback"],"rationale":"Analyst fehlgeschlagen oder Timeout; fallback auf vet.sh report."}'
  fi

  local reviewer_output
  reviewer_output="$(run_reviewer "$slug" "$vet_report" "$analyst_output")"

  local final_report
  final_report="$(update_report_with_semantic "$slug" "$analyst_output" "$reviewer_output")"

  log_audit "VETTING-SEMANTIC" "$slug" "analyst_delta=$(echo "$analyst_output" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["semantic_delta"])')"

  if [[ "$json_output" -eq 1 ]]; then
    echo "$final_report"
  else
    local reviewer_verdict
    reviewer_verdict="$(echo "$reviewer_output" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["reviewer_verdict"])')"
    echo "Semantic vetting: $reviewer_verdict for $slug"
    echo "$final_report" | python3 -c 'import json,sys; d=json.load(sys.stdin); sr=d.get("semantic_review",{}); print(f"  delta={sr.get(\"analyst_delta\",0)} flags={sr.get(\"analyst_flags\",[])}")'
  fi
}

main "$@"
