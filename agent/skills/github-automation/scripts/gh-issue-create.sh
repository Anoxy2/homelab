#!/bin/bash
# gh-issue-create.sh - Create GitHub issue

set -euo pipefail

readonly REPO_DIR="${REPO_DIR:-/home/steges}"

cd "$REPO_DIR" 2>/dev/null || {
    echo '{"error": "Cannot access repository"}' >&2
    exit 1
}

# Check gh CLI
if ! command -v gh >/dev/null 2>&1; then
    echo '{"error": "gh CLI not installed"}' >&2
    exit 1
fi

# Parse arguments
title=""
body=""
labels=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --title)
            title="$2"
            shift 2
            ;;
        --body)
            body="$2"
            shift 2
            ;;
        --labels)
            labels="$2"
            shift 2
            ;;
        *)
            if [[ -z "$title" ]]; then
                title="$1"
            elif [[ -z "$body" ]]; then
                body="$1"
            fi
            shift
            ;;
    esac
done

if [[ -z "$title" ]]; then
    echo '{"error": "Title required"}' >&2
    exit 1
fi

# Build command
cmd="gh issue create --title \"$title\""
if [[ -n "$body" ]]; then
    cmd="$cmd --body \"$body\""
fi
if [[ -n "$labels" ]]; then
    cmd="$cmd --label \"$labels\""
fi

# Create issue
if output=$(eval "$cmd" 2>&1); then
    # Parse issue URL
    issue_url=$(echo "$output" | grep -o 'https://github.com/[^ ]*/issues/[0-9]*' | head -1)
    issue_number=$(echo "$issue_url" | grep -o '[0-9]*$')
    
    cat << EOF
{
  "success": true,
  "issue_number": ${issue_number:-0},
  "url": "$issue_url"
}
EOF
    exit 0
else
    echo "{\"error\": \"$output\"}" >&2
    exit 1
fi
