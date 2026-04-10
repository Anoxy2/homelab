#!/bin/bash
# Pulled neue Images und startet alle Services neu

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/steges/scripts/common.sh
source "$SCRIPT_DIR/common.sh"

cd "$HOME"

MIN_FREE_KB="${UPDATE_STACKS_MIN_FREE_KB:-2097152}"

log_info "Compose-Konfiguration validieren"
docker compose config --quiet

log_info "Pre-Update Backup"
if ! bash "$HOME/scripts/backup.sh"; then
    log_error "Backup fehlgeschlagen - Update wird abgebrochen"
    exit 1
fi
log_info "Backup OK"

free_kb="$(df --output=avail "$HOME" | awk 'NR==2 {print $1}')"
if [[ -z "$free_kb" ]] || (( free_kb < MIN_FREE_KB )); then
    log_error "Zu wenig freier Speicher fuer Update: ${free_kb:-unknown} KB < ${MIN_FREE_KB} KB"
    exit 1
fi
log_info "Freier Speicher OK: ${free_kb} KB"

echo ""
log_info "Pulling new images"
docker compose pull

echo ""
log_info "Restarting all services"
docker compose up -d --remove-orphans

echo ""
log_info "Post-Update Health-Check"
sleep 10
if ! bash "$HOME/scripts/health-check.sh"; then
    log_error "Post-Update Health-Check fehlgeschlagen"
    exit 1
fi
