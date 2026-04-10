#!/bin/bash
# scout-dispatch.sh — Scout skill dispatcher
# Entdeckt neue Skills in konfigurierbaren Hubs.
# Mit --semantic: Analyst (Relevanz-Scoring) + Curator (lernt Suchbegriffe).
#
# Usage:
#   scout-dispatch.sh --dry-run [--json]
#   scout-dispatch.sh --live [N] [--json] [--semantic]
#   scout-dispatch.sh --summary [--json]
#   scout-dispatch.sh --add <slug> <source> <version>
#   scout-dispatch.sh --apply-suggestions [--dry-run]

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SM_ROOT="/home/steges/agent/skills/skill-forge"
HUBS_JSON="$SKILL_DIR/config/hubs.json"
CURATOR_SUGGESTIONS="$SKILL_DIR/.state/curator-suggestions.json"
SM_STATE="$SM_ROOT/.state"
KNOWN_SKILLS="$SM_STATE/known-skills.json"
AUDIT_LOG="$SM_STATE/audit-log.jsonl"

# shellcheck source=/dev/null
source "$SM_ROOT/scripts/common.sh"

usage() {
  cat <<'EOF'
Usage:
  scout-dispatch.sh --dry-run [--json]
  scout-dispatch.sh --live [N] [--json] [--semantic]
  scout-dispatch.sh --summary [--json]
  scout-dispatch.sh --add <slug> <source> <version>
  scout-dispatch.sh --apply-suggestions [--dry-run]
EOF
}

# Retry-Wrapper mit exponential backoff für GitHub API (429: Too many requests)
curl_with_backoff() {
  local url="$1"
  local output="$2"
  local max_attempts=3
  local attempt=1
  local backoff=2
  
  while [[ $attempt -le $max_attempts ]]; do
    if curl -fsSL --connect-timeout 5 --max-time 10 "$url" -o "$output"; then
      return 0
    fi
    
    local http_code
    http_code=$(curl -fsSLI --connect-timeout 5 --max-time 10 "$url" 2>/dev/null | head -1 | awk '{print $2}' 119 echo "0")
    
    # Rate limit: wait and retry
    if [[ "$http_code" == "429" ]]; then
      echo "DEBUG: GitHub rate limit detected, retry ${attempt}/${max_attempts} after ${backoff}s" >&2
      sleep "$backoff"
      backoff=$((backoff * 2))
      attempt=$((attempt + 1))
      continue
    fi
    
    # Other error: fail
    return 1
  done
  
  return 1
}

# ── State helpers ────────────────────────────────────────────────────────────

add_discovered() {
  local slug="$1"
  local source_name="$2"
  local version="$3"

  python3 - "$slug" "$source_name" "$version" "$KNOWN_SKILLS" <<'PY'
import json, sys
sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import utc_now_iso, write_json_atomic

slug, source_name, version, path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)
now = utc_now_iso()
row = data.get(slug, {
    'slug': slug,
    'status': 'discovered',
    'discovered_at': now,
})
row['source'] = source_name
row['version'] = version
row['last_scout'] = now
if 'scout_score' not in row:
    row['scout_score'] = 8
if row.get('status') in (None, 'unknown'):
    row['status'] = 'discovered'
data[slug] = row
write_json_atomic(path, data)
PY

  log_audit "DISCOVER" "$slug" "source=$source_name version=$version"
  echo "Discovered: $slug ($source_name $version)"
}

run_summary() {
  python3 - "$KNOWN_SKILLS" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
counts = {}
for v in data.values():
    s = v.get('status', 'unknown')
    counts[s] = counts.get(s, 0) + 1
print('Scout summary:')
for k in sorted(counts):
    print(f'- {k}: {counts[k]}')
print(f'- total: {len(data)}')
PY
}

