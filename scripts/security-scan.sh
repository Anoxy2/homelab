#!/bin/bash
# security-scan.sh – Verbotene Patterns in Shell-Scripts prüfen (Security Baseline P1)
# Usage:
#   security-scan.sh --changed        # Nur git-geänderte Dateien
#   security-scan.sh <path> [...]     # Explizite Dateien/Verzeichnisse
#   security-scan.sh --all            # Alles unter scripts/ und agent/skills/

set -euo pipefail

ROOT_DIR="${SECURITY_SCAN_ROOT:-/home/steges}"
EXIT_OK=0
EXIT_VIOLATIONS=1
EXIT_USAGE=2

# ── Verbotene Patterns ────────────────────────────────────────────────────────
# Format: BESCHREIBUNG|GREP_PATTERN|EXCLUDE_PATTERN (grep -E; leer = kein Ausschluss)
declare -a FORBIDDEN_PATTERNS=(
  "Curl-pipe-to-shell (RCE)|curl\s+[^|#]*\|\s*(ba)?sh|"
  "Wget-pipe-to-shell (RCE)|wget\s+[^|#]*\|\s*(ba)?sh|"
  "eval mit Variablen-Expansion|(^|[;&|])\s*eval\s+\$|"
  "rm -rf auf Systempfad|rm\s+-[a-zA-Z]*rf\s+/|/tmp|/home|/var/tmp|[\"']rm|eval\("
  "Hardcoded sk-Anthropic-Key|(ANTHROPIC|CLAUDE)_?API_?KEY\s*=\s*['\"]sk-ant|"
  "Hardcoded Bearer-Token|Authorization:\s*Bearer\s+[A-Za-z0-9+/]{20,}|"
  "chmod world-writable|chmod\s+[0-9]*[2367][0-9][2367]\b|"
  "Hardcoded Passwort-Literal|(password|passwd|secret)\s*=\s*['\"][^'\"{\$][^'\"]{3,}['\"]|test|example|changeme|placeholder"
)

usage() {
  cat <<'EOF'
Usage:
  security-scan.sh --changed
  security-scan.sh --all
  security-scan.sh <path> [<path> ...]

Scans shell scripts for forbidden security patterns (RCE, hardcoded creds, etc.).
EOF
}

is_shell_candidate() {
  local path="$1"
  [[ -f "$path" ]] || return 1
  [[ "$path" == *.sh ]] && return 0
  local first
  first="$(head -n 1 "$path" 2>/dev/null || true)"
  [[ "$first" =~ ^\#\!.*(bash|sh) ]]
}

collect_changed() {
  local rel
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    local full="$ROOT_DIR/$rel"
    if is_shell_candidate "$full"; then
      echo "$full"
    fi
  done < <(git -C "$ROOT_DIR" status --porcelain 2>/dev/null | sed -E 's/^.. //')
}

collect_all() {
  find "$ROOT_DIR/scripts" "$ROOT_DIR/agent/skills" \
    -name "*.sh" \
    -not -path "*/__pycache__/*" \
    2>/dev/null | sort
}

scan_files() {
  local -a files=("$@")
  local total_violations=0

  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    local file_violations=0
    for entry in "${FORBIDDEN_PATTERNS[@]}"; do
      local desc="${entry%%|*}"
      local rest="${entry#*|}"
      local pattern="${rest%%|*}"
      local exclude="${rest#*|}"
      # shellcheck disable=SC2155
      local matches
      if [[ -n "$exclude" ]]; then
        matches=$(grep -En "$pattern" "$f" 2>/dev/null | grep -Ev "$exclude" || true)
      else
        matches=$(grep -En "$pattern" "$f" 2>/dev/null || true)
      fi
      if [[ -n "$matches" ]]; then
        if [[ $file_violations -eq 0 ]]; then
          echo "  VIOLATION: ${f#"$ROOT_DIR"/}"
        fi
        while IFS= read -r match; do
          echo "    [$desc] $match"
        done <<< "$matches"
        file_violations=$((file_violations + 1))
        total_violations=$((total_violations + 1))
      fi
    done
  done

  return $((total_violations > 0 ? 1 : 0))
}

main() {
  if [[ $# -eq 0 ]]; then
    usage
    exit "$EXIT_USAGE"
  fi

  local -a targets=()

  case "$1" in
    --changed)
      mapfile -t targets < <(collect_changed | sort -u)
      ;;
    --all)
      mapfile -t targets < <(collect_all)
      ;;
    --help|-h)
      usage
      exit "$EXIT_OK"
      ;;
    *)
      for arg in "$@"; do
        local full="$arg"
        [[ "$arg" = /* ]] || full="$ROOT_DIR/$arg"
        if [[ -d "$full" ]]; then
          while IFS= read -r found; do
            targets+=("$found")
          done < <(find "$full" -name "*.sh" -not -path "*/__pycache__/*" 2>/dev/null || true)
        elif is_shell_candidate "$full"; then
          targets+=("$full")
        fi
      done
      ;;
  esac

  if [[ ${#targets[@]} -eq 0 ]]; then
    echo "Security scan: no shell files to check."
    exit "$EXIT_OK"
  fi

  echo "Security scan (${#targets[@]} files):"

  if scan_files "${targets[@]}"; then
    echo "  Security scan OK – no forbidden patterns found."
    exit "$EXIT_OK"
  else
    echo "  Security scan FAILED – forbidden patterns found (see above)." >&2
    exit "$EXIT_VIOLATIONS"
  fi
}

main "$@"
