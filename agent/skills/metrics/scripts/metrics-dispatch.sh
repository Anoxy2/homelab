#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "/home/steges/agent/skills/skill-forge/scripts/common.sh"

METRICS_STATE_DIR="${METRICS_STATE_DIR:-/home/steges/agent/skills/skill-forge/.state}"
KNOWN_SKILLS_PATH="$METRICS_STATE_DIR/known-skills.json"
AUDIT_LOG_PATH="$METRICS_STATE_DIR/audit-log.jsonl"
LEGACY_AUDIT_LOG_PATH="$METRICS_STATE_DIR/audit.log"
METRICS_PATH="$METRICS_STATE_DIR/metrics.jsonl"
METRICS_WEEKLY_PATH="$METRICS_STATE_DIR/metrics-weekly.json"
VETTER_REPORTS_DIR="$METRICS_STATE_DIR/vetter-reports"
SKILL_RISK_REPORT_PATH="$METRICS_STATE_DIR/skill-risk-report.json"

usage() {
    echo "Usage: metrics-dispatch.sh record <run_id> <live> <vet_score> <duration_ms> | weekly | latest | install-success | risk-report"
}

record_metrics() {
  local run_id="$1"
  local live="$2"
  local vet_score="$3"
  local duration_ms="$4"

  python3 - "$run_id" "$live" "$vet_score" "$duration_ms" "$METRICS_STATE_DIR" <<'PY'
import json, os, sys
from datetime import datetime, timezone
run_id = sys.argv[1]
live = sys.argv[2] == '1'
vet_score = int(sys.argv[3])
duration_ms = int(sys.argv[4])
base = sys.argv[5]
kp = base + '/known-skills.json'
ap = base + '/audit-log.jsonl'
legacy_ap = base + '/audit.log'
mp = base + '/metrics.jsonl'

with open(kp, 'r', encoding='utf-8') as f:
    known = json.load(f)

total = len(known) if known else 1
active = sum(1 for r in known.values() if r.get('status') == 'active')
pending = sum(1 for r in known.values() if r.get('status') == 'pending-review')
rollback = sum(1 for r in known.values() if r.get('status') == 'rollback')
canary = sum(1 for r in known.values() if r.get('status') == 'canary')

promoted = 0
blocked = 0
lines = []
for path in (ap, legacy_ap):
    if os.path.exists(path):
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            lines.extend(f.readlines())

for raw in lines[-600:]:
    line = raw.strip()
    if not line:
        continue
    if line.startswith('{'):
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        action = str(obj.get('command', ''))
        msg = str(obj.get('message', ''))
        if action != 'ORCHESTRATE':
            continue
        if 'vetted->active' in msg:
            promoted += 1
        if 'vetted-blocked' in msg:
            blocked += 1
    else:
        if 'ORCHESTRATE' not in line:
            continue
        if 'vetted->active' in line:
            promoted += 1
        if 'vetted-blocked' in line:
            blocked += 1

record = {
    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'run_id': run_id,
    'live': live,
    'vet_score': vet_score,
    'install_success_rate': round(active / total, 4),
    'false_positive_rate_vetting': round(pending / total, 4),
    'promotion_rate_canary_to_active': round(promoted / max(1, promoted + blocked), 4),
    'rollback_rate': round(rollback / total, 4),
    'cpu_minutes_per_run': round(duration_ms / 60000.0, 4),
    'memory_peak_mb': 0,
    'time_to_decision': round(duration_ms / 1000.0, 2),
    'known_total': total,
    'canary_total': canary
}

import fcntl
lock_path = mp + '.lock'
os.makedirs(os.path.dirname(lock_path), exist_ok=True)
with open(lock_path, 'a') as lf:
    fcntl.flock(lf.fileno(), fcntl.LOCK_EX)
    try:
        with open(mp, 'a', encoding='utf-8') as f:
            f.write(json.dumps(record) + '\n')
    finally:
        fcntl.flock(lf.fileno(), fcntl.LOCK_UN)

print(json.dumps(record, indent=2))
PY
}

