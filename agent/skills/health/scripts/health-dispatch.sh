#!/bin/bash
set -euo pipefail
# shellcheck source=/dev/null
source "/home/steges/agent/skills/skill-forge/scripts/common.sh"

usage() {
  echo "Usage: health-dispatch.sh report | budget"
}

cmd_report() {
  ensure_dirs
  init_state_files

  python3 - <<'PY'
import json
base = '/home/steges/agent/skills/skill-forge/.state'
with open(base + '/known-skills.json', 'r', encoding='utf-8') as f:
    known = json.load(f)
with open(base + '/canary.json', 'r', encoding='utf-8') as f:
    canary = json.load(f)
print('Skill health report')
for slug, row in sorted(known.items()):
    status = row.get('status', 'unknown')
    score = 90
    if status in ('pending-review', 'pending-blacklist', 'rollback'):
        score = 40
    elif status in ('drafted', 'canary'):
        score = 65
    can = canary.get(slug, {}).get('status')
    can_txt = f' canary={can}' if can else ''
    print(f'- {slug}: {score}/100 status={status}{can_txt}')
PY
}

cmd_budget() {
  ensure_dirs
  init_state_files

  python3 - <<'PY'
import json
base = '/home/steges/agent/skills/skill-forge/.state'
limits = '/home/steges/agent/skills/skill-forge/config/limits.yaml'
with open(base + '/known-skills.json', 'r', encoding='utf-8') as f:
    known = json.load(f)
active = sum(1 for v in known.values() if v.get('status') == 'active')
max_active = 25
try:
    with open(limits, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip().startswith('max_active_skills:'):
                max_active = int(line.split(':', 1)[1].strip())
except Exception:
    pass
estimated_tokens = active * 1600
print('Budget report')
print(f'- active skills: {active}/{max_active}')
print(f'- estimated token load: ~{estimated_tokens}')
if active > max_active:
    print('- status: EXCEEDED')
else:
    print('- status: OK')
PY
}

main() {
  local sub="${1:-report}"
  case "$sub" in
    report) cmd_report ;;
    budget) cmd_budget ;;
    *) usage; exit 1 ;;
  esac
}
main "$@"
