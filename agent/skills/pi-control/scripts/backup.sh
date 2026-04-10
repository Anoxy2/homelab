#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 run"
}

action="${1:-}"

case "$action" in
  run)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    exec /home/steges/scripts/backup.sh
    ;;
  *)
    usage
    exit 1
    ;;
esac