run_summary_json() {
  python3 - "$KNOWN_SKILLS" <<'PY'
import json, sys
from datetime import datetime, timezone
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
counts = {}
for v in data.values():
    s = v.get('status', 'unknown')
    counts[s] = counts.get(s, 0) + 1
print(json.dumps({
    'kind': 'scout_summary',
    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'total': len(data),
    'counts': counts,
}, indent=2))
PY
}

print_semantic_json() {
  local analyst_out="$1"
  local curator_out="$2"

  python3 -c "
import json, sys
a=json.loads('''$analyst_out''')
c=json.loads('''$curator_out''')
print(json.dumps({'kind':'scout_semantic','analyst':a,'curator':c}, indent=2))
"
}

# ── Hub discovery ────────────────────────────────────────────────────────────

run_live_scout() {
  local limit="${1:-20}"
  require_cmd curl

  local tmp
  tmp="$(mktemp)"

  # Hubs aus hubs.json lesen (nicht hardcoded)
  mapfile -t github_specs < <(python3 - "$HUBS_JSON" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    cfg = json.load(f)
for s in cfg.get('sources', []):
    if s.get('type') == 'github':
        print(f"{s['name']}|{s['owner']}|{s['repo']}|{s.get('branch','main')}")
PY
)

  mapfile -t clawhub_specs < <(python3 - "$HUBS_JSON" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    cfg = json.load(f)
search_terms = cfg.get('search_terms', [])
for s in cfg.get('sources', []):
    if s.get('type') == 'clawhub':
        terms_str = '|'.join(search_terms)
        print(f"{s['name']}|{s['registry']}|{terms_str}")
PY
)

  local now_ver
  now_ver="$(date -u +%Y.%m.%d)"

  : > "$tmp"

  # GitHub hubs
  for spec in "${github_specs[@]}"; do
    IFS='|' read -r source_name owner repo branch <<< "$spec"
    local api_url="https://api.github.com/repos/$owner/$repo/git/trees/$branch?recursive=1"
    local t
    t="$(mktemp)"
    if ! curl -fsSL "$api_url" -o "$t"; then
      rm -f "$t"
      echo "Live scout warning: cannot fetch $api_url" >&2
      continue
    fi

    python3 - "$t" "$source_name" >> "$tmp" <<'PY'
import json, sys
path, source = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)
for node in data.get('tree', []):
    p = node.get('path', '')
    if not (p.lower().endswith('/skill.md') or p.lower() == 'skill.md'):
        continue
    parts = p.replace('\\', '/').split('/')
    slug = parts[-2] if len(parts) >= 2 else parts[-1].rsplit('.', 1)[0]
    slug = slug.strip()
    if slug:
        print(f"{source}|{slug}")
PY
    rm -f "$t"
  done

  # ClawHub hubs — via /api/v1/search?q=<term>
  # Läuft separat, außerhalb des GitHub-Limits, damit clawhub-Ergebnisse
  # immer hinzugefügt werden unabhängig davon wie viele GitHub-Slugs gefunden wurden.
  local clawhub_discovered=()
  for spec in "${clawhub_specs[@]}"; do
    local source_name registry terms_str
    source_name="${spec%%|*}"
    rest="${spec#*|}"
    registry="${rest%%|*}"
    terms_str="${rest#*|}"

    IFS='|' read -ra terms <<< "$terms_str"
    local ch_tmp seen_ch
    ch_tmp="$(mktemp)"
    : > "$ch_tmp"
    declare -A seen_ch=()
    for term in "${terms[@]}"; do
      local search_url="${registry}/api/v1/search?q=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$term")&limit=10"
      local r
      r="$(mktemp)"
      if curl -fsSL --connect-timeout 5 --max-time 10 "$search_url" -o "$r" 2>/dev/null; then
        python3 - "$r" "$source_name" >> "$ch_tmp" <<'PY'
import json, sys
path, source = sys.argv[1], sys.argv[2]
try:
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    for item in data.get('results', []):
        slug = item.get('slug', '').strip()
        if slug:
            print(f"{source}|{slug}")
