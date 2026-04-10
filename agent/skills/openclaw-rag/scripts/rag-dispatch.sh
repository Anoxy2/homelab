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
  rag-dispatch.sh autodoc <topic> --output <path> [--force] [--dry-run] [--provider auto|anthropic|copilot] [--model <name>] [--no-reindex]

Subcommands:
  retrieve   Query the RAG index (hybrid BM25+vector by default)
  reindex    Re-ingest changed files; --embed also refreshes vectors
  doc-keeper Delta-Scan + marker-safe summary/changelog updates (RAG-owned)
  status     Show index health, vector coverage, embed service state
  autodoc    Synthesize a document from RAG context (Anthropic or Copilot/OpenAI-compatible)
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

refresh_autodoc_index() {
  local reindex_out reindex_rc
  local reindex_detail=""
  set +e
  reindex_out="$($REINDEX_SH --changed-only 2>&1)"
  reindex_rc=$?
  set -e

  if [[ -f "$REINDEX_STATUS_FILE" ]]; then
    reindex_detail="$(python3 - <<'PY' "$REINDEX_STATUS_FILE"
import json, sys
try:
    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        print(json.load(f).get('detail', ''))
except Exception:
    print('')
PY
)"
  fi

  if [[ $reindex_rc -eq 0 ]]; then
    printf '{"attempted":true,"mode":"reindex.sh","rc":0,"detail":%s,"stdout":%s}\n' "$(python3 - <<'PY' "$reindex_detail"
import json, sys
print(json.dumps(sys.argv[1][:800]))
PY
)" "$(python3 - <<'PY' "$reindex_out"
import json, sys
print(json.dumps(sys.argv[1][:800]))
PY
)"
    return 0
  fi

  if [[ "$reindex_detail" == *"post_canary_failed"* || "$reindex_detail" == *"restored_snapshot"* ]]; then
    local ingest_out ingest_rc
    set +e
    ingest_out="$(python3 "$INGEST_PY" --changed-only --json 2>&1)"
    ingest_rc=$?
    set -e
    if [[ $ingest_rc -eq 0 ]]; then
      printf '{"attempted":true,"mode":"ingest-fallback","rc":0,"reindex_rc":%s,"detail":%s,"reindex_stdout":%s,"stdout":%s}\n' \
        "$reindex_rc" \
        "$(python3 - <<'PY' "$reindex_detail"
import json, sys
print(json.dumps(sys.argv[1][:800]))
PY
)" \
        "$(python3 - <<'PY' "$reindex_out"
import json, sys
print(json.dumps(sys.argv[1][:800]))
PY
)" \
        "$(python3 - <<'PY' "$ingest_out"
import json, sys
print(json.dumps(sys.argv[1][:800]))
PY
)"
      return 0
    fi
  fi

  printf '{"attempted":true,"mode":"reindex.sh","rc":%s,"detail":%s,"stdout":%s}\n' \
    "$reindex_rc" \
    "$(python3 - <<'PY' "$reindex_detail"
import json, sys
print(json.dumps(sys.argv[1][:800]))
PY
)" \
    "$(python3 - <<'PY' "$reindex_out"
import json, sys
print(json.dumps(sys.argv[1][:800]))
PY
)"
  return 1
}

# ─── retrieve ─────────────────────────────────────────────────────────────────
retrieve_cmd() {
  local query="${1:-}"
  shift || true
  [[ -n "$query" ]] || { usage; exit 2; }
  local -a forward=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) shift ;;  # retrieve.py always emits JSON
      *) forward+=("$1"); shift ;;
    esac
  done
  exec python3 "$RETRIEVE_PY" "$query" "${forward[@]}"
}

# ─── reindex ──────────────────────────────────────────────────────────────────
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

