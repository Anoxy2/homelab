#!/bin/bash
# git-commit.sh - Create commit with validation

set -euo pipefail

readonly REPO_DIR="${REPO_DIR:-/home/steges}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
message=""
files="-A"
signoff="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--message)
            message="$2"
            shift 2
            ;;
        --files)
            files="$2"
            shift 2
            ;;
        --signoff)
            signoff="true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 -m 'message' [--files 'file1 file2'] [--signoff]"
            exit 0
            ;;
        *)
            if [[ -z "$message" ]]; then
                message="$1"
            fi
            shift
            ;;
    esac
done

# Validate
cd "$REPO_DIR" 2>/dev/null || {
    echo '{"error": "Cannot access repository"}' >&2
    exit 1
}

if [[ -z "$message" ]]; then
    echo '{"error": "Commit message required (-m)"}' >&2
    exit 1
fi

# Stage files
echo "Staging: $files" >&2
git add $files

# Get staged count
staged_count=$(git diff --cached --name-only 2>/dev/null | wc -l)
if [[ "$staged_count" -eq 0 ]]; then
    echo '{"error": "No changes to commit"}' >&2
    exit 1
fi

# Commit
commit_success=false
if [[ "$signoff" == "true" ]]; then
    if git commit -m "$message" --signoff; then
        commit_success=true
    fi
else
    if git commit -m "$message"; then
        commit_success=true
    fi
fi

if [[ "$commit_success" == "true" ]]; then
    commit_hash=$(git rev-parse HEAD)
    short_hash=$(git rev-parse --short HEAD)
    
    cat << EOF
{
  "success": true,
  "commit_hash": "$commit_hash",
  "short_hash": "$short_hash",
  "files_changed": $staged_count,
  "message": "$message"
}
EOF
    exit 0
else
    echo '{"error": "Commit failed"}' >&2
    exit 1
fi
