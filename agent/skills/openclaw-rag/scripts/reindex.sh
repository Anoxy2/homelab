#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAG_DIR="/home/steges/infra/openclaw-data/rag"
INDEX_DB="$RAG_DIR/index.db"
SNAPSHOT_DIR="$RAG_DIR/snapshots"
ACTION_LOG="/home/steges/infra/openclaw-data/action-log.jsonl"
LOCK_FILE="$RAG_DIR/.reindex.lock"
STATUS_FILE="$RAG_DIR/.reindex.status"
REINDEX_TIMEOUT_SECONDS="${RAG_REINDEX_TIMEOUT_SECONDS:-600}"
POST_CANARY_TIMEOUT_SECONDS="${RAG_POST_CANARY_TIMEOUT_SECONDS:-120}"

run_with_timeout() {
	local timeout_s="$1"
	shift
	if command -v timeout >/dev/null 2>&1; then
		timeout --signal=TERM --kill-after=5 "${timeout_s}" "$@"
	else
		"$@"
	fi
}

snapshot_index_daily() {
	if [[ ! -f "$INDEX_DB" ]]; then
		return 0
	fi

	mkdir -p "$SNAPSHOT_DIR"
	local stamp
	stamp="$(date +%Y-%m-%d)"
	local target="$SNAPSHOT_DIR/index.db.$stamp"

	if [[ ! -f "$target" ]]; then
		cp "$INDEX_DB" "$target"
	fi

	ls -1t "$SNAPSHOT_DIR"/index.db.* 2>/dev/null | tail -n +8 | xargs -r rm -f
}

write_status() {
	local state="$1"   # running | success | failed
	local detail="${2:-}"
	mkdir -p "$(dirname "$STATUS_FILE")"
	python3 - "$STATUS_FILE" "$state" "$detail" <<'PY'
import json, sys
from datetime import datetime, timezone
path, state, detail = sys.argv[1:]
with open(path, 'w', encoding='utf-8') as f:
    json.dump({'state': state, 'detail': detail,
               'ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}, f)
    f.write('\n')
PY
}

append_action_log() {
	local result="$1"
	local checksum="$2"
	mkdir -p "$(dirname "$ACTION_LOG")"
	[[ -f "$ACTION_LOG" ]] || : > "$ACTION_LOG"

	python3 - "$ACTION_LOG" "$result" "$checksum" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, result, checksum = sys.argv[1:]
row = {
	'ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
	'skill': 'openclaw-rag',
	'action': 'reindex',
	'result': result,
	'triggered_by': 'reindex.sh',
	'index_checksum': checksum,
}

with open(path, 'a', encoding='utf-8') as f:
	f.write(json.dumps(row, ensure_ascii=True) + '\n')
PY
}

latest_snapshot() {
	ls -1t "$SNAPSHOT_DIR"/index.db.* 2>/dev/null | head -n 1 || true
}

index_quick_check() {
	if [[ ! -f "$INDEX_DB" ]]; then
		return 1
	fi
	python3 - "$INDEX_DB" <<'PY'
import sqlite3
import sys

path = sys.argv[1]
try:
    conn = sqlite3.connect(path)
    row = conn.execute("PRAGMA quick_check").fetchone()
    conn.close()
    ok = (row is not None and str(row[0]).lower() == 'ok')
except Exception:
    ok = False
raise SystemExit(0 if ok else 1)
PY
}

restore_latest_snapshot() {
	local snap
	snap="$(latest_snapshot)"
	if [[ -z "$snap" || ! -f "$snap" ]]; then
		return 1
	fi
	cp "$snap" "$INDEX_DB"
	return 0
}

run_post_reindex_canary() {
	local timeout_s="$1"
	local gate_script="$SCRIPT_DIR/rag-canary-smoke.sh"
	[[ -x "$gate_script" ]] || return 10

	local output
	set +e
	output="$(run_with_timeout "$timeout_s" bash "$gate_script" --json 2>&1)"
	local gate_rc=$?
	set -e

	if [[ $gate_rc -eq 124 ]]; then
		echo "timeout"
		return 124
	fi
	if [[ $gate_rc -ne 0 ]]; then
		if echo "$output" | grep -q '"passed"[[:space:]]*:[[:space:]]*false'; then
			echo "failed"
			return 20
		fi
		echo "error"
		return 21
	fi

	if echo "$output" | grep -q '"passed"[[:space:]]*:[[:space:]]*true'; then
		echo "passed"
		return 0
	fi

	echo "error"
	return 21
}

mkdir -p "$RAG_DIR"

# ─── Exclusive lock: verhindert parallele Reindex-Läufe ─────────────────────
exec 9>"$LOCK_FILE"
if ! flock --nonblock 9; then
	echo "reindex.sh: läuft bereits (lock: $LOCK_FILE) – abgebrochen." >&2
	exit 0
fi

write_status "running"
snapshot_index_daily

[[ "$REINDEX_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || REINDEX_TIMEOUT_SECONDS=600

set +e
run_with_timeout "$REINDEX_TIMEOUT_SECONDS" python3 "$SCRIPT_DIR/ingest.py" --changed-only --json "$@"
rc=$?
set -e

checksum="n/a"
if [[ -f "$INDEX_DB" ]]; then
	checksum="$(sha256sum "$INDEX_DB" | awk '{print $1}')"
fi

if [[ $rc -eq 0 ]]; then
	if index_quick_check; then
		set +e
		canary_result="$(run_post_reindex_canary "$POST_CANARY_TIMEOUT_SECONDS")"
		canary_rc=$?
		set -e

		if [[ $canary_rc -eq 0 ]]; then
			append_action_log "success(post_canary_passed)" "$checksum"
			write_status "success" "${checksum}; post_canary_passed"
		else
			detail="post_canary_${canary_result}"
			if restore_latest_snapshot; then
				checksum="$(sha256sum "$INDEX_DB" | awk '{print $1}')"
				detail="${detail}; restored_snapshot"
				append_action_log "failed(${detail})" "$checksum"
				write_status "failed" "$detail"
			else
				detail="${detail}; no_snapshot"
				append_action_log "failed(${detail})" "$checksum"
				write_status "failed" "$detail"
			fi
			rc=1
		fi
	else
		if restore_latest_snapshot; then
			checksum="$(sha256sum "$INDEX_DB" | awk '{print $1}')"
			append_action_log "failed(quick_check_restore)" "$checksum"
			write_status "failed" "quick_check_restore"
			rc=1
		else
			append_action_log "failed(quick_check_no_snapshot)" "$checksum"
			write_status "failed" "quick_check_no_snapshot"
			rc=1
		fi
	fi
else
	detail="rc=$rc"
	if [[ $rc -eq 124 ]]; then
		detail="timeout(${REINDEX_TIMEOUT_SECONDS}s)"
	fi
	if ! index_quick_check; then
		if restore_latest_snapshot; then
			checksum="$(sha256sum "$INDEX_DB" | awk '{print $1}')"
			detail="${detail}; restored_snapshot"
		fi
	fi
	append_action_log "failed(${detail})" "$checksum"
	write_status "failed" "$detail"
fi

exit "$rc"