# ─── status ───────────────────────────────────────────────────────────────────
status_cmd() {
  python3 - "$DB_PATH" "$EMBED_HEALTH" <<'PY'
import json, sqlite3, sys, urllib.request, struct
from datetime import datetime, timezone
from pathlib import Path

db_path = Path(sys.argv[1])
embed_health_url = sys.argv[2]

result = {
    "db_exists": False,
    "db_size_kb": 0,
    "sources": 0,
    "chunks_total": 0,
    "chunks_with_vectors": 0,
    "vector_coverage_pct": 0.0,
    "index_age_hours": None,
    "last_ingest_at": None,
    "last_embed_backfill_at": None,
    "embed_service": "unknown",
    "snapshots": 0,
    "warnings": [],
}

# Embed service health
try:
    with urllib.request.urlopen(embed_health_url, timeout=3) as r:
        h = json.loads(r.read())
        result["embed_service"] = "healthy" if h.get("status") == "ok" else "degraded"
except Exception:
    result["embed_service"] = "unreachable"

if not db_path.exists():
    result["warnings"].append("index.db does not exist — run reindex first")
    print(json.dumps(result, indent=2))
    sys.exit(0)

result["db_exists"] = True
result["db_size_kb"] = round(db_path.stat().st_size / 1024)

snapshot_dir = db_path.parent / "snapshots"
if snapshot_dir.exists():
    result["snapshots"] = len(list(snapshot_dir.glob("index.db.*")))

try:
    # Try sqlite-vec for vector stats
    vec_available = False
    conn = sqlite3.connect(str(db_path))
    try:
        import sqlite_vec
        conn.enable_load_extension(True)
        sqlite_vec.load(conn)
        conn.enable_load_extension(False)
        vec_available = True
    except Exception:
        pass

    result["sources"] = conn.execute("SELECT COUNT(DISTINCT source) FROM chunks").fetchone()[0]
    result["chunks_total"] = conn.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]

    if vec_available:
        try:
            result["chunks_with_vectors"] = conn.execute("SELECT COUNT(*) FROM chunk_vectors").fetchone()[0]
        except Exception:
            result["chunks_with_vectors"] = 0
    else:
        result["chunks_with_vectors"] = 0
        result["warnings"].append("sqlite-vec not available — vector stats unavailable")

    total = result["chunks_total"]
    vecs = result["chunks_with_vectors"]
    result["vector_coverage_pct"] = round(vecs / total * 100, 1) if total else 0.0

    meta = dict(conn.execute("SELECT key, value FROM index_meta").fetchall())
    result["last_ingest_at"] = meta.get("last_ingest_at")
    result["last_embed_backfill_at"] = meta.get("last_embed_backfill_at")

    if result["last_ingest_at"]:
        ts = result["last_ingest_at"].replace("Z", "+00:00")
        try:
            last = datetime.fromisoformat(ts).replace(tzinfo=timezone.utc)
            age = (datetime.now(timezone.utc) - last).total_seconds() / 3600.0
            result["index_age_hours"] = round(age, 1)
            if age > 24:
                result["warnings"].append(f"index stale: {age:.0f}h since last ingest")
        except Exception:
            pass

    conn.close()

    if result["vector_coverage_pct"] < 95:
        result["warnings"].append(
            f"vector coverage low: {result['vector_coverage_pct']}% "
            f"({result['chunks_with_vectors']}/{result['chunks_total']}) — run: ingest.py --embed-backfill"
        )

except Exception as e:
    result["warnings"].append(f"db-error: {e}")

print(json.dumps(result, indent=2))
PY
}

# ─── autodoc ──────────────────────────────────────────────────────────────────
autodoc_cmd() {
  local topic="${1:-}"
  shift || true
  [[ -n "$topic" ]] || { echo "Usage: rag-dispatch.sh autodoc <topic> --output <path>" >&2; exit 2; }

  local output_path=""
  local force=0
  local dry_run=0
  local limit=10
  local provider="auto"
  local model_override=""
  local no_reindex=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output) output_path="$2"; shift 2 ;;
      --force)  force=1; shift ;;
      --dry-run) dry_run=1; shift ;;
      --limit)  limit="$2"; shift 2 ;;
      --provider) provider="$2"; shift 2 ;;
      --model) model_override="$2"; shift 2 ;;
      --no-reindex) no_reindex=1; shift ;;
      *) shift ;;
    esac
  done

  [[ -n "$output_path" ]] || { echo "autodoc requires --output <path>" >&2; exit 2; }

  local autodoc_out
  local adoc_rc
  set +e
  autodoc_out="$(python3 - "$RETRIEVE_PY" "$topic" "$output_path" "$force" "$dry_run" "$limit" "$provider" "$model_override" "$no_reindex" <<'PY'
