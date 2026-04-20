#!/bin/bash
set -euo pipefail

SOURCE_FILE="/home/steges/infra/canvas/html/index.html"
DEPLOYED_FILE="/home/steges/infra/openclaw-data/canvas/index.html"

usage() {
  echo "Usage: $0 [--json]"
}

emit_json=0
if [[ "${1:-}" == "--json" ]]; then
  emit_json=1
elif [[ $# -gt 0 ]]; then
  usage
  exit 2
fi

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "Source file missing: $SOURCE_FILE" >&2
  exit 1
fi

if [[ ! -f "$DEPLOYED_FILE" ]]; then
  echo "Deployed file missing: $DEPLOYED_FILE" >&2
  exit 1
fi

src_hash="$(sha256sum "$SOURCE_FILE" | awk '{print $1}')"
deployed_hash="$(sha256sum "$DEPLOYED_FILE" | awk '{print $1}')"

is_symlink="false"
if [[ -L "$DEPLOYED_FILE" ]]; then
  is_symlink="true"
fi

status="ok"
if [[ "$src_hash" != "$deployed_hash" ]]; then
  status="drift"
fi

if [[ "$emit_json" -eq 1 ]]; then
  cat <<EOF
{
  "status": "$status",
  "source_file": "$SOURCE_FILE",
  "deployed_file": "$DEPLOYED_FILE",
  "source_sha256": "$src_hash",
  "deployed_sha256": "$deployed_hash",
  "deployed_is_symlink": $is_symlink
}
EOF
else
  echo "Canvas drift check"
  echo "- source:   $SOURCE_FILE"
  echo "- deployed: $DEPLOYED_FILE"
  echo "- source_sha256:   $src_hash"
  echo "- deployed_sha256: $deployed_hash"
  echo "- deployed_is_symlink: $is_symlink"
  echo "- status: $status"
fi

if [[ "$status" == "drift" ]]; then
  exit 3
fi