weekly_aggregate() {
  python3 - "$METRICS_STATE_DIR" <<'PY'
import json
import sys
from datetime import datetime, timezone, timedelta
base = sys.argv[1]
mp = base + '/metrics.jsonl'
wp = base + '/metrics-weekly.json'

rows = []
try:
    with open(mp, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
except FileNotFoundError:
    rows = []

cutoff = datetime.now(timezone.utc) - timedelta(days=7)
recent = []
for r in rows:
    try:
        dt = datetime.strptime(r['timestamp'], '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
    except Exception:
        continue
    if dt >= cutoff:
        recent.append(r)

def avg(key):
    if not recent:
        return 0
    return round(sum(float(x.get(key, 0)) for x in recent) / len(recent), 4)

out = {
    'generated_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'runs': len(recent),
    'avg_install_success_rate': avg('install_success_rate'),
    'avg_false_positive_rate_vetting': avg('false_positive_rate_vetting'),
    'avg_promotion_rate_canary_to_active': avg('promotion_rate_canary_to_active'),
    'avg_rollback_rate': avg('rollback_rate'),
    'avg_cpu_minutes_per_run': avg('cpu_minutes_per_run'),
    'avg_time_to_decision': avg('time_to_decision')
}
import fcntl, tempfile
lock_path = wp + '.lock'
os.makedirs(os.path.dirname(lock_path), exist_ok=True)
with open(lock_path, 'a') as lf:
    fcntl.flock(lf.fileno(), fcntl.LOCK_EX)
    try:
        fd, tmp = tempfile.mkstemp(prefix='.tmp-', suffix='.json', dir=os.path.dirname(wp))
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as f:
                json.dump(out, f, indent=2)
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp, wp)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
    finally:
        fcntl.flock(lf.fileno(), fcntl.LOCK_UN)

print(json.dumps(out, indent=2))
PY
}

latest() {
  python3 - "$METRICS_PATH" <<'PY'
import json
import sys
p = sys.argv[1]
try:
    with open(p, 'r', encoding='utf-8') as f:
        rows = [line.strip() for line in f if line.strip()]
except FileNotFoundError:
    rows = []
if not rows:
    print('{}')
else:
    print(json.dumps(json.loads(rows[-1]), indent=2))
PY
}

install_success_report() {
    python3 - "$METRICS_PATH" "$METRICS_WEEKLY_PATH" <<'PY'
import json
import sys
from pathlib import Path

latest_path = Path(sys.argv[1])
weekly_path = Path(sys.argv[2])

latest = {}
weekly = {}

if latest_path.exists():
    rows = [ln.strip() for ln in latest_path.read_text(encoding='utf-8').splitlines() if ln.strip()]
    if rows:
        latest = json.loads(rows[-1])

if weekly_path.exists():
    weekly = json.loads(weekly_path.read_text(encoding='utf-8'))

payload = {
    'latest_install_success_rate': latest.get('install_success_rate'),
    'latest_run_id': latest.get('run_id'),
    'weekly_avg_install_success_rate': weekly.get('avg_install_success_rate'),
    'weekly_runs': weekly.get('runs'),
}
print(json.dumps(payload, ensure_ascii=True, indent=2))
PY
}

risk_report() {
  python3 - "$KNOWN_SKILLS_PATH" "$AUDIT_LOG_PATH" "$LEGACY_AUDIT_LOG_PATH" "$VETTER_REPORTS_DIR" "$SKILL_RISK_REPORT_PATH" <<'PY'
import fcntl, json, os, sys, tempfile
from datetime import datetime, timezone
from pathlib import Path

known_path   = Path(sys.argv[1])
audit_path   = Path(sys.argv[2])
legacy_path  = Path(sys.argv[3])
vetter_dir   = Path(sys.argv[4])
report_path  = Path(sys.argv[5])

TIER_WEIGHT = {'LOW': 0, 'MEDIUM': 10, 'HIGH': 20, 'EXTREME': 40}

try:
    known = json.loads(known_path.read_text(encoding='utf-8'))
except (FileNotFoundError, json.JSONDecodeError):
    known = {}

# Aggregate audit events per slug
counts = {}  # slug -> {REJECT, ROLLBACK, REVIEW, PASS}
for p in (audit_path, legacy_path):
    if not p.exists():
        continue
    for raw in p.read_text(encoding='utf-8', errors='ignore').splitlines():
        raw = raw.strip()
        if not raw:
            continue
        if raw.startswith('{'):
            try:
                obj = json.loads(raw)
            except json.JSONDecodeError:
                continue
            cmd    = str(obj.get('command', ''))
            target = str(obj.get('target', ''))
        else:
            # legacy plain-text format: ignore, no slug info
            continue
        if cmd not in ('REJECT', 'ROLLBACK', 'REVIEW', 'PASS'):
            continue
        if not target:
            continue
        bucket = counts.setdefault(target, {'REJECT': 0, 'ROLLBACK': 0, 'REVIEW': 0, 'PASS': 0})
        bucket[cmd] = bucket.get(cmd, 0) + 1

out = {'generated_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'), 'skills': {}}

for slug, meta in known.items():
    status = meta.get('status', 'unknown')
    vetting_score = meta.get('vetting_score', meta.get('score', 0))
    quality_tier  = meta.get('quality_tier', '')

    # Vetter report
    vr_path = vetter_dir / f'{slug}.json'
    risk_tier = 'UNKNOWN'
    final_score = None
    verdict = None
    last_vetter_ts = None
    if vr_path.exists():
        try:
            vr = json.loads(vr_path.read_text(encoding='utf-8'))
            risk_tier     = vr.get('risk_tier', 'UNKNOWN')
            verdict       = vr.get('verdict')
            last_vetter_ts = vr.get('timestamp')
            scores = vr.get('scores', {})
            final_score = scores.get('final_score')
        except (json.JSONDecodeError, OSError):
            pass

    bucket = counts.get(slug, {'REJECT': 0, 'ROLLBACK': 0, 'REVIEW': 0, 'PASS': 0})
    reject_count   = bucket['REJECT']
    rollback_count = bucket['ROLLBACK']
    review_count   = bucket['REVIEW']
    pass_count     = bucket['PASS']

    tier_w = TIER_WEIGHT.get(risk_tier, 20)
    pending_bonus = 10 if status == 'pending-review' else 0
    risk_score = min(100, (reject_count * 30) + (rollback_count * 40) + tier_w + pending_bonus)

    out['skills'][slug] = {
        'slug': slug,
        'status': status,
        'risk_tier': risk_tier,
        'vetting_score': vetting_score,
        'quality_tier': quality_tier,
        'verdict': verdict,
        'last_vetter_ts': last_vetter_ts,
        'final_score': final_score,
        'reject_count': reject_count,
        'rollback_count': rollback_count,
        'review_count': review_count,
        'pass_count': pass_count,
        'risk_score': risk_score
    }

# Atomic write
lock_path = str(report_path) + '.lock'
os.makedirs(str(report_path.parent), exist_ok=True)
with open(lock_path, 'a') as lf:
    fcntl.flock(lf.fileno(), fcntl.LOCK_EX)
    try:
        fd, tmp = tempfile.mkstemp(prefix='.tmp-', dir=str(report_path.parent))
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as f:
                json.dump(out, f, indent=2)
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp, str(report_path))
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
    finally:
        fcntl.flock(lf.fileno(), fcntl.LOCK_UN)

print(json.dumps(out, indent=2))
PY
}

main() {
  ensure_dirs
  init_state_files

  local cmd="${1:-}"
  case "$cmd" in
    record)
      [[ $# -eq 5 ]] || { usage; exit 1; }
      record_metrics "$2" "$3" "$4" "$5"
      ;;
    weekly)
      weekly_aggregate
      ;;
    latest)
      latest
      ;;
    install-success)
      install_success_report
      ;;
    risk-report)
      risk_report
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
