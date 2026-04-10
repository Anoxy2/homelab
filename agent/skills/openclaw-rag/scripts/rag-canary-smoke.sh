#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVAL_SCRIPT="$SCRIPT_DIR/evaluate-goldset.py"
CANARY_CRITERIA="/home/steges/agent/skills/skill-forge/policy/canary-criteria.yaml"

DEFAULTS_JSON="$(python3 - "$CANARY_CRITERIA" <<'PY'
import json
import sys

path = sys.argv[1]
defaults = {
  'min_precision_at_5': 0.25,
  'min_recall_at_5': 0.55,
  'max_p95_latency_ms': 200,
  'gold_set_questions': 5,
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

MIN_PRECISION="${RAG_CANARY_MIN_PRECISION:-$(python3 - <<'PY' "$DEFAULTS_JSON"
import json, sys
print(json.loads(sys.argv[1])['min_precision_at_5'])
PY
)}"
MIN_RECALL="${RAG_CANARY_MIN_RECALL:-$(python3 - <<'PY' "$DEFAULTS_JSON"
import json, sys
print(json.loads(sys.argv[1])['min_recall_at_5'])
PY
)}"
MAX_P95_MS="${RAG_CANARY_MAX_P95_MS:-$(python3 - <<'PY' "$DEFAULTS_JSON"
import json, sys
print(json.loads(sys.argv[1])['max_p95_latency_ms'])
PY
)}"
LIMIT="${RAG_CANARY_TOP_K:-5}"
TIMEOUT_MS="${RAG_CANARY_TIMEOUT_MS:-1500}"
JSON_MODE=0

usage() {
  cat <<'EOF'
Usage:
  rag-canary-smoke.sh [--json]

Runs the local GOLD-SET evaluation and enforces basic canary thresholds:
  - min precision@k
  - min recall@k
  - max p95 latency

Env overrides:
  RAG_CANARY_MIN_PRECISION  (default from canary-criteria.yaml for openclaw-rag)
  RAG_CANARY_MIN_RECALL     (default from canary-criteria.yaml for openclaw-rag)
  RAG_CANARY_MAX_P95_MS     (default from canary-criteria.yaml for openclaw-rag)
  RAG_CANARY_TOP_K          (default: 5)
  RAG_CANARY_TIMEOUT_MS     (default: 1500)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_MODE=1
      shift
      ;;
    --help|-h|help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

payload="$(python3 "$EVAL_SCRIPT" --limit "$LIMIT" --timeout-ms "$TIMEOUT_MS")"

python3 - "$payload" "$MIN_PRECISION" "$MIN_RECALL" "$MAX_P95_MS" "$JSON_MODE" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
min_precision = float(sys.argv[2])
min_recall = float(sys.argv[3])
max_p95_ms = float(sys.argv[4])
json_mode = sys.argv[5] == '1'

precision = float(payload.get('avg_precision_at_k', 0.0))
recall = float(payload.get('avg_recall_at_k', 0.0))
p95 = float(payload.get('p95_latency_ms', 0.0))

checks = {
    'precision_ok': precision >= min_precision,
    'recall_ok': recall >= min_recall,
    'p95_ok': p95 <= max_p95_ms,
}
passed = all(checks.values())

result = {
    'kind': 'rag_canary_smoke',
    'passed': passed,
    'thresholds': {
        'min_precision_at_k': min_precision,
        'min_recall_at_k': min_recall,
        'max_p95_latency_ms': max_p95_ms,
        'top_k': payload.get('k'),
        'timeout_ms': payload.get('timeout_ms'),
    },
    'metrics': {
        'avg_precision_at_k': precision,
        'avg_recall_at_k': recall,
        'p95_latency_ms': p95,
        'question_count': payload.get('question_count'),
        'questions_with_full_recall': payload.get('questions_with_full_recall'),
    },
    'checks': checks,
}

if json_mode:
    print(json.dumps(result, ensure_ascii=True, indent=2))
else:
    print('RAG Canary Smoke')
    print(f"  passed: {passed}")
    print(f"  precision@k: {precision} (min {min_precision})")
    print(f"  recall@k:    {recall} (min {min_recall})")
    print(f"  p95(ms):     {p95} (max {max_p95_ms})")
    print(f"  full-recall questions: {payload.get('questions_with_full_recall')}/{payload.get('question_count')}")

raise SystemExit(0 if passed else 1)
PY
