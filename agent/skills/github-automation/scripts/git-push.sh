#!/bin/bash
# git-push.sh - Push to remote with checks

set -euo pipefail

readonly REPO_DIR="${REPO_DIR:-/home/steges}"

# Parse arguments
remote="origin"
branch=""
force="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --remote)
            remote="$2"
            shift 2
            ;;
        --branch)
            branch="$2"
            shift 2
            ;;
        --force)
            force="true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--remote origin] [--branch main] [--force]"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

cd "$REPO_DIR" 2>/dev/null || {
    echo '{"error": "Cannot access repository"}' >&2
    exit 1
}

# Get current branch if not specified
if [[ -z "$branch" ]]; then
    branch=$(git branch --show-current)
fi

# Check remote
if ! git remote get-url "$remote" >/dev/null 2>&1; then
    echo "{\"error\": \"Remote '$remote' not found\"}" >&2
    exit 1
fi

# Push
push_args=""
if [[ "$force" == "true" ]]; then
    push_args="--force-with-lease"
fi

if git push "$remote" "$branch" $push_args; then
    remote_url=$(git remote get-url "$remote")
    
    cat << EOF
{
  "success": true,
  "remote": "$remote",
  "branch": "$branch",
  "remote_url": "$remote_url",
  "forced": $force
}
EOF
    exit 0
else
    echo "{\"error\": \"Push failed\"}" >&2
    exit 1
fi
