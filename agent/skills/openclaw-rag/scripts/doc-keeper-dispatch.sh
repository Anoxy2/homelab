#!/bin/bash

set -euo pipefail

# shellcheck source=/dev/null
source "/home/steges/agent/skills/skill-forge/scripts/common.sh"

REPO_ROOT="${DOC_KEEPER_REPO_ROOT:-/home/steges}"
CHANGELOG_PATH="${DOC_KEEPER_CHANGELOG_PATH:-$REPO_ROOT/CHANGELOG.md}"
DOC_SUMMARY_PATH="${DOC_KEEPER_SUMMARY_PATH:-$REPO_ROOT/docs/operations/doc-keeper-latest.md}"
REVIEW_PATH="${DOC_KEEPER_REVIEW_PATH:-$REPO_ROOT/docs/operations/doc-keeper-changelog-review.md}"
STATE_PATH="${DOC_KEEPER_STATE_PATH:-$STATE_DIR/doc-keeper-state.json}"
AUTO_START="<!-- DOC_KEEPER_AUTO_START -->"
AUTO_END="<!-- DOC_KEEPER_AUTO_END -->"

usage() {
  echo "Usage: doc-keeper-dispatch.sh run [--reason <text>] [--daily] [--summary-only] [--review-changelog]"
}

run_doc_keeper() {
  local reason="$1"
  local mode="$2"
  local changelog_mode="$3"

  python3 - "$REPO_ROOT" "$CHANGELOG_PATH" "$DOC_SUMMARY_PATH" "$REVIEW_PATH" "$STATE_PATH" "$AUTO_START" "$AUTO_END" "$reason" "$mode" "$changelog_mode" <<'PY'
import importlib.util
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

repo_root = Path(sys.argv[1])
changelog_path = Path(sys.argv[2])
summary_path = Path(sys.argv[3])
review_path = Path(sys.argv[4])
state_path = Path(sys.argv[5])
auto_start = sys.argv[6]
auto_end = sys.argv[7]
reason = sys.argv[8]
mode = sys.argv[9]
changelog_mode = sys.argv[10]
helpers_path = Path('/home/steges/agent/skills/skill-forge/scripts/py_helpers.py')

spec = importlib.util.spec_from_file_location('py_helpers', helpers_path)
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)


def run_git(args):
    return subprocess.run(
        ['git', *args],
        cwd=repo_root,
        check=False,
        text=True,
        capture_output=True,
    )


def has_conflict_markers(text: str) -> bool:
    return ('<<<<<<< ' in text) or ('=======\n' in text and '>>>>>>> ' in text)


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def render_block(lines):
    return '\n'.join([auto_start, *lines, auto_end])


def replace_or_append_marker_block(existing: str, block: str) -> str:
    if auto_start in existing and auto_end in existing:
        before = existing.split(auto_start, 1)[0].rstrip()
        after = existing.split(auto_end, 1)[1].lstrip('\n')
        if before and after:
            return before + '\n\n' + block + '\n\n' + after
        if before:
            return before + '\n\n' + block + '\n'
        if after:
            return block + '\n\n' + after
        return block + '\n'
    base = existing.rstrip()
    if base:
        return base + '\n\n' + block + '\n'
    return block + '\n'


def write_marker_file(path: Path, title: str, body_lines):
    ensure_parent(path)
    content = path.read_text(encoding='utf-8') if path.exists() else f'# {title}\n\n'
    if has_conflict_markers(content):
        print(f'CONFLICT: {path.name} contains merge conflict markers', file=sys.stderr)
        raise SystemExit(3)
    if content.count(auto_start) != content.count(auto_end):
        print(f'CONFLICT: doc-keeper marker mismatch in {path.name}', file=sys.stderr)
        raise SystemExit(3)
    block = render_block(body_lines)
    updated = replace_or_append_marker_block(content, block)
    path.write_text(updated, encoding='utf-8')


unmerged = run_git(['ls-files', '-u']).stdout.strip()
if unmerged:
    print('CONFLICT: unmerged git entries detected', file=sys.stderr)
    raise SystemExit(3)

head = run_git(['rev-parse', 'HEAD']).stdout.strip()
if not head:
    print('ERROR: could not determine git HEAD', file=sys.stderr)
    raise SystemExit(2)

state = helpers.read_json_file(state_path, {}) or {}
last_head = str(state.get('last_processed_head', '') or '').strip()

status_lines = [line for line in run_git(['status', '--short']).stdout.strip().splitlines() if line.strip()]
recent_commits = []
delta_files = []
full_scan = False

if last_head and last_head != head:
    rev_range = f'{last_head}..{head}'
    log_rows = run_git(['log', '--date=iso', '--pretty=format:%h|%ad|%s', rev_range]).stdout.strip().splitlines()
    recent_commits = [row for row in log_rows if row.strip()]
    diff_rows = run_git(['diff', '--name-status', last_head, head]).stdout.strip().splitlines()
    delta_files = [row for row in diff_rows if row.strip()]
else:
    full_scan = True
    log_rows = run_git(['log', '-n', '20', '--date=iso', '--pretty=format:%h|%ad|%s']).stdout.strip().splitlines()
    recent_commits = [row for row in log_rows if row.strip()]
    delta_files = status_lines

