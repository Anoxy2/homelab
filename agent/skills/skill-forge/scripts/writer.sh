#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

SKILLS_CLI="/home/steges/scripts/skills"

usage() {
  echo "Usage: writer.sh code|docs|config|test <task-text>"
}

main() {
  ensure_dirs
  init_state_files

  [[ $# -ge 2 ]] || { usage; exit "$EXIT_USAGE"; }
  local kind="$1"
  shift
  local task="$*"

  case "$kind" in
    code|docs|config|test) ;;
    *) usage; exit "$EXIT_USAGE" ;;
  esac

  [[ -x "$SKILLS_CLI" ]] || { echo "skills wrapper nicht gefunden oder nicht ausführbar: $SKILLS_CLI" >&2; exit "$EXIT_MISSING_EXECUTABLE"; }

  local out
  out="$("$SKILLS_CLI" coding "$kind" "$task")"

  local job_id path envelope
  job_id="$(echo "$out" | sed -n '1p')"
  path="$(echo "$out" | sed -n '2p')"
  envelope="$(echo "$out" | sed -n '3p')"

  log_audit "WRITER" "$kind" "job=$job_id path=$path envelope=$envelope schema=v1"
  echo "Writer completed: $job_id"
  echo "$path"
}

main "$@"
