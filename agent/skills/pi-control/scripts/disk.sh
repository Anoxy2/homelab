#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 df | backups"
}

action="${1:-}"

case "$action" in
  df)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    exec df -h /
    ;;
  backups)
    [[ $# -eq 1 ]] || { usage; exit 1; }
    exec du -sh /home/steges/backups/
    ;;
  *)
    usage
    exit 1
    ;;
esac