now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
scan_label = 'full-scan' if full_scan else 'delta'

summary_body = [
    f'Generated: {now}',
    f'Reason: {reason}',
    f'Mode: {mode}',
    f'Scan: {scan_label}',
    f'HEAD: {head}',
]
if last_head:
    summary_body.append(f'Previous HEAD: {last_head}')
summary_body.extend([
    '',
    '## Sources',
    '- git rev-parse HEAD',
    '- git log',
    '- git diff --name-status or git status --short',
    '',
    '## Recent Commits',
])

if recent_commits:
    for row in recent_commits:
        parts = row.split('|', 2)
        if len(parts) == 3:
            summary_body.append(f'- {parts[0]} {parts[2]} ({parts[1]})')
else:
    summary_body.append('- no commits found')

summary_body.extend(['', '## Delta Files' if not full_scan else '## Working Tree', ''])
if delta_files:
    summary_body.extend([f'- {line}' for line in delta_files])
else:
    summary_body.append('- clean')

write_marker_file(summary_path, 'Doc Keeper Latest', summary_body)

if changelog_mode != 'skip':
    changelog_lines = [
        f'Auto-updated: {now}',
        f'Reason: {reason}',
        f'Mode: {mode}',
        f'Changelog Mode: {changelog_mode}',
        f'Scan: {scan_label}',
        'Recent git commits:',
    ]
    if recent_commits:
        for row in recent_commits:
            parts = row.split('|', 2)
            if len(parts) == 3:
                changelog_lines.append(f'- {parts[0]} {parts[2]} ({parts[1]})')
    else:
        changelog_lines.append('- no commits found')

    if changelog_mode == 'review':
        write_marker_file(review_path, 'Doc Keeper Changelog Review', changelog_lines)
    else:
        ensure_parent(changelog_path)
        if not changelog_path.exists():
            changelog_path.write_text('# CHANGELOG\n\n', encoding='utf-8')
        content = changelog_path.read_text(encoding='utf-8')
        if has_conflict_markers(content):
            print('CONFLICT: changelog contains merge conflict markers', file=sys.stderr)
            raise SystemExit(3)
        if content.count(auto_start) != content.count(auto_end):
            print('CONFLICT: doc-keeper marker mismatch in changelog', file=sys.stderr)
            raise SystemExit(3)
        updated = replace_or_append_marker_block(content, render_block(changelog_lines))
        changelog_path.write_text(updated, encoding='utf-8')

lock_path = str(state_path).replace('.json', '.lock')
def _update(data):
    payload = dict(data or {})
    payload['last_processed_head'] = head
    payload['last_run_at'] = now
    payload['last_reason'] = reason
    payload['last_mode'] = mode
    payload['last_scan'] = scan_label
    payload['last_changelog_mode'] = changelog_mode
    if mode == 'daily':
        payload['last_daily_run'] = datetime.now(timezone.utc).strftime('%Y-%m-%d')
    return payload
helpers.locked_json_update(state_path, lock_path, _update, {})

result = {
    'status': 'ok',
    'scan': scan_label,
    'head': head,
    'previous_head': last_head,
    'commit_count': len(recent_commits),
    'delta_file_count': len(delta_files),
    'summary_path': str(summary_path),
    'changelog_mode': changelog_mode,
    'review_path': str(review_path) if changelog_mode == 'review' else '',
}
print(json.dumps(result, ensure_ascii=False))
PY
}

main() {
  ensure_dirs
  init_state_files

  local sub="${1:-}"
  [[ "$sub" == "run" ]] || { usage; exit 1; }
  shift

  local reason="manual"
  local mode="manual"
  local changelog_mode="write"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reason)
        reason="${2:-manual}"
        shift 2
        ;;
      --daily)
        mode="daily"
        shift
        ;;
      --summary-only)
        changelog_mode="skip"
        shift
        ;;
      --review-changelog)
        changelog_mode="review"
        shift
        ;;
      *)
        usage
        exit 1
        ;;
    esac
  done

  set +e
  local result_json
  result_json="$(run_doc_keeper "$reason" "$mode" "$changelog_mode" 2>&1)"
  local run_rc=$?
  set -e
  if [[ $run_rc -ne 0 ]]; then
    log_audit "DOC_KEEPER" "openclaw-rag" "run failed reason=$reason mode=$mode changelog_mode=$changelog_mode rc=$run_rc"
    echo "$result_json" >&2
    echo "Doc-keeper failed (rc=$run_rc)" >&2
    return "$run_rc"
  fi

  local scan commit_count delta_file_count
  scan="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("scan",""))' <<< "$result_json")"
  commit_count="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("commit_count",0))' <<< "$result_json")"
  delta_file_count="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("delta_file_count",0))' <<< "$result_json")"

  log_audit "DOC_KEEPER" "openclaw-rag" "run reason=$reason mode=$mode changelog_mode=$changelog_mode scan=$scan commits=$commit_count delta_files=$delta_file_count"
  echo "Doc-keeper updated: $DOC_SUMMARY_PATH (scan=$scan, commits=$commit_count, delta_files=$delta_file_count, changelog_mode=$changelog_mode)"
}

main "$@"
