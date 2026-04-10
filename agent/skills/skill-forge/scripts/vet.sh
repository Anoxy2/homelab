#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

add_pending_blacklist() {
  local slug="$1"
  local reason="$2"
  python3 - "$slug" "$reason" <<'PY'
import json, sys
sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import write_json_atomic, utc_now_iso
slug, reason = sys.argv[1], sys.argv[2]
p = '/home/steges/agent/skills/skill-forge/.state/pending-blacklist.json'
with open(p, 'r', encoding='utf-8') as f:
    rows = json.load(f)
rows.append({'slug': slug, 'reason': reason, 'added_at': utc_now_iso()})
write_json_atomic(p, rows)
PY
}

update_status() {
  local slug="$1"
  local status="$2"
  local score="$3"

  local allowed
  case "$status" in
    vetted)
      allowed="unknown,discovered,pending-review,vetted,active,reviewed,canary"
      ;;
    pending-review)
      allowed="unknown,discovered,pending-review,vetted,active,reviewed,canary"
      ;;
    pending-blacklist)
      allowed="unknown,discovered,pending-review,vetted,active,reviewed,canary,pending-blacklist"
      ;;
    *)
      echo "Unsupported status in vet.sh: $status" >&2
      return "$EXIT_USAGE"
      ;;
  esac

  if ! validate_known_skill_transition "$slug" "$status" "$allowed" >/dev/null; then
    echo "Blocked invalid state transition for $slug -> $status" >&2
    return "$EXIT_POLICY"
  fi

  python3 - "$slug" "$status" "$score" <<'PY'
import json
import sys

sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import utc_now_iso, write_json_atomic

slug, status, score = sys.argv[1], sys.argv[2], int(sys.argv[3])
p = '/home/steges/agent/skills/skill-forge/.state/known-skills.json'

with open(p, 'r', encoding='utf-8') as f:
    data = json.load(f)
row = data.get(slug, {'slug': slug, 'source': 'manual', 'version': '0.0.0'})
row['status'] = status
row['vetting_score'] = score
row['vetted_at'] = utc_now_iso()
data[slug] = row
write_json_atomic(p, data)
PY
}

write_report() {
  local slug="$1"
  local score="$2"
  local verdict="$3"
  local tier="$4"
  local input_score="$5"
  local static_score="$6"
  local semantic_score="$7"
  local reputation_score="$8"
  local sem_flags_json="${9:-[]}"
  python3 - "$slug" "$score" "$verdict" "$tier" "$input_score" "$static_score" "$semantic_score" "$reputation_score" "$sem_flags_json" <<'PY'
import json, sys
from datetime import datetime, timezone
slug, score, verdict, tier = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
input_score, static_score, semantic_score, reputation_score = map(int, sys.argv[5:9])
sem_flags_raw = sys.argv[9]
try:
    sem_flags = json.loads(sem_flags_raw)
except Exception:
    sem_flags = []
out = f'/home/steges/agent/skills/skill-forge/.state/vetter-reports/{slug}.json'
report = {
    'schema_version': '2',
    'slug': slug,
    'verdict': verdict,
    'risk_tier': tier,
    'scores': {
        'input_score': input_score,
        'static_score': static_score,
        # static_semantic: deterministic pattern scan on script file (vet.sh layer)
        'static_semantic_score': semantic_score,
        'reputation_score': reputation_score,
        'final_score': score,
    },
    # static_semantic_flags: [{id, severity, reason}] from vet.sh's static file analysis
    'static_semantic_flags': sem_flags,
    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
}
with open(out, 'w', encoding='utf-8') as f:
    json.dump(report, f, indent=2)
PY
}

score_to_tier() {
  local score="$1"
  if (( score >= 85 )); then echo "LOW"; return; fi
  if (( score >= 65 )); then echo "MEDIUM"; return; fi
  if (( score >= 35 )); then echo "HIGH"; return; fi
  echo "EXTREME"
}