except Exception:
    pass
PY
      fi
      rm -f "$r"
    done
    # Dedup clawhub results und direkt registrieren
    while IFS= read -r row; do
      [[ -z "$row" || "$row" != *"|"* ]] && continue
      local ch_source ch_slug
      ch_source="${row%%|*}"
      ch_slug="${row#*|}"
      local ch_key="${ch_slug,,}"
      if [[ -z "${seen_ch[$ch_key]+_}" ]]; then
        seen_ch[$ch_key]=1
        with_state_lock add_discovered "$ch_slug" "$ch_source" "$now_ver"
        clawhub_discovered+=("$row")
      fi
    done < "$ch_tmp"
    rm -f "$ch_tmp"
    unset seen_ch
  done

  mapfile -t discovered < <(python3 - "$tmp" "$limit" <<'PY'
import sys
from collections import OrderedDict
path, limit = sys.argv[1], int(sys.argv[2])
seen = OrderedDict()
with open(path, 'r', encoding='utf-8') as f:
    for raw in f:
        row = raw.strip()
        if not row or '|' not in row:
            continue
        source, slug = row.split('|', 1)
        key = slug.lower()
        if key not in seen:
            seen[key] = (source, slug)
for i, (_, (source, slug)) in enumerate(seen.items()):
    if i >= limit:
        break
    print(f"{source}|{slug}")
PY
)
  rm -f "$tmp"

  for row in "${discovered[@]}"; do
    local source_name slug
    source_name="${row%%|*}"
    slug="${row#*|}"
    with_state_lock add_discovered "$slug" "$source_name" "$now_ver"
  done

  # source-cache aktualisieren
  python3 - "$now_ver" "$SM_STATE/source-cache.json" <<'PY'
import json, sys
from datetime import datetime, timezone
version, cache_path = sys.argv[1], sys.argv[2]
try:
    with open(cache_path, 'r', encoding='utf-8') as f:
        cache = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    cache = {}
cache['last_live_scout'] = {
    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'version': version,
}
with open(cache_path, 'w', encoding='utf-8') as f:
    json.dump(cache, f, indent=2, sort_keys=True)
PY

  echo "Live scout discovered: ${#discovered[@]}"

  # Entdeckte Slugs zurückgeben für Analyst/Curator
  printf '%s\n' "${discovered[@]}"
}

# ── Analyst: Relevanz-Scoring ────────────────────────────────────────────────

run_analyst() {
  local discovered_list="$1"   # newline-separated "source|slug"

  python3 - "$discovered_list" "$KNOWN_SKILLS" "$HUBS_JSON" <<'PY'
import json, sys

raw_list, known_path, hubs_path = sys.argv[1], sys.argv[2], sys.argv[3]

with open(known_path, 'r', encoding='utf-8') as f:
    known = json.load(f)
with open(hubs_path, 'r', encoding='utf-8') as f:
    hubs_cfg = json.load(f)

profile_terms = [t.lower() for t in hubs_cfg.get('search_terms', [])]
active_slugs = {k for k, v in known.items() if v.get('status') in ('active', 'vetted', 'matured')}
active_sources = {v.get('source', '') for k, v in known.items() if v.get('status') == 'active'}

results = []
for row in raw_list.strip().split('\n'):
    if not row or '|' not in row:
        continue
    source, slug = row.split('|', 1)
    txt = slug.lower().replace('-', ' ').replace('_', ' ')

    score = 5  # base
    rationale = []

    # Bereits bekannt?
    if slug in known:
        existing_status = known[slug].get('status', 'unknown')
        if existing_status in ('active', 'vetted', 'matured'):
            score = 0
            rationale.append(f'Bereits {existing_status} — skip')
            results.append({'slug': slug, 'source': source, 'relevance_score': score,
                            'rationale': ' '.join(rationale)})
            continue
        elif existing_status in ('pending-blacklist', 'blacklisted'):
            score = 0
            rationale.append(f'Blacklist-Status: {existing_status} — skip')
            results.append({'slug': slug, 'source': source, 'relevance_score': score,
                            'rationale': ' '.join(rationale)})
            continue

    # Profil-Match
    matches = [t for t in profile_terms if t in txt]
    if matches:
        score += len(matches) * 2
        rationale.append(f'Profil-Match: {", ".join(matches)}')

    # Bewährte Quelle
    if source in active_sources:
        score += 2
        rationale.append(f'Quelle {source!r} hat bereits aktive Skills geliefert')

    # Ähnlichkeit zu aktiven Skills (Teilstring-Match)
    similar = [s for s in active_slugs if any(w in s for w in txt.split())]
    if similar:
        score += 1
        rationale.append(f'Ähnlich zu aktiven Skills: {similar[:3]}')

    score = min(score, 10)
    results.append({
        'slug': slug,
        'source': source,
        'relevance_score': score,
        'rationale': ' '.join(rationale) if rationale else 'Kein spezifischer Match',
    })

results.sort(key=lambda x: x['relevance_score'], reverse=True)
print(json.dumps({'kind': 'scout_analyst', 'candidates': results}, indent=2))
PY
}