import json, os, subprocess, sys, urllib.request, urllib.error
import socket
import time
from datetime import datetime, timezone
from pathlib import Path

retrieve_py, topic, output_path, force_s, dry_run_s, limit_s, provider, model_override, no_reindex_s = sys.argv[1:]
force = force_s == "1"
dry_run = dry_run_s == "1"
limit = int(limit_s)
no_reindex = no_reindex_s == "1"
output = Path(output_path)

ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")
COPILOT_API_KEY = (
  os.environ.get("COPILOT_API_KEY", "")
  or os.environ.get("OPENAI_API_KEY", "")
  or os.environ.get("GITHUB_TOKEN", "")
)
COPILOT_BASE_URL = os.environ.get("RAG_AUTODOC_COPILOT_BASE_URL", "https://models.inference.ai.azure.com").rstrip("/")
COPILOT_MODEL = model_override or os.environ.get("RAG_AUTODOC_COPILOT_MODEL", "gpt-4.1")
COPILOT_MAX_TOKENS = int(os.environ.get("RAG_AUTODOC_COPILOT_MAX_TOKENS", "1024"))
API_TIMEOUT_SECONDS = int(os.environ.get("RAG_AUTODOC_API_TIMEOUT_SECONDS", "120"))
API_RETRIES = max(1, int(os.environ.get("RAG_AUTODOC_API_RETRIES", "2")))
MARKER_START = "<!-- DOC_KEEPER_AUTO_START -->"
MARKER_END   = "<!-- DOC_KEEPER_AUTO_END -->"

def render_marker_block(body: str) -> str:
  return (
    f"{MARKER_START}\n"
    f"<!-- Generated by: rag-dispatch.sh autodoc | topic: {topic} | {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%MZ')} -->\n\n"
    f"{body.strip()}\n\n"
    f"{MARKER_END}\n"
  )


def merge_autodoc(existing: str, block: str) -> tuple[str, str]:
  has_start = MARKER_START in existing
  has_end = MARKER_END in existing
  if has_start and has_end:
    before = existing.split(MARKER_START, 1)[0].rstrip()
    after = existing.split(MARKER_END, 1)[1].lstrip("\n")
    if before and after:
      return before + "\n\n" + block + "\n\n" + after, "replace-marker-block"
    if before:
      return before + "\n\n" + block + "\n", "replace-marker-block"
    if after:
      return block + "\n\n" + after, "replace-marker-block"
    return block + "\n", "replace-marker-block"

  if has_start != has_end:
    raise ValueError("marker mismatch in existing file")

  base = existing.rstrip()
  if base:
    return base + "\n\n" + block + "\n", "append-marker-block"
  return block + "\n", "write-marker-block"

# RAG retrieval
proc = subprocess.run(
    ["python3", str(retrieve_py), topic, "--limit", str(limit), "--no-hybrid"],
    capture_output=True, text=True, check=False,
)
payload = {}
if proc.returncode == 0 and proc.stdout.strip():
    try:
        payload = json.loads(proc.stdout)
    except Exception:
        pass

results = payload.get("results", [])
if not results:
    print(json.dumps({"ok": False, "error": "no RAG results for topic", "topic": topic}))
    sys.exit(1)

filtered_results = []
stale_sources = []
for r in results:
  src_path = Path(r.get("source", ""))
  if src_path.exists():
    filtered_results.append(r)
  else:
    stale_sources.append(str(src_path))

if not filtered_results:
  print(json.dumps({
    "ok": False,
    "error": "only stale RAG sources found for topic",
    "topic": topic,
    "stale_sources": stale_sources,
  }))
  sys.exit(1)

# Build context from top chunks
context_parts = []
for r in filtered_results:
    src = r["source"].replace("/home/steges/", "")
    context_parts.append(f"[Quelle: {src}]\n{r['text']}")
context = "\n\n---\n\n".join(context_parts)

