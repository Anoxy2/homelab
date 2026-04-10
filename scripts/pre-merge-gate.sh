#!/bin/bash
# Pre-merge quality gate: shellcheck + policy lint + skill-forge smoke tests
# Usage: pre-merge-gate.sh [--all]
#   (no args)  – lint changed files only, skip slow smoke tests
#   --all      – lint ALL shell files and run smoke tests

set -euo pipefail

ROOT_DIR="/home/steges"
SKILL_MANAGER_SCRIPTS="$ROOT_DIR/agent/skills/skill-forge/scripts"
PASS=0
FAIL=0

step() { echo ""; echo "── $* ──────────────────────────────────────"; }
ok()   { echo "  OK: $*"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL+1)); }

MODE="${1:-}"

# ── 1. Shell lint ─────────────────────────────────────────────────────────────
step "Shell lint"
if [[ "$MODE" == "--all" ]]; then
  mapfile -t all_sh < <(find "$ROOT_DIR/scripts" "$ROOT_DIR/agent/skills" -name "*.sh" -not -path "*/__pycache__/*" 2>/dev/null | sort)
  if [[ ${#all_sh[@]} -gt 0 ]]; then
    if command -v shellcheck >/dev/null 2>&1; then
      if shellcheck -x "${all_sh[@]}" 2>&1; then
        ok "shellcheck (all, ${#all_sh[@]} files)"
      else
        fail "shellcheck found issues"
      fi
    else
      ok "shellcheck not installed – skipped"
    fi
  else
    ok "no .sh files found"
  fi
else
  if "$ROOT_DIR/scripts/lint-shell.sh" --changed 2>&1; then
    ok "lint-shell.sh --changed"
  else
    fail "lint-shell.sh --changed"
  fi
fi

# ── 2. Security pattern scan ──────────────────────────────────────────────────
step "Security pattern scan"
if [[ "$MODE" == "--all" ]]; then
  if "$ROOT_DIR/scripts/security-scan.sh" --all 2>&1; then
    ok "security-scan.sh --all"
  else
    fail "security-scan.sh –- forbidden patterns found"
  fi
else
  if "$ROOT_DIR/scripts/security-scan.sh" --changed 2>&1; then
    ok "security-scan.sh --changed"
  else
    fail "security-scan.sh –- forbidden patterns found"
  fi
fi

# ── 3. Policy lint ────────────────────────────────────────────────────────────
step "Policy lint"
if "$ROOT_DIR/scripts/skill-forge" policy lint 2>&1; then
  ok "policy lint"
else
  fail "policy lint"
fi

# ── 4. Bash syntax check on changed scripts ──────────────────────────────────
step "Bash syntax (bash -n)"
changed_sh=()
while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue
  full="$ROOT_DIR/$rel"
  [[ -f "$full" && "$full" == *.sh ]] || continue
  changed_sh+=("$full")
done < <(git -C "$ROOT_DIR" status --porcelain 2>/dev/null | sed -E 's/^.. //' || true)

if [[ ${#changed_sh[@]} -eq 0 ]]; then
  ok "no changed .sh files"
else
  syntax_ok=1
  for f in "${changed_sh[@]}"; do
    if ! bash -n "$f" 2>&1; then
      fail "syntax error in $f"
      syntax_ok=0
    fi
  done
  [[ $syntax_ok -eq 1 ]] && ok "bash -n (${#changed_sh[@]} files)"
fi

# ── 5. Skill structure check ──────────────────────────────────────────────────
step "Skill structure check"
if "$ROOT_DIR/scripts/skill-structure-check.sh" 2>&1; then
  ok "skill-structure-check.sh"
else
  fail "skill-structure-check.sh – required structure missing"
fi

# ── 6. Smoke tests (--all only) ───────────────────────────────────────────────
if [[ "$MODE" == "--all" ]]; then
  step "Skill-Manager contract tests"
  if bash "$SKILL_MANAGER_SCRIPTS/test-wrapper-contracts.sh" 2>&1 | tail -3; then
    ok "test-wrapper-contracts.sh"
  else
    fail "test-wrapper-contracts.sh"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
if [[ $FAIL -eq 0 ]]; then
  echo "  Pre-merge gate: PASS ($PASS checks)"
  exit 0
else
  echo "  Pre-merge gate: FAIL ($FAIL/$((PASS+FAIL)) checks failed)" >&2
  exit 1
fi
