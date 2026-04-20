#!/bin/bash
set -euo pipefail

ROOT="/home/steges"
STATE_DIR="$ROOT/agent/skills/skill-forge/.state"
OUT="$ROOT/infra/canvas/html/state-brief.latest.json"

python3 - "$STATE_DIR" "$OUT" <<'PY'
import json
import math
import os
import sys
import tempfile
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


state_dir = Path(sys.argv[1])
dest = Path(sys.argv[2])


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def safe_load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def safe_read_ts(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8").strip()
    except Exception:
        return ""


def pct(val, digits=1) -> float:
    try:
        return round(float(val) * 100, digits)
    except (TypeError, ValueError):
        return 0.0


def fp(val, digits=3) -> float:
    try:
        return round(float(val), digits)
    except (TypeError, ValueError):
        return 0.0


# --- load state files ---
known_skills: dict = safe_load_json(state_dir / "known-skills.json", {})
canary_state: dict = safe_load_json(state_dir / "canary.json", {})
freeze: dict = safe_load_json(state_dir / "incident-freeze.json", {})
pending_blacklist: list = safe_load_json(state_dir / "pending-blacklist.json", [])
metrics_weekly: dict = safe_load_json(state_dir / "metrics-weekly.json", {})
risk_report: dict = safe_load_json(state_dir / "skill-risk-report.json", {})
last_scout_ts: str = safe_read_ts(state_dir / "heartbeat-last-run.ts")

# --- metrics.jsonl ---
metrics_lines: list[dict] = []
jsonl_path = state_dir / "metrics.jsonl"
if jsonl_path.exists():
    for raw in jsonl_path.read_text(encoding="utf-8").splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            metrics_lines.append(json.loads(raw))
        except Exception:
            pass

# cap to last 30 for payload
metric_rows = metrics_lines[-30:]

# --- scout section ---
status_counts: Counter = Counter()
scout_list: list[dict] = []
for slug, entry in known_skills.items():
    if not isinstance(entry, dict):
        continue
    status = entry.get("status", "unknown")
    status_counts[status] += 1
    scout_list.append({
        "slug": slug,
        "source": entry.get("source", ""),
        "status": status,
        "version": entry.get("version", ""),
        "discovered_at": entry.get("discovered_at", ""),
        "last_scout": entry.get("last_scout", ""),
        "scout_score": fp(entry.get("scout_score", 0)),
        "vetting_score": fp(entry.get("vetting_score", 0)),
        "vetted_at": entry.get("vetted_at", ""),
    })

# sort: pending-review > canary > active > others; within group by last_scout desc
status_order = {
    "pending-review": 0,
    "pending-blacklist": 1,
    "canary": 2,
    "active": 3,
    "rollback": 4,
    "vetted": 5,
    "reviewed": 6,
}
scout_list.sort(key=lambda s: (status_order.get(s["status"], 99), s.get("last_scout", "") or ""), reverse=False)

scout_section = {
    "known_total": len(known_skills),
    "status_counts": dict(status_counts.most_common()),
    "canary_count": status_counts.get("canary", 0),
    "active_count": status_counts.get("active", 0),
    "pending_review": status_counts.get("pending-review", 0),
    "pending_blacklist_count": len(pending_blacklist),
    "last_scout_ts": last_scout_ts,
    "skills": scout_list[:80],  # cap for payload size
}

# --- health section ---
canary_list: list[dict] = []
for slug, entry in canary_state.items():
    if not isinstance(entry, dict):
        continue
    canary_list.append({
        "slug": slug,
        "status": entry.get("status", "unknown"),
        "started_at": entry.get("started_at", ""),
        "until": entry.get("until", ""),
        "promoted_at": entry.get("promoted_at", ""),
    })
canary_list.sort(key=lambda c: c.get("started_at", "") or "", reverse=True)

risk_skills: list[dict] = []
for slug, entry in risk_report.get("skills", {}).items():
    if not isinstance(entry, dict):
        continue
    risk_skills.append({
        "slug": slug,
        "status": entry.get("status", ""),
        "risk_tier": entry.get("risk_tier", ""),
        "risk_score": fp(entry.get("risk_score", 0)),
        "final_score": fp(entry.get("final_score", 0)),
        "verdict": entry.get("verdict", ""),
        "vetting_score": fp(entry.get("vetting_score", 0)),
        "rollback_count": entry.get("rollback_count", 0),
        "reject_count": entry.get("reject_count", 0),
    })
risk_skills.sort(key=lambda r: r.get("risk_score", 0), reverse=True)

def count_canary_by_status(canary_state: dict, target_status: str) -> int:
    return sum(1 for e in canary_state.values() if isinstance(e, dict) and e.get("status") == target_status)

high_risk = [r for r in risk_skills if r.get("risk_tier") in ("high", "critical")]
health_section = {
    "freeze": {
        "enabled": freeze.get("enabled", False),
        "reason": freeze.get("reason", ""),
        "changed_at": freeze.get("changed_at", ""),
    },
    "pending_blacklist": pending_blacklist,
    "pending_blacklist_count": len(pending_blacklist),
    "canary_total": len(canary_list),
    "canary_running": count_canary_by_status(canary_state, "running"),
    "canary_promoted": count_canary_by_status(canary_state, "promoted"),
    "risk_report_generated_at": risk_report.get("generated_at", ""),
    "high_risk_count": len(high_risk),
    "canaries": canary_list[:40],
    "high_risk_skills": high_risk[:20],
}

# --- metrics section ---
series_install: list[float] = []
series_rollback: list[float] = []
series_known: list[int] = []
series_canary: list[int] = []
series_ts: list[str] = []
for row in metric_rows:
    series_ts.append(row.get("timestamp", ""))
    series_install.append(pct(row.get("install_success_rate", 0)))
    series_rollback.append(pct(row.get("rollback_rate", 0)))
    series_known.append(int(row.get("known_total", 0) or 0))
    series_canary.append(int(row.get("canary_total", 0) or 0))

recent_runs = [
    {
        "ts": r.get("timestamp", ""),
        "run_id": r.get("run_id", ""),
        "live": r.get("live", False),
        "vet_score": fp(r.get("vet_score", 0)),
        "install_success_rate": pct(r.get("install_success_rate", 0)),
        "rollback_rate": pct(r.get("rollback_rate", 0)),
        "time_to_decision": fp(r.get("time_to_decision", 0)),
        "known_total": int(r.get("known_total", 0) or 0),
        "canary_total": int(r.get("canary_total", 0) or 0),
    }
    for r in metric_rows[-10:]
]

metrics_section = {
    "weekly": {
        "generated_at": metrics_weekly.get("generated_at", ""),
        "runs": metrics_weekly.get("runs", 0),
        "avg_install_success_rate": pct(metrics_weekly.get("avg_install_success_rate", 0)),
        "avg_rollback_rate": pct(metrics_weekly.get("avg_rollback_rate", 0)),
        "avg_promotion_rate": pct(metrics_weekly.get("avg_promotion_rate_canary_to_active", 0)),
        "avg_time_to_decision": fp(metrics_weekly.get("avg_time_to_decision", 0)),
        "avg_false_positive_rate": pct(metrics_weekly.get("avg_false_positive_rate_vetting", 0)),
    },
    "series": {
        "timestamps": series_ts,
        "install_success_pct": series_install,
        "rollback_rate_pct": series_rollback,
        "known_total": series_known,
        "canary_total": series_canary,
    },
    "recent_runs": recent_runs,
    "total_runs": len(metric_rows),
}

payload = {
    "updated_at": utc_now_iso(),
    "scout": scout_section,
    "health": health_section,
    "metrics": metrics_section,
}

dest.parent.mkdir(parents=True, exist_ok=True)
fd, tmp = tempfile.mkstemp(prefix=".tmp-state-brief-", suffix=".json", dir=dest.parent)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=True, indent=2)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp, dest)
    os.chmod(dest, 0o644)
finally:
    if os.path.exists(tmp):
        os.unlink(tmp)
PY
