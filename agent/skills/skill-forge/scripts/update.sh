#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

show_updates() {
python3 - <<'PY'
import json
p='/home/steges/agent/skills/skill-forge/.state/known-skills.json'
with open(p,'r',encoding='utf-8') as f: d=json.load(f)
print('Update candidates:')
for slug,row in sorted(d.items()):
    st=row.get('status','unknown')
    if st in ('active','vetted','reviewed'):
        prev=row.get('version','n/a')
        print(f'- {slug} ({st}) version={prev}')
PY
}

append_update_log() {
  local slug="$1"
  local mode="$2"
  local note="$3"
  python3 - "$slug" "$mode" "$note" <<'PY'
import json
import sys

sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import utc_now_iso, write_json_atomic

slug, mode, note = sys.argv[1], sys.argv[2], sys.argv[3]
kp='/home/steges/agent/skills/skill-forge/.state/known-skills.json'
lp='/home/steges/agent/skills/skill-forge/.state/update-log.json'

with open(kp,'r',encoding='utf-8') as f: known=json.load(f)
with open(lp,'r',encoding='utf-8') as f: log=json.load(f)
row=known.get(slug,{})
entry={
  'slug': slug,
  'mode': mode,
  'timestamp': utc_now_iso(),
  'status_after': row.get('status','unknown'),
  'version_after': row.get('version','unknown'),
  'note': note,
}
log.append(entry)
write_json_atomic(lp, log)
PY
}

get_vetting_score() {
  local slug="$1"
  python3 - "$slug" <<'PY'
import json, sys
slug = sys.argv[1]
p = '/home/steges/agent/skills/skill-forge/.state/known-skills.json'
with open(p, 'r', encoding='utf-8') as f: d = json.load(f)
print(d.get(slug, {}).get('vetting_score', 70))
PY
}

mark_updated() {
  local slug="$1"
  local note="${2:-manual update}"
  python3 - "$slug" "$note" <<'PY'
import json
import sys

sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import utc_now_iso, write_json_atomic

slug, note = sys.argv[1], sys.argv[2]
p='/home/steges/agent/skills/skill-forge/.state/known-skills.json'

with open(p,'r',encoding='utf-8') as f: d=json.load(f)
if slug not in d:
    print('NOT_FOUND'); raise SystemExit(2)
d[slug]['updated_at']=utc_now_iso()
if d[slug].get('status')!='pending-blacklist':
    d[slug]['status']='active'
d[slug]['last_update_note']=note
write_json_atomic(p, d)
print('OK')
PY
}

ensure_skill_exists() {
  local slug="$1"
  python3 - "$slug" <<'PY'
import json, sys
slug = sys.argv[1]
p = '/home/steges/agent/skills/skill-forge/.state/known-skills.json'
with open(p, 'r', encoding='utf-8') as f:
    d = json.load(f)
if slug not in d:
    print('NOT_FOUND')
    raise SystemExit(2)
print('OK')
PY
}

main(){
  ensure_dirs; init_state_files
  if [[ "${1:-}" == "--dry-run" ]]; then show_updates; exit 0; fi
  if [[ "${1:-}" == "--all" ]]; then
    while IFS= read -r slug; do
      [[ -z "$slug" ]] && continue
      local score
      score="$(get_vetting_score "$slug")"
      "$SCRIPT_DIR/vet.sh" "$slug" "$score" >/dev/null 2>&1 || true
      local st
      st="$(python3 - "$slug" <<'PY'
import json, sys
slug=sys.argv[1]
p='/home/steges/agent/skills/skill-forge/.state/known-skills.json'
with open(p,'r',encoding='utf-8') as f: d=json.load(f)
print(d.get(slug,{}).get('status','unknown'))
PY
)"
      if [[ "$st" == "vetted" || "$st" == "active" ]]; then
        with_state_lock mark_updated "$slug" "bulk update run" >/dev/null || true
        with_state_lock append_update_log "$slug" "all" "bulk update run"
        log_audit "UPDATE" "$slug" "all score=$score"
        echo "Updated: $slug"
      else
        with_state_lock append_update_log "$slug" "all" "re-vetting blocked status=$st"
        log_audit "UPDATE-BLOCKED" "$slug" "all status=$st score=$score"
        echo "Re-vetting blocked: $slug (status=$st)"
      fi
    done < <(python3 - <<'PY'
import json
p='/home/steges/agent/skills/skill-forge/.state/known-skills.json'
with open(p,'r',encoding='utf-8') as f: d=json.load(f)
for s,r in sorted(d.items()):
    if r.get('status') in ('active','vetted','reviewed'):
        print(s)
PY
)
    exit 0
  fi
  [[ $# -ge 1 ]] || { echo "Usage: update.sh <slug>|--all|--dry-run [--changelog <text>]"; exit 1; }
  local slug="$1"
  shift
  local note="manual update"
  if [[ "${1:-}" == "--changelog" ]]; then
    [[ -n "${2:-}" ]] || { echo "Missing changelog text"; exit 1; }
    note="${2:-manual update}"
  fi

  ensure_skill_exists "$slug" >/dev/null
  local score
  score="$(get_vetting_score "$slug")"
  "$SCRIPT_DIR/vet.sh" "$slug" "$score" >/dev/null 2>&1 || true
  local st
  st="$(python3 - "$slug" <<'PY'
import json, sys
slug=sys.argv[1]
p='/home/steges/agent/skills/skill-forge/.state/known-skills.json'
with open(p,'r',encoding='utf-8') as f: d=json.load(f)
print(d.get(slug,{}).get('status','unknown'))
PY
)"
  if [[ "$st" == "vetted" || "$st" == "active" ]]; then
    with_state_lock mark_updated "$slug" "$note" >/dev/null
    with_state_lock append_update_log "$slug" "single" "$note"
    log_audit "UPDATE" "$slug" "single note=$note score=$score"
    echo "Updated: $slug"
  else
    with_state_lock append_update_log "$slug" "single" "re-vetting blocked status=$st"
    log_audit "UPDATE-BLOCKED" "$slug" "single status=$st score=$score"
    echo "Re-vetting blocked: $slug (status=$st)"
  fi
}
main "$@"
