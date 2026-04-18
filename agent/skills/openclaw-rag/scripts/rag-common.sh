#!/bin/bash
# rag-common.sh - Gemeinsame Funktionen für RAG-Skripte
# Usage: source "$(dirname "$0")/rag-common.sh"

set -euo pipefail

# Pfade
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${RAG_AUTODOC_REPO_ROOT:-/home/steges}"
DB_PATH="/home/steges/infra/openclaw-data/rag/index.db"
EMBED_HEALTH="http://192.168.2.101:18790/health"
PROJECT_ENV_FILE="/home/steges/.env"
REINDEX_STATUS_FILE="/home/steges/infra/openclaw-data/rag/.reindex.status"

# Logging
log_info() { echo "[INFO] $*" >&2; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# Umgebungsvariablen laden
load_project_env() {
  if [[ -f "$PROJECT_ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$PROJECT_ENV_FILE"
    set +a
  fi
}

# Timeout-Wrapper für Befehle
run_with_timeout() {
  local timeout_s="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout --signal=TERM --kill-after=5 "${timeout_s}" "$@"
  else
    "$@"
  fi
}

# JSON escapen für sichere Ausgabe
json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<< "$1"
}

# Healthcheck für Embed-Service
check_embed_health() {
  local url="${1:-$EMBED_HEALTH}"
  curl -sf "$url" >/dev/null 2>&1
}

# Reindex-Status laden
get_reindex_status() {
  if [[ -f "$REINDEX_STATUS_FILE" ]]; then
    python3 -c "
import json, sys
try:
    with open('$REINDEX_STATUS_FILE', 'r') as f:
        print(json.load(f).get('detail', ''))
except Exception:
    print('')
"
  fi
}

# Datenbank-Pfad zurückgeben
get_db_path() {
  echo "$DB_PATH"
}

# Usage-Hilfe für Subcommands
usage_rag_dispatch() {
  cat <<'EOF'
Usage:
  rag-dispatch.sh retrieve <query> [--limit N] [--timeout-ms N] [--no-hybrid]
  rag-dispatch.sh reindex [--changed-only] [--embed] [--timeout-seconds N]
  rag-dispatch.sh status

Subcommands:
  retrieve   Query the RAG index (hybrid BM25+vector by default)
  reindex    Re-ingest changed files; --embed also refreshes vectors
  status     Show index health, vector coverage, embed service state
EOF
}
