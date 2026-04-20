#!/bin/bash
# Checks whether a discovered slug is already covered by a local installed skill.
# Exits 0 always; result written to stdout.
# Stdout: "NEW", "MERGE:<local-slug>", or "SKIP:<local-slug>"
# With --json: machine-readable envelope on stdout instead.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

usage() {
  echo "Usage: overlap-check.sh <slug> [--json]"
}

main() {
  ensure_dirs
  init_state_files
  [[ $# -ge 1 ]] || { usage; exit 1; }

  local slug="$1"
  local json_out=0
  [[ "${2:-}" == "--json" ]] && json_out=1

  python3 - "$slug" "$json_out" <<'PY'
import json, os, re, sys

slug    = sys.argv[1]
json_out = sys.argv[2] == '1'

SKILLS_DIR = '/home/steges/agent/skills'
KP         = '/home/steges/agent/skills/skill-forge/.state/known-skills.json'

with open(KP, 'r', encoding='utf-8') as f:
    known = json.load(f)

def toks(s):
    return [t for t in re.split(r'[^a-z0-9]+', s.lower()) if len(t) > 1]

def skill_keywords(skill_dir):
    """Extract keywords from SKILL.md description line (first 10 non-empty lines)."""
    md = os.path.join(skill_dir, 'SKILL.md')
    words = set()
    try:
        with open(md, 'r', encoding='utf-8') as f:
            for i, line in enumerate(f):
                if i > 20:
                    break
                for w in re.split(r'[^a-z0-9]+', line.lower()):
                    if len(w) > 2:
                        words.add(w)
    except OSError:
        pass
    return words

# Local skills: directories under SKILLS_DIR that have a SKILL.md
local_skills = []
try:
    for entry in os.scandir(SKILLS_DIR):
        if entry.is_dir() and os.path.isfile(os.path.join(entry.path, 'SKILL.md')):
            # Exclude skill-forge itself and internal infrastructure dirs
            if entry.name not in ('skill-forge', 'core', 'profile', 'authoring'):
                local_skills.append(entry.name)
except OSError:
    pass

new_toks = set(toks(slug))
# Also include the joined form (e.g. "home-assistant" → "homeassistant")
new_toks.add(''.join(toks(slug)))
best_match = None
best_score = 0
best_type  = 'NEW'

for local in local_skills:
    if local == slug:
        # Exact match: already installed
        best_match = local
        best_type  = 'SKIP'
        best_score = 1.0
        break

    local_toks  = set(toks(local))
    local_kws   = skill_keywords(os.path.join(SKILLS_DIR, local))
    all_local   = local_toks | local_kws

    shared_name = new_toks & local_toks
    shared_kw   = new_toks & local_kws

    # Score: name-token overlap weighted higher than keyword overlap
    score = len(shared_name) * 0.4 + len(shared_kw) * 0.25

    # First-token match is a strong signal
    nt = toks(slug)
    lt = toks(local)
    if nt and lt and nt[0] == lt[0]:
        score += 0.5

    if score > best_score:
        best_score = score
        best_match = local
        # SKIP if local skill is active and score is high (functionally covered)
        local_status = known.get(local, {}).get('status', '')
        if score >= 0.8 and local_status == 'active':
            best_type = 'SKIP'
        elif score >= 0.4:
            best_type = 'MERGE'
        else:
            best_type = 'NEW'

if best_score < 0.4:
    best_type  = 'NEW'
    best_match = None

if json_out:
    result = {
        'slug':         slug,
        'overlap_type': best_type,
        'covers':       best_match,
        'confidence':   round(min(best_score, 1.0), 2),
    }
    print(json.dumps(result))
else:
    if best_type == 'NEW':
        print('NEW')
    else:
        print(f'{best_type}:{best_match}')
PY
}

main "$@"
