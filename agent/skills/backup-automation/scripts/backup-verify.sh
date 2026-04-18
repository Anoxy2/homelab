#!/bin/bash
# backup-verify.sh - Verify backup integrity

set -euo pipefail

readonly USB_MOUNT="/mnt/usb-backup"
readonly BACKUP_ROOT="$USB_MOUNT/backups"
readonly LOG_FILE="/var/log/backup-automation.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [verify] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [verify] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

# Find backup to verify
find_backup() {
    local date_spec="${1:-latest}"
    
    if [[ "$date_spec" == "latest" ]]; then
        # Find most recent backup
        ls -t "$BACKUP_ROOT/" 2>/dev/null | grep -E '^20[0-9]{6}$' | head -1
    else
        # Specific date
        if [[ -d "$BACKUP_ROOT/$date_spec" ]]; then
            echo "$date_spec"
        else
            error "Backup not found: $date_spec"
            return 1
        fi
    fi
}

# Verify checksums
verify_checksums() {
    local backup_dir="$1"
    local checksum_file="$backup_dir/.checksums.sha256"
    
    if [[ ! -f "$checksum_file" ]]; then
        log "No checksums file found, skipping checksum verification"
        return 0
    fi
    
    log "Verifying checksums..."
    cd "$backup_dir"
    
    if sha256sum -c "$checksum_file" --quiet --ignore-missing 2>/dev/null; then
        log "All checksums valid"
        return 0
    else
        error "Checksum verification failed"
        return 1
    fi
}

# Verify SQLite databases
verify_sqlite() {
    local backup_dir="$1"
    local errors=0
    
    log "Verifying SQLite databases..."
    
    # Find all .db and .sqlite files
    while IFS= read -r db; do
        if [[ -f "$db" ]]; then
            log "  Checking: $(basename "$db")"
            if ! sqlite3 "$db" "PRAGMA integrity_check;" | grep -q "ok"; then
                error "    FAILED: $(basename "$db")"
                ((errors++))
            else
                log "    OK: $(basename "$db")"
            fi
        fi
    done < <(find "$backup_dir" -type f \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \) 2>/dev/null)
    
    if [[ "$errors" -gt 0 ]]; then
        error "SQLite verification failed with $errors errors"
        return 1
    fi
    
    log "All SQLite databases valid"
    return 0
}

# Check backup completeness
check_completeness() {
    local backup_dir="$1"
    local missing=()
    
    log "Checking backup completeness..."
    
    # Essential items that should be present
    local required=(
        "openclaw-memory"
        "pihole"
        "homeassistant"
        "vaultwarden"
        "secrets"
        "ssh"
        "mosquitto"
        "esphome"
        "authelia"
        "uptime-kuma"
    )
    
    for item in "${required[@]}"; do
        if [[ ! -e "$backup_dir/$item" ]]; then
            missing+=("$item")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing items: ${missing[*]}"
        return 1
    fi
    
    log "Backup is complete (${#required[@]} essential items present)"
    return 0
}

# Main verification
main() {
    local date_spec="${1:-latest}"
    
    log "=== Backup Verification Started ==="
    log "Target: $date_spec"
    
    # Find backup
    local backup_date=$(find_backup "$date_spec")
    if [[ -z "$backup_date" ]]; then
        error "No backup found"
        return 1
    fi
    
    local backup_dir="$BACKUP_ROOT/$backup_date"
    log "Verifying: $backup_dir"
    
    if [[ ! -d "$backup_dir" ]]; then
        error "Backup directory does not exist: $backup_dir"
        return 1
    fi
    
    # Run checks
    local overall_status="PASSED"
    
    if ! check_completeness "$backup_dir"; then
        overall_status="FAILED"
    fi
    
    if ! verify_checksums "$backup_dir"; then
        overall_status="FAILED"
    fi
    
    if ! verify_sqlite "$backup_dir"; then
        overall_status="FAILED"
    fi
    
    # Report
    log "=== Verification $overall_status ==="
    
    # Save verify state
    local verify_state="$backup_dir/.verify.json"
    cat > "$verify_state" << EOF
{
  "verified_at": "$(date -Iseconds)",
  "backup_date": "$backup_date",
  "status": "$overall_status",
  "checks": {
    "completeness": true,
    "checksums": true,
    "sqlite": true
  }
}
EOF
    
    if [[ "$overall_status" == "PASSED" ]]; then
        return 0
    else
        return 1
    fi
}

# Run
main "$@"
