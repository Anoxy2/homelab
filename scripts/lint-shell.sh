#!/bin/bash
set -euo pipefail

ROOT_DIR="/home/steges"
PROFILE="$ROOT_DIR/.shellcheckrc"

usage() {
  cat <<'EOF'
Usage:
  lint-shell.sh --changed
  lint-shell.sh <path> [<path> ...]

Behavior:
  - --changed: lints changed shell scripts from git status.
  - explicit paths: lints the given files.
  - if local shellcheck is unavailable, uses docker image koalaman/shellcheck-alpine.
EOF
}

is_shell_candidate() {
  local path="$1"
  [[ -f "$path" ]] || return 1

  case "$path" in
    *.sh|scripts/*|agent/skills/*/scripts/*)
      return 0
      ;;
  esac

  local first
  first="$(head -n 1 "$path" 2>/dev/null || true)"
  [[ "$first" =~ ^\#\!.*(bash|sh)$ ]]
}

collect_changed_candidates() {
  local rel
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    if is_shell_candidate "$ROOT_DIR/$rel"; then
      echo "$rel"
    fi
  done < <(git -C "$ROOT_DIR" status --porcelain | sed -E 's/^.. //')
}

run_shellcheck_local() {
  local files=("$@")
  shellcheck -x --norc --rcfile "$PROFILE" "${files[@]}"
}

run_shellcheck_docker() {
  local files=("$@")
  command -v docker >/dev/null 2>&1 || {
    echo "ERROR: shellcheck not installed and docker not available for fallback." >&2
    exit 2
  }

  local docker_files=()
  local f
  for f in "${files[@]}"; do
    docker_files+=("/work/$f")
  done

  docker run --rm \
    -v "$ROOT_DIR:$ROOT_DIR:ro" \
    -v "$ROOT_DIR:/work:ro" \
    -w /work \
    koalaman/shellcheck-alpine:stable \
    shellcheck -x --norc --rcfile /work/.shellcheckrc "${docker_files[@]}"
}

main() {
  local -a targets=()

  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  if [[ "$1" == "--changed" ]]; then
    mapfile -t targets < <(collect_changed_candidates | sort -u)
  else
    local arg
    for arg in "$@"; do
      if [[ "$arg" = /* ]]; then
        arg="${arg#"${ROOT_DIR}"/}"
      fi
      if is_shell_candidate "$ROOT_DIR/$arg"; then
        targets+=("$arg")
      fi
    done
    mapfile -t targets < <(printf '%s\n' "${targets[@]}" | awk 'NF' | sort -u)
  fi

  if [[ ${#targets[@]} -eq 0 ]]; then
    echo "No changed shell files to lint."
    exit 0
  fi

  echo "Linting shell files (${#targets[@]}):"
  printf ' - %s\n' "${targets[@]}"

  if command -v shellcheck >/dev/null 2>&1; then
    run_shellcheck_local "${targets[@]}"
  else
    run_shellcheck_docker "${targets[@]}"
  fi

  echo "Shell lint OK"
}

main "$@"
