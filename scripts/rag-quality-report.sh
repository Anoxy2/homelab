#!/bin/bash
# Wöchentlicher RAG-Qualitätsreport: Gold-Set Evaluation + Telegram-Zusammenfassung

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${RAG_REPORT_REPO_ROOT:-/home/steges}"
EVALUATE="$REPO_ROOT/agent/skills/openclaw-rag/scripts/evaluate-goldset.py"
GOLD_SET="$REPO_ROOT/agent/skills/openclaw-rag/GOLD-SET.json"
CANARY_CRITERIA="$REPO_ROOT/agent/skills/skill-forge/policy/canary-criteria.yaml"

# Thresholds aus canary-criteria.yaml lesen (identisch mit rag-canary-smoke.sh)
_THRESHOLDS="$(python3 - "$CANARY_CRITERIA" <<'PY'
import json, sys
path = sys.argv[1]
defaults = {
  'min_precision_at_5': 0.25,
  'min_recall_at_5': 0.55,
  'max_p95_latency_ms': 450,
}
try:
  import yaml
  with open(path, 'r', encoding='utf-8') as f:
    data = yaml.safe_load(f) or {}
  rag = (((data.get('skills') or {}).get('openclaw-rag') or {}).get('rag_quality') or {})
  defaults.update({k: rag.get(k, v) for k, v in defaults.items()})
except Exception:
  pass
print(json.dumps(defaults, ensure_ascii=True))
PY
)"
MIN_PRECISION="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['min_precision_at_5'])" "$_THRESHOLDS")"
MIN_RECALL="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['min_recall_at_5'])" "$_THRESHOLDS")"
MAX_P95_MS="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['max_p95_latency_ms'])" "$_THRESHOLDS")"

# shellcheck source=/home/steges/scripts/lib/env.sh
source "$SCRIPT_DIR/lib/env.sh"
load_dotenv

send_telegram() {
  local msg="$1"
  local token="${TELEGRAM_BOT_TOKEN:-}"
  local chat="${TELEGRAM_CHAT_ID:-}"
  [[ -n "$token" && -n "$chat" ]] || return 0
  curl -sf -X POST "https://api.telegram.org/bot${token}/sendMessage" \
    -d chat_id="$chat" \
    -d parse_mode="HTML" \
    --data-urlencode "text=$msg" >/dev/null || true
}

now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
host_name="$(hostname)"

if [[ ! -f "$EVALUATE" ]]; then
  send_telegram "📊 RAG Weekly Report @ ${host_name} — ${now}
❌ evaluate-goldset.py nicht gefunden: ${EVALUATE}"
  echo "ERROR: evaluate-goldset.py not found"
  exit 1
fi

if [[ ! -f "$GOLD_SET" ]]; then
  send_telegram "📊 RAG Weekly Report @ ${host_name} — ${now}
❌ GOLD-SET.json nicht gefunden: ${GOLD_SET}"
  echo "ERROR: GOLD-SET.json not found"
  exit 1
fi

if ! eval_out="$(python3 "$EVALUATE" --limit 5 --timeout-ms 1500 2>&1)"; then
  rc=$?
  send_telegram "📊 RAG Weekly Report @ ${host_name} — ${now}
❌ Evaluation fehlgeschlagen (rc=${rc})
${eval_out:0:300}"
  echo "ERROR: evaluation failed rc=${rc}"
  exit 1
fi

if [[ -z "$eval_out" ]]; then
  send_telegram "📊 RAG Weekly Report @ ${host_name} — ${now}
❌ Evaluation gab keine Ausgabe zurück"
  echo "ERROR: evaluation returned empty output"
  exit 1
fi

read -r precision recall p95 parse_ok <<EOF
$(python3 - <<'PY' "$eval_out"
import json
import sys

raw = sys.argv[1]
try:
    payload = json.loads(raw)
except Exception:
    print("n/a n/a n/a 0")
    raise SystemExit(0)

precision = payload.get("avg_precision_at_k", "n/a")
recall = payload.get("avg_recall_at_k", "n/a")
p95 = payload.get("p95_latency_ms", "n/a")

print(f"{precision} {recall} {p95} 1")
PY
)
EOF

if [[ "$parse_ok" != "1" ]]; then
  send_telegram "📊 RAG Weekly Report @ ${host_name} — ${now}
❌ Evaluation lieferte kein valides JSON
${eval_out:0:300}"
  echo "ERROR: evaluation returned invalid JSON"
  exit 1
fi

# Gate-Bewertung (Thresholds aus canary-criteria.yaml)
gates="✅ Gates OK"
gate_details=""
if [[ "$precision" != "n/a" ]] && (( $(echo "$precision < $MIN_PRECISION" | bc -l) )); then
  gates="⚠️ Gate FAIL"
  gate_details="${gate_details}
• Precision@5 ${precision} < ${MIN_PRECISION} (Minimum)"
fi
if [[ "$recall" != "n/a" ]] && (( $(echo "$recall < $MIN_RECALL" | bc -l) )); then
  gates="⚠️ Gate FAIL"
  gate_details="${gate_details}
• Recall@5 ${recall} < ${MIN_RECALL} (Minimum)"
fi
if [[ "$p95" != "n/a" ]] && (( $(echo "$p95 > $MAX_P95_MS" | bc -l) )); then
  gates="⚠️ Gate FAIL"
  gate_details="${gate_details}
• p95 ${p95}ms > ${MAX_P95_MS}ms (Maximum)"
fi

msg="📊 RAG Weekly Report @ ${host_name} — ${now}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Precision@k: ${precision} (Min: ${MIN_PRECISION})
• Recall@k:    ${recall} (Min: ${MIN_RECALL})
• p95 Latenz:  ${p95}ms (Max: ${MAX_P95_MS}ms)

${gates}${gate_details}"

send_telegram "$msg"
echo "RAG quality report sent: precision=${precision} recall=${recall} p95=${p95}ms"
