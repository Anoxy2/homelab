#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

main(){
  ensure_dirs; init_state_files
  [[ $# -eq 1 ]] || { echo "Usage: provenance-show.sh <slug>"; exit 1; }
  local slug="$1"
  local dir="$STATE_DIR/provenance/$slug"
  [[ -d "$dir" ]] || { echo "No provenance for $slug"; exit 0; }
  ls -1 "$dir" | sort
}
main "$@"