# ── Curator: Suchbegriffe + Quellen lernen ───────────────────────────────────

run_curator() {
  python3 - "$KNOWN_SKILLS" "$HUBS_JSON" "$CURATOR_SUGGESTIONS" <<'PY'
import json, sys, re
from datetime import datetime, timezone

known_path, hubs_path, suggestions_path = sys.argv[1], sys.argv[2], sys.argv[3]

with open(known_path, 'r', encoding='utf-8') as f:
    known = json.load(f)
with open(hubs_path, 'r', encoding='utf-8') as f:
    hubs_cfg = json.load(f)
try:
    with open(suggestions_path, 'r', encoding='utf-8') as f:
        suggestions_log = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    suggestions_log = []

existing_terms = set(t.lower() for t in hubs_cfg.get('search_terms', []))
existing_sources = {s['name'] for s in hubs_cfg.get('sources', [])}

# Alle aktiven/reifen Skills analysieren → Wörter aus Slugs extrahieren
valued_statuses = {'active', 'vetted', 'matured', 'canary'}
valued_slugs = [k for k, v in known.items() if v.get('status') in valued_statuses]
blacklisted_sources = {
    v.get('source', '') for v in known.values()
    if v.get('status') in ('blacklisted', 'pending-blacklist')
}

# Wortfrequenz aus Slug-Namen
word_freq = {}
for slug in valued_slugs:
    words = re.split(r'[-_]', slug.lower())
    for w in words:
        if len(w) >= 4 and w not in ('skill', 'test', 'demo', 'base', 'core', 'main'):
            word_freq[w] = word_freq.get(w, 0) + 1

# Neue Suchbegriffe: häufig in aktiven Skills, noch nicht in Profil
new_terms = []
for word, freq in sorted(word_freq.items(), key=lambda x: -x[1]):
    if word not in existing_terms and freq >= 2:
        confidence = min(0.5 + freq * 0.1, 0.95)
        new_terms.append({'term': word, 'frequency': freq, 'confidence': confidence})

# Quellen bewerten: welche liefern viele aktive Skills?
source_scores = {}
for v in known.values():
    src = v.get('source', '')
    if not src:
        continue
    if v.get('status') in valued_statuses:
        source_scores[src] = source_scores.get(src, 0) + 1

# Quellen-Empfehlungen (aktuell nur Info-Level, keine auto-add)
recommended_sources = [
    {'name': src, 'active_skills': count, 'confidence': min(0.3 + count * 0.1, 0.8)}
    for src, count in sorted(source_scores.items(), key=lambda x: -x[1])
    if src not in existing_sources and src not in blacklisted_sources and count >= 2
]

now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
result = {
    'kind': 'scout_curator',
    'timestamp': now,
    'suggested_terms': new_terms,
    'recommended_sources': recommended_sources,
}

# Ins Suggestions-Log schreiben
suggestions_log.append(result)
# Nur letzte 50 Einträge behalten
suggestions_log = suggestions_log[-50:]
with open(suggestions_path, 'w', encoding='utf-8') as f:
    json.dump(suggestions_log, f, indent=2)

print(json.dumps(result, indent=2))
PY
}

