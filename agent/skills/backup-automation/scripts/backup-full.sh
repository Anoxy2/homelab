#!/bin/bash
# backup-full.sh - Main backup entry point
# Orchestrates GitHub + USB backup with notifications

set -euo pipefail

# Config
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SKILL_ROOT="$(dirname "$SCRIPT_DIR")"
readonly STATE_DIR="$SKILL_ROOT/.state"
readonly LOG_FILE="/var/log/backup-automation.log"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly DATE=$(date +%Y%m%d)

# Ensure state dir exists
mkdir -p "$STATE_DIR"

# Logging function (stderr so subshell captures don't pollute JSON results)
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE" >&2
}

error() {
    log "ERROR: $*"
}

# OpenClaw notification
notify_openclaw() {
    local message="$1"
    local priority="${2:-normal}"
    
    if command -v claw-send.sh >/dev/null 2>&1; then
        /home/steges/scripts/claw-send.sh "$message"
    else
        # Direct docker call
        docker exec openclaw openclaw agent \
            --message "$message" \
            --session backup \
            2>/dev/null || true
    fi
    
    log "Notification sent: $message"
}

# GitHub backup using github-automation skill
do_github_backup() {
    log "=== GitHub Backup (via github-automation skill) ==="
    
    local commit_msg="${1:-"backup: automated $TIMESTAMP"}"
    local github_result="{\"success\": false}"
    local GITHUB_SKILL="/home/steges/agent/skills/github-automation/scripts"
    
    # Check if github-automation skill exists
    if [[ ! -d "$GITHUB_SKILL" ]]; then
        error "github-automation skill not found at $GITHUB_SKILL"
        echo "{\"success\": false, \"error\": \"github-automation skill missing\"}"
        return 1
    fi
    
    # Check git status via github-automation
    local status_output
    if ! status_output=$("$GITHUB_SKILL/git-status.sh" 2>/dev/null); then
        error "Failed to get git status"
        echo "{\"success\": false, \"error\": \"git status failed\"}"
        return 1
    fi
    
    # Check if clean
    local is_clean=$(echo "$status_output" | grep -o '"clean": true' || echo "")
    
    if [[ -n "$is_clean" ]]; then
        # Check if ahead of remote
        local ahead=$(echo "$status_output" | grep -o '"ahead": [0-9]*' | grep -o '[0-9]*' || echo "0")
        if [[ "$ahead" -gt 0 ]]; then
            log "$ahead commits ahead, pushing..."
            if "$GITHUB_SKILL/git-push.sh" 2>/dev/null; then
                local commit_hash=$(cd /home/steges && git rev-parse --short HEAD)
                github_result="{\"success\": true, \"commit\": \"$commit_hash\", \"action\": \"push\"}"
                log "GitHub push successful: $commit_hash"
            else
                error "GitHub push failed"
                github_result="{\"success\": false, \"error\": \"push failed\"}"
            fi
        else
            log "GitHub: clean and up-to-date, nothing to do"
            github_result="{\"success\": true, \"commit\": \"none\", \"action\": \"none\"}"
        fi
    else
        # Need to commit
        log "Changes detected, committing..."
        if "$GITHUB_SKILL/git-commit.sh" -m "$commit_msg" 2>/dev/null; then
            if "$GITHUB_SKILL/git-push.sh" 2>/dev/null; then
                local commit_hash=$(cd /home/steges && git rev-parse --short HEAD)
                github_result="{\"success\": true, \"commit\": \"$commit_hash\", \"action\": \"commit+push\"}"
                log "GitHub commit+push successful: $commit_hash"
            else
                error "GitHub push failed after commit"
                github_result="{\"success\": false, \"error\": \"push after commit failed\"}"
            fi
        else
            error "GitHub commit failed"
            github_result="{\"success\": false, \"error\": \"commit failed\"}"
        fi
    fi
    
    echo "$github_result"
}

