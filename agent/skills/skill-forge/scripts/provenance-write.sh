#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

main() {
  ensure_dirs
  init_state_files

  [[ $# -eq 7 ]] || {
    echo "Usage: provenance-write.sh <slug> <source> <url> <upstream_fingerprint> <score> <tier> <version>"
    exit 1
  }

  local slug="$1"
  local source_name="$2"
  local url="$3"
  local upstream_fingerprint="$4"
  local score="$5"
  local tier="$6"
  local version="$7"

  python3 - "$slug" "$source_name" "$url" "$upstream_fingerprint" "$score" "$tier" "$version" <<'PY'
import json, os, sys
from datetime import datetime, timezone
slug, source_name, url, upstream_fingerprint, score, tier, version = sys.argv[1:8]
out_dir = f'/home/steges/agent/skills/skill-forge/.state/provenance/{slug}'
os.makedirs(out_dir, exist_ok=True)
out = f'{out_dir}/{version}.json'
obj = {
  'slug': slug,
  'source': source_name,
  'source_url': url,
  'upstream_fingerprint': upstream_fingerprint,
  'vetting': {
    'score': int(score),
    'risk_tier': tier,
    'policy_version': '1'
  },
  'installed_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
}
with open(out, 'w', encoding='utf-8') as f:
  json.dump(obj, f, indent=2)
print(out)
PY
}

outfile="$(main "$@")"
log_audit "PROVENANCE" "-" "write=$outfile"
echo "Wrote provenance: $outfile"