apply_curator_suggestions() {
  local dry_run="${1:-0}"

  python3 - "$HUBS_JSON" "$CURATOR_SUGGESTIONS" "$dry_run" <<'PY'
import json, sys
from datetime import datetime, timezone

hubs_path, suggestions_path, dry_run_arg = sys.argv[1], sys.argv[2], sys.argv[3]
dry_run = dry_run_arg == '1'

with open(hubs_path, 'r', encoding='utf-8') as f:
    hubs_cfg = json.load(f)
try:
    with open(suggestions_path, 'r', encoding='utf-8') as f:
        suggestions_log = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    suggestions_log = []

if not suggestions_log:
    print('Keine Curator-Vorschläge vorhanden.')
    sys.exit(0)

latest = suggestions_log[-1]
existing_terms = set(t.lower() for t in hubs_cfg.get('search_terms', []))
added = []
pending = []

for item in latest.get('suggested_terms', []):
    term = item['term']
    confidence = item['confidence']
    if term in existing_terms:
        continue
    if confidence >= 0.7:
        added.append(term)
    else:
        pending.append({'term': term, 'confidence': confidence})

if dry_run:
    print(f'[dry-run] Würde hinzufügen: {added}')
    print(f'[dry-run] Pending (confidence < 0.7): {[p["term"] for p in pending]}')
    sys.exit(0)

for term in added:
    hubs_cfg.setdefault('search_terms', []).append(term)

hubs_cfg['updated_at'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
hubs_cfg['curator_version'] = hubs_cfg.get('curator_version', 0) + 1

with open(hubs_path, 'w', encoding='utf-8') as f:
    json.dump(hubs_cfg, f, indent=2)

if added:
    print(f'Neue Suchbegriffe hinzugefügt: {added}')
if pending:
    print(f'Pending (confidence < 0.7, nicht angewendet): {[p["term"] for p in pending]}')
PY
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
  ensure_dirs
  init_state_files

  # Sicherstellen dass curator-suggestions.json existiert
  [[ -f "$CURATOR_SUGGESTIONS" ]] || echo '[]' > "$CURATOR_SUGGESTIONS"

  "$SM_ROOT/scripts/policy-lint.sh" >/dev/null

  # Flags parsen
  local cmd="${1:-}"
  local limit=20
  local semantic=0
  local json_mode=0
  local dry_run_apply=0

  # --json Flag in allen Positionen erkennen
  for arg in "$@"; do
    [[ "$arg" == "--json" ]] && json_mode=1
    [[ "$arg" == "--semantic" ]] && semantic=1
  done

  # Incident Freeze → read-only
  if [[ "$(is_incident_freeze_on)" == "1" ]]; then
    if [[ "$json_mode" -eq 1 ]]; then
      run_summary_json
    else
      echo "Incident freeze aktiv: scout läuft im read-only Summary-Modus." >&2
      run_summary
    fi
    exit 0
  fi

  case "$cmd" in
    --add)
      [[ $# -eq 4 ]] || { echo "Usage: scout-dispatch.sh --add <slug> <source> <version>" >&2; exit "$EXIT_USAGE"; }
      with_state_lock add_discovered "$2" "$3" "$4"
      ;;

    --dry-run)
      if [[ "$semantic" -eq 1 ]]; then
        if [[ "$json_mode" -ne 1 ]]; then
          echo "Dry-run + semantic: analysiere vorhandene discovered-Kandidaten..."
        fi
        local discovered_input
        discovered_input="$(python3 - "$KNOWN_SKILLS" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
for slug, v in data.items():
    if v.get('status') == 'discovered':
        print(f"{v.get('source','unknown')}|{slug}")
PY
)"
        local analyst_out
        analyst_out="$(run_analyst "$discovered_input")"
        local curator_out
        curator_out="$(run_curator)"
        if [[ "$json_mode" -eq 1 ]]; then
          print_semantic_json "$analyst_out" "$curator_out"
        else
          echo "=== Analyst ==="
          echo "$analyst_out" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for c in d['candidates'][:10]:
    print(f\"  [{c['relevance_score']:2}] {c['slug']} — {c['rationale'][:60]}\")
"
          echo "=== Curator ==="
          echo "$curator_out" | python3 -c "
import json,sys
d=json.load(sys.stdin)
terms=[t['term'] for t in d.get('suggested_terms',[]) if t['confidence']>=0.7]
pending=[t['term'] for t in d.get('suggested_terms',[]) if t['confidence']<0.7]
print(f\"  Auto-merge: {terms}\")
print(f\"  Pending:    {pending}\")
"
        fi
      else
        if [[ "$json_mode" -eq 1 ]]; then
          run_summary_json
        else
          echo "Dry-run: kein Hub-Pull. Aktueller State:"
          run_summary
        fi
      fi
      ;;

    --live)
      [[ "${2:-}" =~ ^[0-9]+$ ]] && limit="$2"
      local discovered_raw
      discovered_raw="$(run_live_scout "$limit")"
      # Letzte Zeilen sind "source|slug" Einträge (alles nach "Live scout discovered: N")
      local discovered_list
      discovered_list="$(echo "$discovered_raw" | grep -E '^\S+\|\S+' || true)"

      if [[ "$semantic" -eq 1 && -n "$discovered_list" ]]; then
        local analyst_out
        analyst_out="$(run_analyst "$discovered_list")"
        local curator_out
        curator_out="$(run_curator)"

        if [[ "$json_mode" -eq 1 ]]; then
          print_semantic_json "$analyst_out" "$curator_out"
        else
          echo ""
          echo "=== Scout Analyst ==="
          echo "$analyst_out" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for c in d['candidates'][:10]:
    print(f\"  [{c['relevance_score']:2}] {c['slug']} ({c['source']}) — {c['rationale'][:70]}\")
"
          echo ""
          echo "=== Scout Curator ==="
          echo "$curator_out" | python3 -c "
import json,sys
d=json.load(sys.stdin)
high=[t for t in d.get('suggested_terms',[]) if t['confidence']>=0.7]
low=[t for t in d.get('suggested_terms',[]) if t['confidence']<0.7]
print(f\"  Auto-merge ({len(high)}): {[t['term'] for t in high]}\")
print(f\"  Pending   ({len(low)}): {[t['term'] for t in low]}\")
if d.get('recommended_sources'):
    print(f\"  Empfohlene Quellen: {[s['name'] for s in d['recommended_sources']]}\")
"
          # Auto-apply hohe Confidence
          apply_curator_suggestions "0"
        fi
      else
        if [[ "$json_mode" -eq 1 ]]; then
          run_summary_json
        else
          run_summary
        fi
      fi
      ;;

    --apply-suggestions)
      [[ "${2:-}" == "--dry-run" ]] && dry_run_apply=1
      apply_curator_suggestions "$dry_run_apply"
      ;;

    --summary|"")
      if [[ "$json_mode" -eq 1 ]]; then
        run_summary_json
      else
        run_summary
      fi
      ;;

    *)
      usage >&2
      exit "$EXIT_USAGE"
      ;;
  esac
}

main "$@"
