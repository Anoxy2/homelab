#!/bin/bash
# git-status.sh - Detailed git status for GitHub automation

set -euo pipefail

readonly REPO_DIR="${1:-/home/steges}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$REPO_DIR" 2>/dev/null || {
    echo '{"error": "Cannot access repository"}' >&2
    exit 1
}

# Check if git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo '{"error": "Not a git repository"}' >&2
    exit 1
fi

# Gather info
branch=$(git branch --show-current 2>/dev/null || echo "unknown")
ahead=$(git rev-list --count HEAD...@{upstream} 2>/dev/null || echo "0")
behind=$(git rev-list --count @{upstream}...HEAD 2>/dev/null || echo "0")

# Modified files
modified=$(git diff --name-only 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo "[]")

# Staged files  
staged=$(git diff --cached --name-only 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo "[]")

# Untracked files
untracked=$(git ls-files --others --exclude-standard 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo "[]")

# Check if clean
is_clean="false"
if [[ -z "$(git status --porcelain 2>/dev/null)" ]]; then
    is_clean="true"
fi

# Last commit
last_commit=$(git log -1 --format="%H" 2>/dev/null || echo "unknown")
last_commit_short=$(git log -1 --format="%h" 2>/dev/null || echo "unknown")
last_commit_time=$(git log -1 --format="%ci" 2>/dev/null || echo "unknown")
last_commit_msg=$(git log -1 --format="%s" 2>/dev/null | jq -R . || echo '"unknown"')

# Remote
remote_url=$(git remote get-url origin 2>/dev/null || echo "none")

# Output JSON
cat << EOF
{
  "clean": $is_clean,
  "branch": "$branch",
  "ahead": $ahead,
  "behind": $behind,
  "modified": $modified,
  "staged": $staged,
  "untracked": $untracked,
  "last_commit": {
    "hash": "$last_commit",
    "short": "$last_commit_short",
    "time": "$last_commit_time",
    "message": $last_commit_msg
  },
  "remote": "$remote_url"
}
EOF
