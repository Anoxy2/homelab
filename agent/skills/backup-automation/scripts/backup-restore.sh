#!/bin/bash
# backup-restore.sh - Restore from USB backup
# Usage: backup-restore.sh [DATE] [--dry-run]

set -euo pipefail

readonly USB_MOUNT="/mnt/usb-backup"
readonly BACKUP_ROOT="$USB_MOUNT/backups"
readonly REPO_DIR="/home/steges"
readonly LOG_FILE="/var/log/backup-automation.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [restore] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [restore] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

confirm() {
    local prompt="$1"
    echo -n "$prompt [y/N] "
    read -r response
    [[ "$response" == "y" || "$response" == "Y" ]]
}

# Find backup
find_backup() {
    local date_spec="${1:-latest}"
    
    if [[ "$date_spec" == "latest" ]]; then
        ls -t "$BACKUP_ROOT/" 2>/dev/null | grep -E '^20[0-9]{6}$' | head -1
    else
        if [[ -d "$BACKUP_ROOT/$date_spec" ]]; then
            echo "$date_spec"
        else
            error "Backup not found: $date_spec"
            return 1
        fi
    fi
}

# Restore item
restore_item() {
    local src="$1"
    local dst="$2"
    local name="$3"
    local dry_run="${4:-false}"
    
    log "Restoring $name..."
    
    if [[ ! -e "$src" ]]; then
        log "  Source not found: $src"
        return 0
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        log "  [DRY RUN] Would restore: $src -> $dst"
        return 0
    fi
    
    # Create backup of current state
    if [[ -e "$dst" ]]; then
        local backup_suffix=".restore-backup-$(date +%Y%m%d%H%M%S)"
        log "  Backing up current state: $dst -> $dst$backup_suffix"
        mv "$dst" "$dst$backup_suffix"
    fi
    
    # Restore
    mkdir -p "$(dirname "$dst")"
    
    if cp -r "$src" "$dst"; then
        log "  Restored: $name"
        return 0
    else
        error "  Failed to restore: $name"
        return 1
    fi
}

# Main restore
main() {
    local date_spec="latest"
    local dry_run=false
    local skip_confirm=false
    
    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            --yes|-y)
                skip_confirm=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [DATE] [--dry-run] [--yes]"
                echo ""
                echo "Examples:"
                echo "  $0                    # Restore latest"
                echo "  $0 20260401           # Restore specific date"
                echo "  $0 --dry-run          # Preview what would be restored"
                echo "  $0 --yes              # Skip confirmation"
                exit 0
                ;;
            20[0-9][0-9][0-9][0-9][0-9][0-9])
                date_spec="$1"
                shift
                ;;
            *)
                error "Unknown argument: $1"
                exit 1
                ;;
        esac
    done
    
    log "=== Restore Started ==="
    log "Target backup: $date_spec"
    [[ "$dry_run" == "true" ]] && log "DRY RUN MODE - No changes will be made"
    
    # Find backup
    local backup_date=$(find_backup "$date_spec")
    if [[ -z "$backup_date" ]]; then
        error "No backup found"
        exit 1
    fi
    
    local backup_dir="$BACKUP_ROOT/$backup_date"
    log "Restoring from: $backup_dir"
    
    # Show what will be restored
    echo ""
    echo "The following items will be restored:"
    ls -la "$backup_dir" 2>/dev/null || true
    echo ""
    
    # Confirm
    if [[ "$skip_confirm" != "true" && "$dry_run" != "true" ]]; then
        if ! confirm "Proceed with restore?"; then
            log "Restore cancelled by user"
            exit 0
        fi
    fi
    
    local errors=0
    
    # Restore items
    restore_item "$backup_dir/openclaw-memory" "$REPO_DIR/infra/openclaw-data/memory" "OpenClaw Memory" "$dry_run" || ((errors++))
    restore_item "$backup_dir/pihole" "$REPO_DIR/pihole/etc-pihole" "Pi-hole" "$dry_run" || ((errors++))
    restore_item "$backup_dir/homeassistant" "$REPO_DIR/homeassistant" "Home Assistant" "$dry_run" || ((errors++))
    
    if [[ -d "$backup_dir/vaultwarden" ]]; then
        restore_item "$backup_dir/vaultwarden" "$REPO_DIR/vaultwarden" "Vaultwarden" "$dry_run" || ((errors++))
    fi
    
    # Restore secrets
    if [[ -d "$backup_dir/secrets" ]]; then
        log "Restoring secrets..."
        [[ -f "$backup_dir/secrets/.env" ]] && restore_item "$backup_dir/secrets/.env" "$REPO_DIR/.env" ".env (root)" "$dry_run"
        [[ -f "$backup_dir/secrets/secrets.yaml" ]] && restore_item "$backup_dir/secrets/secrets.yaml" "$REPO_DIR/homeassistant/secrets.yaml" "HA secrets" "$dry_run"
    fi
    
    # Restore SSH
    if [[ -d "$backup_dir/ssh" ]]; then
        restore_item "$backup_dir/ssh" "$REPO_DIR/.ssh" "SSH Keys" "$dry_run" || ((errors++))
    fi
    
    # Restart services if not dry-run
    if [[ "$dry_run" != "true" && "$errors" -eq 0 ]]; then
        log "Restarting services..."
        cd "$REPO_DIR"
        
        # Restart affected containers
        docker restart openclaw 2>/dev/null || true
        docker restart homeassistant 2>/dev/null || true
        docker restart pihole 2>/dev/null || true
        docker restart vaultwarden 2>/dev/null || true
        
        log "Services restarted"
    fi
    
    # Report
    log "=== Restore Completed ==="
    if [[ "$errors" -gt 0 ]]; then
        error "Completed with $errors errors"
        exit 1
    else
        log "Restore successful"
        
        # Notify OpenClaw
        if command -v claw-send.sh >/dev/null 2>&1; then
            /home/steges/scripts/claw-send.sh "✅ Restore completed from $backup_date"
        fi
    fi
}

# Run
main "$@"
