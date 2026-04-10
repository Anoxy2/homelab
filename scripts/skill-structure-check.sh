#!/bin/bash
# skill-structure-check.sh – Einheitliche Skill-Struktur prüfen (Standards & Contracts P0/P1)
# Validiert: SKILL.md (required), scripts/ (required), agents/ (expected), contracts/ (expected)
#
# Usage:
#   skill-structure-check.sh [--strict] [<skills-dir>]
#   --strict: agents/ und contracts/ fehlen lassen Gate fehlschlagen (sonst nur Warnung)

set -euo pipefail

SKILLS_ROOT="${SKILL_STRUCTURE_ROOT:-/home/steges/agent/skills}"
STRICT=0
EXIT_OK=0
EXIT_FAIL=1
EXIT_USAGE=2

# Skills ohne Dispatch-Script – kein scripts/-Verzeichnis erwartet
# Format: Leerzeichen-getrennte Skill-Namen
SKIP_SCRIPTS="core openclaw-ui"

# Pflicht (immer Fehler wenn fehlend), außer bei SKIP_SCRIPTS
REQUIRED=("SKILL.md" "scripts")
# Erwartet (Warnung in normal; Fehler in --strict)
EXPECTED=("agents" "contracts")

usage() {
  cat <<'EOF'
Usage:
  skill-structure-check.sh [--strict] [<skills-dir>]

Checks every skill directory for the required structure:
  Required:  SKILL.md, scripts/
  Expected:  agents/, contracts/   (warnings; errors with --strict)
EOF
}

main() {
  local custom_root=""
  for arg in "$@"; do
    case "$arg" in
      --strict) STRICT=1 ;;
      --help|-h) usage; exit "$EXIT_OK" ;;
      *) custom_root="$arg" ;;
    esac
  done
  [[ -n "$custom_root" ]] && SKILLS_ROOT="$custom_root"

  if [[ ! -d "$SKILLS_ROOT" ]]; then
    echo "ERROR: skills root not found: $SKILLS_ROOT" >&2
    exit "$EXIT_USAGE"
  fi

  local total=0 errors=0 warnings=0

  for skill_dir in "$SKILLS_ROOT"/*/; do
    [[ -d "$skill_dir" ]] || continue
    local name
    name=$(basename "$skill_dir")
    local skill_errors=0 skill_warnings=0
    total=$((total+1))

    # Required (scripts/ skip für bekannte no-dispatch Skills)
    for item in "${REQUIRED[@]}"; do
      if [[ "$item" == "scripts" ]] && [[ " $SKIP_SCRIPTS " == *" $name "* ]]; then
        continue
      fi
      if [[ ! -e "$skill_dir$item" ]]; then
        echo "  ERROR   [$name] missing required: $item"
        skill_errors=$((skill_errors+1))
      fi
    done

    # Expected
    for item in "${EXPECTED[@]}"; do
      if [[ ! -d "$skill_dir$item" ]]; then
        if [[ $STRICT -eq 1 ]]; then
          echo "  ERROR   [$name] missing expected (strict): $item/"
          skill_errors=$((skill_errors+1))
        else
          echo "  WARN    [$name] missing expected: $item/"
          skill_warnings=$((skill_warnings+1))
        fi
      fi
    done

    errors=$((errors + skill_errors))
    warnings=$((warnings + skill_warnings))
  done

  echo ""
  echo "Skill structure check: $total skills, $errors errors, $warnings warnings"

  if [[ $errors -gt 0 ]]; then
    echo "FAIL – required structure missing in $errors item(s)." >&2
    exit "$EXIT_FAIL"
  else
    echo "OK"
    exit "$EXIT_OK"
  fi
}

main "$@"