def build_dryrun_preview() -> str:
  lines = [
    f"## Auto-Doc Preview: {topic}",
    "",
    "Dry-Run ohne API-Call. Inhalt basiert direkt auf den Top-RAG-Treffern.",
    "",
    "### Kernpunkte aus Retrieval",
  ]
  for idx, r in enumerate(filtered_results[:5], start=1):
    src = r["source"].replace("/home/steges/", "")
    snippet = " ".join(str(r.get("text", "")).split())[:220]
    lines.append(f"{idx}. ({src}) {snippet}")
  lines.append("")
  lines.append(f"Generiert: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}")
  return "\n".join(lines)

system_prompt = (
    "Du bist OpenClaw, ein KI-Assistent der auf einem Raspberry Pi 5 Homelab läuft. "
    "Dein Betreiber ist steges (Tobias). "
    "Schreibe präzise, sachliche Markdown-Dokumente auf Basis der angegebenen Quellen. "
    "Keine Erfindungen. Wenn Informationen fehlen: 'Keine Daten vorhanden' schreiben."
)
user_prompt = (
    f"Erstelle eine aktuelle Zusammenfassung zum Thema: **{topic}**\n\n"
    f"Verwende ausschließlich folgende Quellen:\n\n{context}\n\n"
    f"Format: Markdown. Kompakt und sachlich. "
    f"Hinweis am Ende: generiert von OpenClaw autodoc, {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}"
)

use_api_in_dry_run = os.environ.get("RAG_AUTODOC_DRYRUN_USE_API", "0") == "1"

provider = (provider or "auto").strip().lower()
provider_aliases = {
  "auto": "auto",
  "anthropic": "anthropic",
  "claude": "anthropic",
  "copilot": "copilot",
  "copilot-gpt-4.1": "copilot",
  "gpt-4.1": "copilot",
  "openai": "copilot",
}
if provider not in provider_aliases:
  print(json.dumps({"ok": False, "error": f"invalid provider: {provider}"}))
  sys.exit(2)
provider = provider_aliases[provider]

def resolve_provider() -> str:
  if provider != "auto":
    return provider
  if ANTHROPIC_API_KEY:
    return "anthropic"
  if COPILOT_API_KEY:
    return "copilot"
  return "none"

def call_anthropic() -> tuple[str, str]:
  if not ANTHROPIC_API_KEY:
    raise RuntimeError("ANTHROPIC_API_KEY not set")

  api_payload = json.dumps({
    "model": "claude-haiku-4-5-20251001",
    "max_tokens": 2048,
    "system": system_prompt,
    "messages": [{"role": "user", "content": user_prompt}],
  }).encode()

  req = urllib.request.Request(
    "https://api.anthropic.com/v1/messages",
    data=api_payload,
    headers={
      "Content-Type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
    },
    method="POST",
  )
  last_error = None
  for attempt in range(1, API_RETRIES + 1):
    try:
      with urllib.request.urlopen(req, timeout=API_TIMEOUT_SECONDS) as resp:
        api_resp = json.loads(resp.read())
      return api_resp["content"][0]["text"], "anthropic-api"
    except (TimeoutError, socket.timeout, urllib.error.URLError) as e:
      last_error = e
      if attempt < API_RETRIES:
        time.sleep(2 * attempt)
        continue
      raise RuntimeError(f"anthropic request timed out/failed after {API_RETRIES} attempts: {e}")
    except Exception as e:
      last_error = e
      break
  raise RuntimeError(str(last_error) if last_error else "anthropic request failed")

