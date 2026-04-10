#!/bin/bash
# backup-github.sh - GitHub backup operations
# Handles git status check, commit, and push

set -euo pipefail

readonly REPO_DIR="/home/steges"
readonly LOG_FILE="/var/log/backup-automation.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [github] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

# Check if we're in a git repo
check_git_repo() {
    if ! cd "$REPO_DIR"; then
        error "Cannot access $REPO_DIR"
        return 1
    fi
    
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        error "Not a git repository: $REPO_DIR"
        return 1
    fi
    
    return 0
}

# Get git status as JSON
get_status() {
    cd "$REPO_DIR"
    
    local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local ahead=$(git rev-list --count HEAD...@{upstream} 2>/dev/null || echo "0")
    local modified=$(git diff --name-only 2>/dev/null | jq -R . | jq -s .)
    local untracked=$(git ls-files --others --exclude-standard 2>/dev/null | jq -R . | jq -s .)
    local is_clean=$(git diff --quiet && git diff --cached --quiet && echo "true" || echo "false")
    
    cat << EOF
{
  "branch": "$branch",
  "ahead": $ahead,
  "clean": $is_clean,
  "modified": $modified,
  "untracked": $untracked
}
EOF
}

# Check if there are changes worth committing
has_changes() {
    cd "$REPO_DIR"
    
    # Check modified files
    if ! git diff --quiet 2>/dev/null; then
        return 0
    fi
    
    # Check staged files
    if ! git diff --cached --quiet 2>/dev/null; then
        return 0
    fi
    
    # Check untracked files (excluding ignored)
    if git ls-files --others --exclude-standard | grep -q .; then
        return 0
    fi
    
    return 1
}

# Stage all changes
stage_all() {
    cd "$REPO_DIR"
    
    log "Staging changes..."
    git add -A
    
    # Show what's staged
    local staged=$(git diff --cached --name-only | wc -l)
    log "Files staged: $staged"
    
    return 0
}

# Commit with message
commit() {
    local message="$1"
    
    cd "$REPO_DIR"
    
    log "Committing: $message"
    
    if git commit -m "$message"; then
        local hash=$(git rev-parse --short HEAD)
        log "Committed: $hash"
        return 0
    else
        error "Commit failed"
        return 1
    fi
}

# Push to origin
push() {
    cd "$REPO_DIR"
    
    log "Pushing to origin..."
    
    # Check if we have remote
    if ! git remote get-url origin >/dev/null 2>&1; then
        error "No remote 'origin' configured"
        return 1
    fi
    
    # Try push
    if git push origin "$(git branch --show-current)"; then
        log "Push successful"
        return 0
    else
        error "Push failed"
        return 1
    fi
}

# Main backup flow
main() {
    local message="${1:-"backup: automated $(date +%Y%m%d_%H%M%S)"}"
    
    log "=== GitHub Backup Started ==="
    
    # Pre-checks
    if ! check_git_repo; then
        return 1
    fi
    
    # Check if there are changes
    if ! has_changes; then
        log "No changes to commit"
        
        # Check if we're ahead of remote
        cd "$REPO_DIR"
        local ahead=$(git rev-list --count HEAD...@{upstream} 2>/dev/null || echo "0")
        
        if [[ "$ahead" -gt 0 ]]; then
            log "$ahead commits ahead of remote, pushing..."
            push
            return $?
        fi
        
        log "Repository is clean and up-to-date"
        return 0
    fi
    
    # Stage
    stage_all
    
    # Commit
    if ! commit "$message"; then
        return 1
    fi
    
    # Push
    if ! push; then
        return 1
    fi
    
    log "=== GitHub Backup Completed ==="
    return 0
}

# Run
main "$@"