# USB backup
do_usb_backup() {
    log "=== USB Backup ==="
    
    local usb_result="{\"success\": false}"
    
    if "$SCRIPT_DIR/backup-usb.sh"; then
        # Get backup stats
        local backup_path="/mnt/usb-backup/backups/$DATE"
        local size_mb=$(du -sm "$backup_path" 2>/dev/null | cut -f1)
        local file_count=$(find "$backup_path" -type f 2>/dev/null | wc -l)
        
        usb_result="{\"success\": true, \"path\": \"$backup_path\", \"size_mb\": $size_mb, \"files\": $file_count}"
        log "USB backup successful: ${size_mb}MB, ${file_count} files"
    else
        error "USB backup failed"
        usb_result="{\"success\": false, \"error\": \"usb backup script failed\"}"
    fi
    
    echo "$usb_result"
}

# Save state
save_state() {
    local github_json="$1"
    local usb_json="$2"
    
    cat > "$STATE_DIR/last-backup.json" << EOF
{
  "timestamp": "$TIMESTAMP",
  "date": "$DATE",
  "github": $github_json,
  "usb": $usb_json,
  "overall_success": $(echo "$github_json" | grep -q '"success": true' && echo "$usb_json" | grep -q '"success": true' && echo "true" || echo "false")
}
EOF
}

# Main
main() {
    local commit_msg="${1:-"backup: automated $TIMESTAMP"}"
    local skip_github="${2:-false}"
    local skip_usb="${3:-false}"
    
    log "=========================================="
    log "Backup Automation Started: $TIMESTAMP"
    log "=========================================="
    
    local github_result="{\"success\": false, \"skipped\": true}"
    local usb_result="{\"success\": false, \"skipped\": true}"
    
    # GitHub backup
    if [[ "$skip_github" != "true" ]]; then
        github_result=$(do_github_backup "$commit_msg")
    else
        log "GitHub backup skipped"
    fi
    
    # USB backup
    if [[ "$skip_usb" != "true" ]]; then
        usb_result=$(do_usb_backup)
    else
        log "USB backup skipped"
    fi
    
    # Save state
    save_state "$github_result" "$usb_result"
    
    # Determine overall status
    local github_success=$(echo "$github_result" | grep -o '"success": true' | head -1)
    local usb_success=$(echo "$usb_result" | grep -o '"success": true' | head -1)
    
    if [[ -n "$github_success" && -n "$usb_success" ]]; then
        log "=========================================="
        log "Backup COMPLETED SUCCESSFULLY"
        log "=========================================="
        notify_openclaw "✅ Backup completed: GitHub + USB ($DATE)"
        exit 0
    elif [[ -n "$github_success" ]]; then
        log "=========================================="
        log "Backup PARTIAL (GitHub OK, USB failed)"
        log "=========================================="
        notify_openclaw "⚠️ Backup partial: GitHub OK, USB failed ($DATE)" "warning"
        exit 1
    elif [[ -n "$usb_success" ]]; then
        log "=========================================="
        log "Backup PARTIAL (USB OK, GitHub failed)"
        log "=========================================="
        notify_openclaw "⚠️ Backup partial: USB OK, GitHub failed ($DATE)" "warning"
        exit 1
    else
        log "=========================================="
        log "Backup FAILED"
        log "=========================================="
        notify_openclaw "🚨 Backup FAILED: Both GitHub and USB ($DATE)" "critical"
        exit 2
    fi
}

# Usage
usage() {
    echo "Usage: $0 [commit_message] [--skip-github] [--skip-usb]"
    echo ""
    echo "Examples:"
    echo "  $0                                  # Full backup"
    echo "  $0 'manual backup before update'   # Custom message"
    echo "  $0 '' --skip-usb                    # GitHub only"
    echo "  $0 '' --skip-github                 # USB only"
}

# Parse args
COMMIT_MSG="backup: automated $(date +%Y%m%d_%H%M%S)"
SKIP_GITHUB=false
SKIP_USB=false

for arg in "$@"; do
    case "$arg" in
        --skip-github)
            SKIP_GITHUB=true
            ;;
        --skip-usb)
            SKIP_USB=true
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            COMMIT_MSG="$arg"
            ;;
    esac
done

# Run
main "$COMMIT_MSG" "$SKIP_GITHUB" "$SKIP_USB"
