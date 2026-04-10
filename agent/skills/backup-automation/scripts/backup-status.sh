#!/bin/bash
# backup-status.sh - Quick status check for backup system

set -euo pipefail

readonly SKILL_ROOT="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
readonly STATE_FILE="$SKILL_ROOT/.state/last-backup.json"
readonly USB_MOUNT="/mnt/usb-backup"
readonly REPO_DIR="/home/steges"

# Colors (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# GitHub status (via github-automation skill)
check_github() {
    local GITHUB_SKILL="/home/steges/agent/skills/github-automation/scripts"
    
    if [[ ! -f "$GITHUB_SKILL/git-status.sh" ]]; then
        echo "GitHub: ${RED}ERROR - github-automation skill not found${NC}"
        return 1
    fi
    
    local status_output
    if ! status_output=$("$GITHUB_SKILL/git-status.sh" 2>/dev/null); then
        echo "GitHub: ${RED}ERROR - Failed to get status${NC}"
        return 1
    fi
    
    # Parse JSON output
    local branch=$(echo "$status_output" | grep -o '"branch": "[^"]*"' | cut -d'"' -f4)
    local is_clean=$(echo "$status_output" | grep -o '"clean": true' || echo "")
    local ahead=$(echo "$status_output" | grep -o '"ahead": [0-9]*' | grep -o '[0-9]*' || echo "0")
    local modified_count=$(echo "$status_output" | grep -o '"modified": \[' | wc -l || echo "0")
    local last_commit=$(echo "$status_output" | grep -o '"time": "[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [[ -z "$is_clean" ]]; then
        echo "GitHub: ${YELLOW}DIRTY${NC} (branch: $branch)"
    elif [[ "$ahead" -gt 0 ]]; then
        echo "GitHub: ${YELLOW}AHEAD${NC} ($ahead commits to push, branch: $branch)"
    else
        echo "GitHub: ${GREEN}OK${NC} (clean, branch: $branch)"
    fi
    
    return 0
}

# USB status
check_usb() {
    if ! mountpoint -q "$USB_MOUNT"; then
        echo "USB: ${RED}NOT MOUNTED${NC} ($USB_MOUNT)"
        return 1
    fi
    
    local device=$(findmnt -n -o SOURCE "$USB_MOUNT" 2>/dev/null || echo "unknown")
    local size=$(df -h "$USB_MOUNT" 2>/dev/null | tail -1 | awk '{print $2}')
    local used=$(df -h "$USB_MOUNT" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
    local latest=$(ls -t "$USB_MOUNT/backups/" 2>/dev/null | head -1 || echo "none")
    
    if [[ "$used" -gt 90 ]]; then
        echo "USB: ${RED}CRITICAL${NC} ($used% full, device: $device)"
    elif [[ "$used" -gt 80 ]]; then
        echo "USB: ${YELLOW}WARNING${NC} ($used% full, device: $device)"
    else
        echo "USB: ${GREEN}OK${NC} ($used% used, latest: $latest)"
    fi
    
    return 0
}

# Last backup status
check_last_backup() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "Last Backup: ${YELLOW}UNKNOWN${NC} (no state file)"
        return 1
    fi
    
    local timestamp=$(jq -r '.timestamp' "$STATE_FILE" 2>/dev/null || echo "unknown")
    local overall=$(jq -r '.overall_success' "$STATE_FILE" 2>/dev/null || echo "false")
    local github=$(jq -r '.github.success' "$STATE_FILE" 2>/dev/null || echo "false")
    local usb=$(jq -r '.usb.success' "$STATE_FILE" 2>/dev/null || echo "false")
    
    if [[ "$overall" == "true" ]]; then
        echo "Last Backup: ${GREEN}SUCCESS${NC} ($timestamp)"
    elif [[ "$github" == "true" || "$usb" == "true" ]]; then
        echo "Last Backup: ${YELLOW}PARTIAL${NC} ($timestamp)"
    else
        echo "Last Backup: ${RED}FAILED${NC} ($timestamp)"
    fi
    
    # Check if older than 25 hours
    local backup_time=$(date -d "${timestamp:0:8} ${timestamp:9:2}:${timestamp:11:2}" +%s 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local diff_hours=$(( (current_time - backup_time) / 3600 ))
    
    if [[ "$diff_hours" -gt 25 ]]; then
        echo "           ${RED}WARNING: Last backup is ${diff_hours}h old${NC}"
    fi
    
    return 0
}

# Main
main() {
    echo "=========================================="
    echo "Backup System Status"
    echo "=========================================="
    echo ""
    
    check_github
    check_usb
    check_last_backup
    
    echo ""
    echo "=========================================="
    
    # Quick stats
    if [[ -f "$STATE_FILE" ]]; then
        echo ""
        echo "Details (from $STATE_FILE):"
        jq . "$STATE_FILE" 2>/dev/null || cat "$STATE_FILE"
    fi
}

# Run
main "$@"
