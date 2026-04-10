#!/bin/bash
# Shared parser for recurring passthrough flags.
# Supports: --json, --dry-run, --reason <text>

set -euo pipefail

COMMON_FLAG_JSON=0
COMMON_FLAG_DRY_RUN=0
COMMON_FLAG_REASON=""
COMMON_ARGS=()

parse_common_flags() {
  COMMON_FLAG_JSON=0
  COMMON_FLAG_DRY_RUN=0
  COMMON_FLAG_REASON=""
  COMMON_ARGS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)
        COMMON_FLAG_JSON=1
        shift
        ;;
      --dry-run)
        COMMON_FLAG_DRY_RUN=1
        shift
        ;;
      --reason)
        COMMON_FLAG_REASON="${2:-}"
        [[ -n "$COMMON_FLAG_REASON" ]] || {
          echo "Missing value for --reason" >&2
          return 2
        }
        shift 2
        ;;
      *)
        COMMON_ARGS+=("$1")
        shift
        ;;
    esac
  done
}

append_common_flags() {
  local -n _out_ref=$1
  (( COMMON_FLAG_DRY_RUN == 1 )) && _out_ref+=("--dry-run")
  (( COMMON_FLAG_JSON == 1 )) && _out_ref+=("--json")
  if [[ -n "$COMMON_FLAG_REASON" ]]; then
    _out_ref+=("--reason" "$COMMON_FLAG_REASON")
  fi
}
