#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${RAG_AUTODOC_REPO_ROOT:-/home/steges}"
RETRIEVE_PY="$SCRIPT_DIR/retrieve.py"
REINDEX_SH="$SCRIPT_DIR/reindex.sh"
DOC_KEEPER_SH="$SCRIPT_DIR/doc-keeper-dispatch.sh"
DB_PATH="/home/steges/infra/openclaw-data/rag/index.db"
EMBED_HEALTH="http://192.168.2.101:18790/health"
PROJECT_ENV_FILE="/home/steges/.env"
INGEST_PY="$SCRIPT_DIR/ingest.py"
REINDEX_STATUS_FILE="/home/steges/infra/openclaw-data/rag/.reindex.status"

load_project_env() {
  if [[ -f "$PROJECT_ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$PROJECT_ENV_FILE"
    set +a
  fi
}

usage() {
  cat <<'EOF'
Usage:
  rag-dispatch.sh retrieve <query> [--limit N] [--timeout-ms N] [--no-hybrid]
  rag-dispatch.sh reindex [--changed-only] [--embed] [--timeout-seconds N]
  rag-dispatch.sh doc-keeper run [--reason <text>] [--daily] [--summary-only] [--review-changelog] [--autodoc] [--autodoc-dry-run] [--autodoc-profile daily|post-promote|weekly] [--autodoc-provider auto|anthropic|copilot] [--autodoc-model <name>]
  rag-dispatch.sh status

Subcommands:
  retrieve   Query the RAG index (hybrid BM25+vector by default)
  reindex    Re-ingest changed files; --embed also refreshes vectors
  doc-keeper Delta-Scan + marker-safe summary/changelog updates (RAG-owned)
  status     Show index health, vector coverage, embed service state

Note: autodoc has moved to its own skill. Use: ~/scripts/skills autodoc <topic> --output <path>
EOF
}

run_with_timeout() {
  local timeout_s="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout --signal=TERM --kill-after=5 "${timeout_s}" "$@"
  else
    "$@"
  fi
}

retrieve_cmd() {
  local query="${1:-}"
  shift || true
  [[ -n "$query" ]] || { usage; exit 2; }
  local -a forward=()
  local limit=5
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) shift ;;
    --limit)
    limit="${2:-5}"
    forward+=("$1" "$limit")
    shift 2
    ;;
      *) forward+=("$1"); shift ;;
    esac
  done

  local primary_out
  local primary_rc
  set +e
  primary_out="$(python3 "$RETRIEVE_PY" "$query" "${forward[@]}" 2>&1)"
  primary_rc=$?
  set -e
  if [[ $primary_rc -ne 0 ]]; then
  echo "$primary_out" >&2
  return $primary_rc
  fi

  echo "$primary_out"
}

reindex_cmd() {
  local timeout_seconds="${RAG_REINDEX_TIMEOUT_SECONDS:-600}"
  local -a forward=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) shift ;;
      --timeout-seconds) timeout_seconds="${2:-}"; shift 2 ;;
      *) forward+=("$1"); shift ;;
    esac
  done
  [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || { echo "Invalid --timeout-seconds: $timeout_seconds" >&2; exit 2; }
  run_with_timeout "$timeout_seconds" "$REINDEX_SH" "${forward[@]}"
}

# Module laden (Status, Doc-Keeper).
# shellcheck source=/home/steges/agent/skills/openclaw-rag/scripts/modules/status.sh
source "$SCRIPT_DIR/modules/status.sh"
# shellcheck source=/home/steges/agent/skills/openclaw-rag/scripts/modules/doc_keeper.sh
source "$SCRIPT_DIR/modules/doc_keeper.sh"

main() {
  load_project_env
  local sub="${1:-}"
  case "$sub" in
    retrieve) shift; retrieve_cmd "$@" ;;
    reindex)  shift; reindex_cmd "$@" ;;
    doc-keeper) shift; doc_keeper_cmd "$@" ;;
    status)   shift; status_cmd "$@" ;;
    autodoc)
      echo "autodoc has moved to its own skill. Use: ~/scripts/skills autodoc ${*:2}" >&2
      exit 2
      ;;
    ""|--help|-h|help) usage ;;
    *) usage; exit 2 ;;
  esac
}

main "$@"
