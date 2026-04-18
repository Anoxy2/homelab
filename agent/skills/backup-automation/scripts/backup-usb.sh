#!/bin/bash
# backup-usb.sh - USB backup operations
# Handles mount, rsync, cleanup, and verification

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly USB_MOUNT="/mnt/usb-backup"
readonly BACKUP_ROOT="$USB_MOUNT/backups"
readonly SOURCE_DIR="/home/steges"
readonly LOG_FILE="/var/log/backup-automation.log"
readonly RETENTION_DAYS=14

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [usb] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [usb] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

# Check if USB is mounted
check_mount() {
    if mountpoint -q "$USB_MOUNT"; then
        log "USB mounted at $USB_MOUNT"
        return 0
    fi
    
    log "USB not mounted, attempting mount..."
    
    # Try to mount
    if mount "$USB_MOUNT" 2>/dev/null; then
        log "Mount successful"
        return 0
    fi
    
    # Try with device
    local device=$(findmnt -n -o SOURCE "$USB_MOUNT" 2>/dev/null || echo "")
    if [[ -n "$device" ]]; then
        if mount "$device" "$USB_MOUNT" 2>/dev/null; then
            log "Mount successful (device: $device)"
            return 0
        fi
    fi
    
    error "Failed to mount USB at $USB_MOUNT"
    return 1
}

# Get USB stats
get_stats() {
    if ! check_mount; then
        return 1
    fi
    
    local device=$(findmnt -n -o SOURCE "$USB_MOUNT")
    local size=$(df -h "$USB_MOUNT" | tail -1 | awk '{print $2}')
    local used=$(df -h "$USB_MOUNT" | tail -1 | awk '{print $3}')
    local available=$(df -h "$USB_MOUNT" | tail -1 | awk '{print $4}')
    local used_percent=$(df -h "$USB_MOUNT" | tail -1 | awk '{print $5}' | tr -d '%')
    
    log "USB Stats: $used / $size used ($used_percent%), $available free"
    
    # Alert if getting full
    if [[ "$used_percent" -gt 80 ]]; then
        log "WARNING: USB is ${used_percent}% full"
    fi
    
    return 0
}

# Create backup directory
create_backup_dir() {
    local date="$(date +%Y%m%d)"
    local backup_dir="$BACKUP_ROOT/$date"
    
    mkdir -p "$backup_dir"
    echo "$backup_dir"
}

# Backup specific path
backup_path() {
    local src="$1"
    local dst="$2"
    local name="$3"
    
    log "Backing up $name..."
    
    if [[ ! -e "$src" ]]; then
        log "  Skipping $name (not found: $src)"
        return 0
    fi
    
    mkdir -p "$(dirname "$dst")"
    
    # Use rsync with appropriate options
    # Exit code 23 = partial transfer (some files not readable, e.g. container-owned files) — acceptable for best-effort backup
    local rsync_exit=0
    rsync -av --delete --ignore-errors \
        --exclude='*.log' \
        --exclude='tmp/' \
        --exclude='temp/' \
        --exclude='node_modules/' \
        --exclude='__pycache__/' \
        "$src" "$dst" || rsync_exit=$?

    if [[ "$rsync_exit" -eq 0 || "$rsync_exit" -eq 23 || "$rsync_exit" -eq 24 ]]; then
        local size=$(du -sm "$dst" 2>/dev/null | cut -f1)
        log "  $name: ${size}MB${rsync_exit:+ (partial, some files skipped)}"
        return 0
    else
        error "  Failed to backup $name (rsync exit: $rsync_exit)"
        return 1
    fi
}

# Main backup
run_backup() {
    log "=== USB Backup Started ==="
    
    # Check mount
    if ! check_mount; then
        return 1
    fi
    
    # Check stats
    get_stats
    
    # Create backup dir
    local backup_dir=$(create_backup_dir)
    log "Backup directory: $backup_dir"
    
    local errors=0
    
    # 1. OpenClaw Memory
    backup_path \
        "$SOURCE_DIR/infra/openclaw-data/memory/" \
        "$backup_dir/openclaw-memory/" \
        "OpenClaw Memory" \
        || ((errors++))
    
    # 2. Pi-hole
    backup_path \
        "$SOURCE_DIR/pihole/config/" \
        "$backup_dir/pihole/" \
        "Pi-hole" \
        || ((errors++))
    
    # 3. Home Assistant
    backup_path \
        "$SOURCE_DIR/homeassistant/" \
        "$backup_dir/homeassistant/" \
        "Home Assistant" \
        || ((errors++))
    
    # 4. Grafana
    backup_path \
        "$SOURCE_DIR/grafana/data/grafana.db" \
        "$backup_dir/grafana/" \
        "Grafana DB" \
        || ((errors++))
    
    # 5. Vaultwarden
    backup_path \
        "$SOURCE_DIR/vaultwarden/" \
        "$backup_dir/vaultwarden/" \
        "Vaultwarden" \
        || ((errors++))
    
    # 6. Secrets
    mkdir -p "$backup_dir/secrets"
    [[ -f "$SOURCE_DIR/.env" ]] && cp "$SOURCE_DIR/.env" "$backup_dir/secrets/"
    [[ -f "$SOURCE_DIR/infra/.env" ]] && cp "$SOURCE_DIR/infra/.env" "$backup_dir/secrets/"
    [[ -f "$SOURCE_DIR/homeassistant/secrets.yaml" ]] && cp "$SOURCE_DIR/homeassistant/secrets.yaml" "$backup_dir/secrets/"
    log "  Secrets: backed up"
    
    # 7. SSH Keys
    backup_path \
        "$SOURCE_DIR/.ssh/" \
        "$backup_dir/ssh/" \
        "SSH Keys" \
        || ((errors++))
    
    # 8. Git Config
    [[ -f "$SOURCE_DIR/.gitconfig" ]] && cp "$SOURCE_DIR/.gitconfig" "$backup_dir/"
    log "  Git config: backed up"
    
    # Sync to ensure writes complete
    sync
    
    # Create checksums (exclude the checksum file itself to avoid self-reference)
    log "Creating checksums..."
    cd "$backup_dir"
    find . -type f ! -name '.checksums.sha256' -exec sha256sum {} \; > "$backup_dir/.checksums.sha256"
    log "Checksums created"
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Unmount (optional - safer for removable media)
    # umount "$USB_MOUNT"
    
    log "=== USB Backup Completed ==="
    
    if [[ "$errors" -gt 0 ]]; then
        error "Completed with $errors errors"
        return 1
    fi
    
    return 0
}

# Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up old backups (>$RETENTION_DAYS days)..."
    
    local deleted=0
    while IFS= read -r dir; do
        if [[ -d "$dir" ]]; then
            log "  Removing: $(basename "$dir")"
            rm -rf "$dir"
            ((deleted++))
        fi
    done < <(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "20*" -mtime +$RETENTION_DAYS 2>/dev/null)
    
    log "Removed $deleted old backups"
}

# Main
main() {
    # Parse args
    local verify=false
    local cleanup=true
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verify)
                verify=true
                shift
                ;;
            --no-cleanup)
                cleanup=false
                shift
                ;;
            *)
                break
                ;;
        esac
    done
    
    run_backup
    
    # Verify if requested
    if [[ "$verify" == "true" ]]; then
        log "Running verification..."
        "$SCRIPT_DIR/backup-verify.sh" latest
    fi
}

# Run
main "$@"
