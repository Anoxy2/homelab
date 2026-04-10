#!/bin/bash

set -euo pipefail

SKILLS_CLI="/home/steges/scripts/skills"
EXIT_USAGE=2
EXIT_MISSING_EXECUTABLE=6

usage() {
  echo "Usage: author-skill.sh <name> [--mode auto|template|from-tested|scratch] [--reason <text>]"
}

main() {
  [[ -x "$SKILLS_CLI" ]] || {
    echo "Missing executable: $SKILLS_CLI"
    exit "$EXIT_MISSING_EXECUTABLE"
  }
  [[ $# -ge 1 ]] || { usage; exit "$EXIT_USAGE"; }
  exec "$SKILLS_CLI" authoring "$@"
}

main "$@"