def call_copilot_openai_compatible() -> tuple[str, str]:
  if not COPILOT_API_KEY:
    raise RuntimeError("COPILOT_API_KEY/OPENAI_API_KEY/GITHUB_TOKEN not set")

  payload = json.dumps({
    "model": COPILOT_MODEL,
    "messages": [
      {"role": "system", "content": system_prompt},
      {"role": "user", "content": user_prompt},
    ],
    "temperature": 0.2,
    "max_tokens": COPILOT_MAX_TOKENS,
  }).encode()

  req = urllib.request.Request(
    f"{COPILOT_BASE_URL}/chat/completions",
    data=payload,
    headers={
      "Content-Type": "application/json",
      "Authorization": f"Bearer {COPILOT_API_KEY}",
    },
    method="POST",
  )
  last_error = None
  for attempt in range(1, API_RETRIES + 1):
    try:
      with urllib.request.urlopen(req, timeout=API_TIMEOUT_SECONDS) as resp:
        data = json.loads(resp.read())
      content = data.get("choices", [{}])[0].get("message", {}).get("content", "")
      if not content:
        raise RuntimeError("empty response from copilot/openai-compatible endpoint")
      return content, f"copilot-openai-compatible:{COPILOT_MODEL}"
    except (TimeoutError, socket.timeout, urllib.error.URLError) as e:
      last_error = e
      if attempt < API_RETRIES:
        time.sleep(2 * attempt)
        continue
      raise RuntimeError(f"copilot request timed out/failed after {API_RETRIES} attempts: {e}")
    except Exception as e:
      last_error = e
      break

  raise RuntimeError(str(last_error) if last_error else "copilot request failed")

if dry_run and not use_api_in_dry_run:
  generated = build_dryrun_preview()
  generation_mode = "dry-run-local-preview"
else:
  chosen = resolve_provider()
  if chosen == "none":
    print(json.dumps({
      "ok": False,
      "error": "no API credentials set (need ANTHROPIC_API_KEY or COPILOT_API_KEY/OPENAI_API_KEY/GITHUB_TOKEN)",
    }))
    sys.exit(1)

  try:
    if chosen == "anthropic":
      generated, generation_mode = call_anthropic()
    else:
      generated, generation_mode = call_copilot_openai_compatible()
  except Exception as e:
    print(json.dumps({"ok": False, "error": f"api-error: {e}"}))
    sys.exit(1)

block = render_marker_block(generated)
write_mode = "write-marker-block"
if output.exists():
  existing = output.read_text(encoding="utf-8")
  if force:
    final_content = block
    write_mode = "force-overwrite"
  else:
    try:
      final_content, write_mode = merge_autodoc(existing, block)
    except ValueError as e:
      print(json.dumps({"ok": False, "error": str(e), "output": str(output)}))
      sys.exit(1)
else:
  final_content = block

if dry_run:
    print(json.dumps({
        "ok": True, "dry_run": True, "topic": topic,
        "output": str(output), "preview": generated[:500],
        "generation_mode": generation_mode,
      "write_mode": write_mode,
        "rag_sources": [r["source"].replace("/home/steges/", "") for r in filtered_results],
        "stale_sources_dropped": stale_sources,
    }))
    sys.exit(0)

output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(final_content, encoding="utf-8")

reindex_result = {"attempted": not no_reindex}

print(json.dumps({
    "ok": True, "topic": topic, "output": str(output),
  "generation_mode": generation_mode,
  "write_mode": write_mode,
    "chars": len(final_content),
  "rag_sources": [r["source"].replace("/home/steges/", "") for r in filtered_results],
  "stale_sources_dropped": stale_sources,
  "reindex": reindex_result,
}))
PY
)"
  adoc_rc=$?
  set -e
  if [[ $adoc_rc -ne 0 ]]; then
    echo "$autodoc_out" >&2
    return $adoc_rc
  fi

  if [[ "$dry_run" == "1" || "$no_reindex" == "1" ]]; then
    echo "$autodoc_out"
    return 0
  fi

  local index_refresh_out
  if ! index_refresh_out="$(refresh_autodoc_index)"; then
    python3 - <<'PY' "$autodoc_out" "$index_refresh_out"
import json, sys

payload = json.loads(sys.argv[1])
payload["ok"] = False
payload["error"] = "autodoc index refresh failed"
payload["reindex"] = json.loads(sys.argv[2])
print(json.dumps(payload))
PY
    return 1
  fi

  python3 - <<'PY' "$autodoc_out" "$index_refresh_out"
import json, sys

payload = json.loads(sys.argv[1])
payload["reindex"] = json.loads(sys.argv[2])
print(json.dumps(payload))
PY
}

