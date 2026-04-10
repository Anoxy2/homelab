#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

lint_agent_md_state_writes() {
  local -a agent_md_files=()
  local -a violations=()
  local targets_re='(known-skills\.json|canary\.json|audit-log\.jsonl|pending-blacklist\.json|author-queue\.json|writer-jobs\.json|incident-freeze\.json)'

  mapfile -t agent_md_files < <(find /home/steges/agent/skills -type f \( -path '*/agents/*.md' -o -path '*/AGENTS.md' \) 2>/dev/null | sort)

  local f
  for f in "${agent_md_files[@]}"; do
    [[ -f "$f" ]] || continue

    # Nur echte Write-Muster blockieren (Redirection / tee in State-Dateien),
    # reine Dokumentationstexte wie "write" oder Dateinamen bleiben erlaubt.
    while IFS= read -r hit; do
      [[ -n "$hit" ]] || continue
      violations+=("$hit")
    done < <(grep -En "(>>?|tee[[:space:]]+).*$targets_re" "$f" 2>/dev/null || true)
  done

  if [[ ${#violations[@]} -gt 0 ]]; then
    echo "Policy violation: state-write command patterns found in Agent-MD files"
    printf ' - %s\n' "${violations[@]}"
    return 1
  fi
}

main() {
  ensure_dirs
  init_state_files

  local files=(
    "$POLICY_DIR/vetting-policy.yaml"
    "$POLICY_DIR/rollout-policy.yaml"
    "$POLICY_DIR/incident-policy.yaml"
    "$POLICY_DIR/source-trust-policy.yaml"
  )

  for f in "${files[@]}"; do
    [[ -f "$f" ]] || { echo "Missing policy file: $f"; exit 1; }
    grep -Eq '^version:[[:space:]]+[0-9]+' "$f" || { echo "Invalid version in $f"; exit 1; }
  done

  grep -Eq '^min_reputation_for_extraction:[[:space:]]+[0-9]+' "$POLICY_DIR/vetting-policy.yaml" || {
    echo "Missing min_reputation_for_extraction in vetting-policy.yaml"
    exit 1
  }

  grep -Eq 'quarantine_hours:[[:space:]]+[0-9]+' "$POLICY_DIR/vetting-policy.yaml" || {
    echo "Missing quarantine_hours in vetting-policy.yaml"
    exit 1
  }

  grep -Eq 'shadow_mode_days:[[:space:]]+[0-9]+' "$POLICY_DIR/rollout-policy.yaml" || {
    echo "Missing shadow_mode_days in rollout-policy.yaml"
    exit 1
  }

  grep -Eq 'extreme_findings_same_source_24h:[[:space:]]+[0-9]+' "$POLICY_DIR/incident-policy.yaml" || {
    echo "Missing auto_freeze threshold in incident-policy.yaml"
    exit 1
  }

  lint_agent_md_state_writes || exit 1

  echo "Policy lint OK"
}

main "$@"
