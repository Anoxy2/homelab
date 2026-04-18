#!/bin/bash
set -euo pipefail

ROOT="/home/steges"
STATE_DIR="$ROOT/agent/skills/skill-forge/.state"
SKILLS_DIR="$ROOT/agent/skills"
OUT="$ROOT/agent/skills/openclaw-ui/html/skill-pages.latest.json"

python3 - "$STATE_DIR" "$SKILLS_DIR" "$OUT" <<'PY'
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

state_dir = Path(sys.argv[1])
skills_dir = Path(sys.argv[2])
dest = Path(sys.argv[3])


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def safe_load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def parse_purpose(skill_md: Path) -> str:
    if not skill_md.exists():
        return "No SKILL.md available."
    lines = skill_md.read_text(encoding="utf-8", errors="ignore").splitlines()

    purpose_lines = []
    active = False
    for raw in lines:
        line = raw.strip()
        if line.lower() == "## zweck" or line.lower() == "## purpose":
            active = True
            continue
        if active and line.startswith("## "):
            break
        if active:
            if line and not line.startswith("```"):
                purpose_lines.append(line)
    if purpose_lines:
        return " ".join(purpose_lines)[:500]

    for raw in lines:
        line = raw.strip()
        if line.startswith("description:"):
            return line.split(":", 1)[1].strip().strip('"').strip("'")[:500]

    return "No purpose summary found."


def find_runbook(slug: str) -> str:
    runbooks_dir = Path("/home/steges/docs/runbooks")
    candidates = sorted(runbooks_dir.glob("*.md"))
    low_slug = slug.lower()
    for path in candidates:
        name = path.stem.lower()
        if low_slug in name or name in low_slug:
            return str(path.relative_to(Path("/home/steges")))
    return ""


def action_allowlist(slug: str) -> list[dict]:
    mapping = {
        "learn": [
            {"id": "skills learn weekly --json", "label": "Weekly Distill"},
            {"id": "skills learn show", "label": "Show Learnings"},
        ],
        "openclaw-rag": [
            {"id": "skills rag status", "label": "RAG Status"},
            {"id": "skills rag retrieve \"openclaw heartbeat\" --limit 3", "label": "RAG Smoke Query"},
        ],
        "heartbeat": [
            {"id": "skills heartbeat check", "label": "Heartbeat Check"},
            {"id": "skills heartbeat run --dry", "label": "Heartbeat Dry Run"},
        ],
        "ha-control": [
            {"id": "skills ha-control check", "label": "HA Check"},
            {"id": "skills ha-control list-entities --domain sensor --prefix growbox", "label": "Growbox Entities"},
        ],
        "pi-control": [
            {"id": "skills pi-control status", "label": "Pi Status"},
            {"id": "skills pi-control status-full", "label": "Pi Status Full"},
        ],
    }
    default = [
        {"id": f"skills {slug} --help", "label": "Show Help"}
    ]
    actions = mapping.get(slug, default)
    return [{**a, "enabled": True} for a in actions]


known_skills = safe_load_json(state_dir / "known-skills.json", {})
risk_report = safe_load_json(state_dir / "skill-risk-report.json", {})

risk_map = risk_report.get("skills", {}) if isinstance(risk_report, dict) else {}

local_slugs = []
for p in sorted(skills_dir.iterdir()):
    if p.is_dir() and not p.name.startswith("."):
        local_slugs.append(p.name)

all_slugs = sorted(set(local_slugs) | set(known_skills.keys()))

items = []
for slug in all_slugs:
    entry = known_skills.get(slug, {})
    if not isinstance(entry, dict):
        entry = {}

    skill_md = skills_dir / slug / "SKILL.md"
    purpose = parse_purpose(skill_md)
    risk = risk_map.get(slug, {}) if isinstance(risk_map, dict) else {}

    item = {
        "slug": slug,
        "name": slug,
        "purpose": purpose,
        "status": entry.get("status", "local" if slug in local_slugs else "unknown"),
        "source": entry.get("source", "local" if slug in local_slugs else ""),
        "version": entry.get("version", ""),
        "discovered_at": entry.get("discovered_at", ""),
        "last_scout": entry.get("last_scout", ""),
        "vetting_score": entry.get("vetting_score", 0),
        "risk_tier": risk.get("risk_tier", ""),
        "risk_score": risk.get("risk_score", 0),
        "verdict": risk.get("verdict", ""),
        "actions": action_allowlist(slug),
        "docs": {
            "skill_md": str(skill_md.relative_to(Path("/home/steges"))) if skill_md.exists() else "",
            "runbook": find_runbook(slug),
        },
    }
    items.append(item)

payload = {
    "updated_at": utc_now_iso(),
    "count": len(items),
    "items": items,
}

dest.parent.mkdir(parents=True, exist_ok=True)
fd, tmp = tempfile.mkstemp(prefix=".tmp-skill-pages-", suffix=".json", dir=dest.parent)
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