# ─── doc-keeper + autodoc batch ───────────────────────────────────────────────
run_autodoc_profile() {
  local profile="$1"
  local dry_run="$2"
  local provider="${3:-auto}"
  local model="${4:-}"
  local -a specs=()

  case "$profile" in
    daily)
      specs=(
        "system-state|$REPO_ROOT/agent/SYSTEM-STATE.md"
        "growbox-summary|$REPO_ROOT/growbox/GROW-SUMMARY.md"
        "open-work-todo|$REPO_ROOT/agent/TO-DO.md"
      )
      ;;
    post-promote)
      specs=(
        "skill-inventar|$REPO_ROOT/agent/SKILL-INVENTORY.md"
      )
      ;;
    weekly)
      specs=(
        "self-model|$REPO_ROOT/agent/SELF-MODEL.md"
        "operative-history|$REPO_ROOT/agent/HISTORY.md"
      )
      ;;
    *)
      echo "Invalid --autodoc-profile: $profile" >&2
      return 2
      ;;
  esac

  local failures=0
  local successes=0
  local spec topic output
  for spec in "${specs[@]}"; do
    topic="${spec%%|*}"
    output="${spec#*|}"

    local -a cmd=("$0" autodoc "$topic" --output "$output" --no-reindex)
    if [[ "$dry_run" == "1" ]]; then
      cmd+=(--dry-run)
    fi
    cmd+=(--provider "$provider")
    if [[ -n "$model" ]]; then
      cmd+=(--model "$model")
    fi

    set +e
    local out
    out="$("${cmd[@]}" 2>&1)"
    local rc=$?
    set -e

    if [[ $rc -ne 0 ]]; then
      failures=$((failures + 1))
      echo "autodoc[$topic] failed: $out" >&2
    else
      successes=$((successes + 1))
      echo "$out"
    fi
  done

  if [[ "$dry_run" != "1" && $failures -eq 0 && $successes -gt 0 ]]; then
    local index_refresh_out
    if ! index_refresh_out="$(refresh_autodoc_index)"; then
      echo "autodoc index refresh failed: $index_refresh_out" >&2
      return 1
    fi
    echo "$index_refresh_out"
  fi

  [[ $failures -eq 0 ]]
}

doc_keeper_cmd() {
  local sub="${1:-run}"
  [[ "$sub" == "run" ]] || { echo "Usage: rag-dispatch.sh doc-keeper run [...]" >&2; exit 2; }
  shift || true

  local enable_autodoc=0
  local autodoc_dry_run=0
  local autodoc_profile=""
  local autodoc_provider="auto"
  local autodoc_model=""
  local is_daily=0
  local -a forward=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --autodoc)
        enable_autodoc=1
        shift
        ;;
      --autodoc-dry-run)
        enable_autodoc=1
        autodoc_dry_run=1
        shift
        ;;
      --autodoc-profile)
        autodoc_profile="${2:-}"
        shift 2
        ;;
      --autodoc-provider)
        autodoc_provider="${2:-auto}"
        shift 2
        ;;
      --autodoc-model)
        autodoc_model="${2:-}"
        shift 2
        ;;
      --daily)
        is_daily=1
        forward+=("$1")
        shift
        ;;
      *)
        forward+=("$1")
        shift
        ;;
    esac
  done

  "$DOC_KEEPER_SH" run "${forward[@]}"

  if [[ "$enable_autodoc" == "0" ]]; then
    return 0
  fi

  if [[ -z "$autodoc_profile" ]]; then
    if [[ "$is_daily" == "1" ]]; then
      autodoc_profile="daily"
    else
      autodoc_profile="post-promote"
    fi
  fi

  if ! run_autodoc_profile "$autodoc_profile" "$autodoc_dry_run" "$autodoc_provider" "$autodoc_model"; then
    echo "WARN: autodoc profile '$autodoc_profile' had failures; doc-keeper result stays successful" >&2
  fi
}

# ─── main ─────────────────────────────────────────────────────────────────────
main() {
  load_project_env
  local sub="${1:-}"
  case "$sub" in
    retrieve) shift; retrieve_cmd "$@" ;;
    reindex)  shift; reindex_cmd "$@" ;;
    doc-keeper) shift; doc_keeper_cmd "$@" ;;
    status)   shift; status_cmd "$@" ;;
    autodoc)  shift; autodoc_cmd "$@" ;;
    ""|--help|-h|help) usage ;;
    *) usage; exit 2 ;;
  esac
}

main "$@"