deep_scan_score_penalty() {
  local scan_path="$1"
  [[ -n "$scan_path" ]] || { echo "0|"; return; }
  [[ -e "$scan_path" ]] || { echo "0|"; return; }

  local flags=()
  local penalty=0

  if rg -n "eval\(" "$scan_path" >/dev/null 2>&1; then
    flags+=("eval")
    penalty=$((penalty + 60))
  fi
  if rg -n "exec\(" "$scan_path" >/dev/null 2>&1; then
    flags+=("exec")
    penalty=$((penalty + 50))
  fi
  if rg -n "sudo -S -p ''" "$scan_path" >/dev/null 2>&1; then
    flags+=("sudo-noninteractive")
    penalty=$((penalty + 40))
  fi
  if rg -n "curl|wget" "$scan_path" >/dev/null 2>&1; then
    flags+=("network-fetch")
    penalty=$((penalty + 20))
  fi
  if rg -n "[A-Za-z0-9+/]{50,}={0,2}" "$scan_path" >/dev/null 2>&1; then
    flags+=("long-base64-like")
    penalty=$((penalty + 20))
  fi

  local joined=""
  if (( ${#flags[@]} > 0 )); then
    joined="$(IFS=,; echo "${flags[*]}")"
  fi
  echo "$penalty|$joined"
}

semantic_score_delta() {
  local scan_path="$1"
  [[ -n "$scan_path" ]] || { echo "0|[]"; return; }
  [[ -e "$scan_path" ]] || { echo "0|[]"; return; }

  python3 - "$scan_path" <<'PY'
import re, sys, json
path = sys.argv[1]
with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    txt = f.read().lower()

delta = 0
# flags: [{id, severity (block|warn|info), reason}]
flags = []

mentions_safe = any(k in txt for k in ('audit', 'lint', 'review', 'validate', 'check'))
mentions_danger = any(k in txt for k in ('delete /', 'rm -rf', 'sudo -s', 'curl http', 'wget http'))

if mentions_safe and mentions_danger:
    delta -= 30
    flags.append({'id': 'purpose-mismatch', 'severity': 'block', 'reason': 'Safety-Formulierungen kombiniert mit destruktiven Ops'})

if 'ignore previous instructions' in txt or 'system prompt' in txt:
    delta -= 25
    flags.append({'id': 'prompt-injection-like', 'severity': 'block', 'reason': 'Prompt-Injection-artige Formulierungen gefunden'})

if ('permissions:' in txt or 'requires:' in txt) and any(k in txt for k in ('all', 'admin', 'root')):
    delta -= 20
    flags.append({'id': 'broad-permissions', 'severity': 'warn', 'reason': 'Sehr breite Rechteanforderungen ohne spezifische Begründung'})

if 'scripts/' in txt and ('no scripts' in txt or 'without scripts' in txt):
    delta -= 10
    flags.append({'id': 'cross-file-mismatch', 'severity': 'warn', 'reason': 'Widersprüchliche Script-Referenzen im Skill'})

delta = max(-80, min(20, delta))
print(f"{delta}|{json.dumps(flags)}")
PY
}

emit_json_result() {
  local slug="$1"
  python3 - "$slug" <<'PY'
import json, sys
slug = sys.argv[1]
p = f'/home/steges/agent/skills/skill-forge/.state/vetter-reports/{slug}.json'
with open(p, 'r', encoding='utf-8') as f:
    print(json.dumps(json.load(f), indent=2))
PY
}

main() {
  ensure_dirs
  init_state_files

  [[ $# -ge 2 ]] || { echo "Usage: vet.sh <slug> <score>"; exit 1; }
  local slug="$1"
  local score="$2"
  local input_score="$2"
  local scan_path=""
  local json_output=0
  local semantic_mode=0

  local args=("${@:3}")
  local i=0
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --file)
        i=$((i + 1))
        scan_path="${args[$i]:-}"
        [[ -n "$scan_path" ]] || { echo "Usage: vet.sh <slug> <score> [--file <path>] [--semantic] [--json]"; exit 1; }
        ;;
      --semantic)
        semantic_mode=1
        ;;
      --json)
        json_output=1
        ;;
    esac
    i=$((i + 1))
  done

  [[ "$score" =~ ^[0-9]+$ ]] || { echo "Score must be integer 0..100"; exit 1; }
  (( score >= 0 && score <= 100 )) || { echo "Score out of range"; exit 1; }

  local deep
  deep="$(deep_scan_score_penalty "$scan_path")"
  local penalty flags
  penalty="${deep%%|*}"
  flags="${deep#*|}"

  local semantic
  semantic="$(semantic_score_delta "$scan_path")"
  local sem_delta sem_flags_json
  sem_delta="${semantic%%|*}"
  sem_flags_json="${semantic#*|}"
  # Legacy: für Audit-Log kompakte Darstellung der Flag-IDs
  local sem_flags_str
  sem_flags_str="$(echo "$sem_flags_json" | python3 -c "import json,sys; data=json.load(sys.stdin); print(','.join(f['id'] for f in data))" 2>/dev/null || echo "")"

  local static_score semantic_score reputation_score final_score
  static_score="$score"
  if [[ -n "$scan_path" ]]; then
    score=$((score - penalty))
    (( score < 0 )) && score=0
  fi

  score=$((score + sem_delta))
  (( score < 0 )) && score=0
  (( score > 100 )) && score=100
  final_score="$score"
  semantic_score=$((50 + sem_delta))
  (( semantic_score < 0 )) && semantic_score=0
  (( semantic_score > 100 )) && semantic_score=100
  reputation_score="$input_score"

  local tier
  tier="$(score_to_tier "$score")"

  if [[ "$tier" == "EXTREME" ]]; then
    with_state_lock update_status "$slug" "pending-blacklist" "$score"
    local reason="extreme verdict"
    [[ -n "$flags" ]] && reason="$reason flags=$flags"
    [[ -n "$sem_flags_str" ]] && reason="$reason sem=$sem_flags_str"
    add_pending_blacklist "$slug" "$reason"
    write_report "$slug" "$score" "REJECT" "$tier" "$input_score" "$static_score" "$semantic_score" "$reputation_score" "$sem_flags_json"
    log_audit "REJECT" "$slug" "tier=$tier score=$score pending-blacklist flags=$flags sem_flags=$sem_flags_str"
    if [[ "$json_output" -eq 1 ]]; then
      emit_json_result "$slug"
    else
      echo "Vetting result: REJECT ($tier) -> pending-blacklist"
    fi
    exit 0
  fi

  if [[ "$tier" == "HIGH" ]]; then
    with_state_lock update_status "$slug" "pending-review" "$score"
    write_report "$slug" "$score" "REVIEW" "$tier" "$input_score" "$static_score" "$semantic_score" "$reputation_score" "$sem_flags_json"
    log_audit "REVIEW" "$slug" "tier=$tier score=$score flags=$flags sem_flags=$sem_flags_str"
    if [[ "$json_output" -eq 1 ]]; then
      emit_json_result "$slug"
    else
      echo "Vetting result: REVIEW ($tier)"
    fi
    exit 0
  fi

  with_state_lock update_status "$slug" "vetted" "$score"
  write_report "$slug" "$score" "PASS" "$tier" "$input_score" "$static_score" "$semantic_score" "$reputation_score" "$sem_flags_json"
  log_audit "PASS" "$slug" "tier=$tier score=$score flags=$flags sem_flags=$sem_flags_str"
  if [[ "$json_output" -eq 1 ]]; then
    emit_json_result "$slug"
  else
    echo "Vetting result: PASS ($tier)"
  fi

  if [[ "$semantic_mode" -eq 1 ]]; then
    local vetting_dispatch="/home/steges/agent/skills/vetting/scripts/vetting-dispatch.sh"
    if [[ -x "$vetting_dispatch" ]]; then
      if [[ "$json_output" -eq 1 ]]; then
        "$vetting_dispatch" "$slug" --json
      else
        "$vetting_dispatch" "$slug"
      fi
    else
      echo "vetting-dispatch.sh nicht gefunden — semantisches Vetting übersprungen" >&2
    fi
  fi
}

main "$@"
