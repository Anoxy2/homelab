#!/bin/bash
set -euo pipefail

PW_IMAGE="${PW_IMAGE:-mcr.microsoft.com/playwright:v1.53.0-jammy}"
BASE_URL="${CANVAS_BASE_URL:-http://192.168.2.101:8090}"
STAMP="$(date +%Y-%m-%d)"
OUT_DIR="${CANVAS_BASELINE_DIR:-/home/steges/docs/visual-baselines/canvas/${STAMP}}"
OUT_JSON="${OUT_DIR}/smoke-result.json"

mkdir -p "$OUT_DIR"

# Lightweight content checks
HTML_TMP="/tmp/canvas-page.html"
curl -sf "$BASE_URL" > "$HTML_TMP"
grep -q 'Ops Dashboard' "$HTML_TMP"
grep -q 'OpenClaw Chat' "$HTML_TMP"
grep -q 'MQTT Browser' "$HTML_TMP"

checks=(
  "ops|#dashboard|ops-dashboard.png"
  "chat|#chat|chat-page.png"
  "mqtt|#mqtt|mqtt-page.png"
)

failed=0
printf '{"generated_at":"%s","base_url":"%s","checks":[' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$BASE_URL" > "$OUT_JSON"
first=1
for row in "${checks[@]}"; do
  IFS='|' read -r name hash shot <<< "$row"
  url="${BASE_URL}${hash}"
  out="${OUT_DIR}/${shot}"
  ok=1
  err=""

  if ! docker run --rm --network host -v "$OUT_DIR:/work" "$PW_IMAGE" \
      bash -lc "npx -y playwright@1.53.0 screenshot '$url' '/work/$shot'" >/tmp/pw-${name}.log 2>&1; then
    ok=0
    failed=$((failed+1))
    err="$(tail -n 2 /tmp/pw-${name}.log | tr '\n' ' ' | sed 's/"/\\"/g')"
  fi

  [[ $first -eq 1 ]] || printf ',' >> "$OUT_JSON"
  first=0
  printf '{"name":"%s","url":"%s","screenshot":"%s","ok":%s,"error":"%s"}' \
    "$name" "$url" "$shot" "$([ "$ok" -eq 1 ] && echo true || echo false)" "$err" >> "$OUT_JSON"
done

printf '],"failed":%s,"status":"%s"}\n' "$failed" "$([ "$failed" -eq 0 ] && echo ok || echo failed)" >> "$OUT_JSON"

echo "status=$([ "$failed" -eq 0 ] && echo ok || echo failed) total=${#checks[@]} failed=$failed"
