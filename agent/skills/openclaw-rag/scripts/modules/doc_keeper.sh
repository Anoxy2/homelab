#!/bin/bash

# doc_keeper.sh - Doc-Keeper Adapter fuer rag-dispatch
# AutoDoc wird an den eigenständigen autodoc-Skill delegiert.

AUTODOC_DISPATCH="/home/steges/agent/skills/autodoc/scripts/autodoc-dispatch.sh"

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

  local -a autodoc_cmd=("$AUTODOC_DISPATCH" profile "$autodoc_profile" --provider "$autodoc_provider")
  [[ "$autodoc_dry_run" == "1" ]] && autodoc_cmd+=(--dry-run)
  [[ -n "$autodoc_model" ]] && autodoc_cmd+=(--model "$autodoc_model")

  if ! "${autodoc_cmd[@]}"; then
    echo "WARN: autodoc profile '$autodoc_profile' had failures; doc-keeper result stays successful" >&2
  fi
}
