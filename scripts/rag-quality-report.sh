#!/bin/bash
# Wöchentlicher RAG-Qualitätsreport: Gold-Set Evaluation + Telegram-Zusammenfassung

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${RAG_REPORT_REPO_ROOT:-/home/steges}"
EVALUATE="$REPO_ROOT/agent/skills/openclaw-rag/scripts/evaluate-goldset.py"
GOLD_SET="$REPO_ROOT/agent/skills/openclaw-rag/GOLD-SET.json"

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

# Gate-Bewertung (aus rag-canary-smoke.sh: precision>=0.25, recall>=0.55, p95<=200ms)
gates="✅ Gates OK"
gate_details=""
if [[ "$precision" != "n/a" ]] && (( $(echo "$precision < 0.25" | bc -l) )); then
  gates="⚠️ Gate FAIL"
  gate_details="${gate_details}
• Precision@5 ${precision} < 0.25 (Minimum)"
fi
if [[ "$recall" != "n/a" ]] && (( $(echo "$recall < 0.55" | bc -l) )); then
  gates="⚠️ Gate FAIL"
  gate_details="${gate_details}
• Recall@5 ${recall} < 0.55 (Minimum)"
fi
if [[ "$p95" != "n/a" ]] && (( $(echo "$p95 > 200" | bc -l) )); then
  gates="⚠️ Gate FAIL"
  gate_details="${gate_details}
• p95 ${p95}ms > 200ms (Maximum)"
fi

msg="📊 RAG Weekly Report @ ${host_name} — ${now}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Precision@k: ${precision} (Min: 0.25)
• Recall@k:    ${recall} (Min: 0.55)
• p95 Latenz:  ${p95}ms (Max: 200ms)

${gates}${gate_details}"

send_telegram "$msg"
echo "RAG quality report sent: precision=${precision} recall=${recall} p95=${p95}ms"
