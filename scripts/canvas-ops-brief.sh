#!/bin/bash
set -euo pipefail

ROOT="/home/steges"
OUT="$ROOT/infra/canvas/html/ops-brief.latest.json"

python3 - "$ROOT" "$OUT" <<'PY'
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
dest = Path(sys.argv[2])

open_work_path = root / "docs/operations/open-work-todo.md"
handover_path = root / "docs/operations/session-handover.md"
decisions_dir = root / "docs/decisions"
runbooks_dir = root / "docs/runbooks"


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def rel(path: Path) -> str:
    return str(path.relative_to(root))


def read_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines()


def clean(text: str) -> str:
    return " ".join(text.strip().split())


def first_heading(lines: list[str]) -> str:
    for line in lines:
        if line.startswith("# "):
            return clean(line[2:])
    return ""


def first_paragraph(lines: list[str]) -> str:
    paragraph: list[str] = []
    for raw in lines:
        line = raw.strip()
        if not line:
            if paragraph:
                break
            continue
        if line.startswith("#"):
            if paragraph:
                break
            continue
        if re.match(r"^[-*]\s+", line) or re.match(r"^\d+\.\s+", line):
            if paragraph:
                break
            continue
        paragraph.append(line)
    return clean(" ".join(paragraph))


def section_lines(lines: list[str], heading_prefix: str) -> list[str]:
    target = heading_prefix.lower()
    active = False
    collected: list[str] = []
    for raw in lines:
        line = raw.rstrip("\n")
        stripped = line.strip()
        if stripped.startswith("## "):
            heading = stripped[3:].strip().lower()
            if active:
                break
            active = heading.startswith(target)
            continue
        if active:
            collected.append(line)
    return collected


def ordered_items(lines: list[str]) -> list[str]:
    items: list[str] = []
    for raw in lines:
        stripped = raw.strip()
        match = re.match(r"^\d+\.\s+(.*)$", stripped)
        if match:
            items.append(clean(match.group(1)))
    return items


def bullet_items(lines: list[str], limit: int | None = None) -> list[str]:
    items: list[str] = []
    for raw in lines:
        stripped = raw.strip()
        match = re.match(r"^[-*]\s+(.*)$", stripped)
        if match:
            items.append(clean(match.group(1)))
            if limit is not None and len(items) >= limit:
                break
    return items


def infer_runbook_tags(name: str) -> list[str]:
    lowered = name.lower()
    tags: list[str] = []
    for key in ("dns", "openclaw", "esp32", "rag", "pihole", "backup", "recovery"):
        if key in lowered:
            tags.append(key)
    if not tags:
        tags.append("ops")
    return tags


def summarize(text: str, limit: int = 180) -> str:
    clean_text = clean(text)
    if len(clean_text) <= limit:
        return clean_text
    return clean_text[: limit - 1].rstrip() + "..."


def parse_open_work(path: Path) -> dict:
    lines = read_lines(path)
    items: list[dict] = []
    current_section = ""
    for raw in lines:
        stripped = raw.strip()
        if stripped.startswith("## "):
            current_section = stripped[3:].strip()
            continue
        if not stripped.startswith("- "):
            continue
        if current_section == "Offene Arbeit":
            priority = "OPEN"
        elif current_section.startswith("P0"):
            priority = "P0"
        elif current_section.startswith("P1"):
            priority = "P1"
        else:
            continue
        items.append({
            "priority": priority,
            "section": current_section,
            "text": clean(stripped[2:]),
        })

    return {
        "source_path": rel(path),
        "items": items,
        "counts": {
            "open": sum(1 for item in items if item["priority"] == "OPEN"),
            "p0": sum(1 for item in items if item["priority"] == "P0"),
            "p1": sum(1 for item in items if item["priority"] == "P1"),
            "total": len(items),
        },
    }


def parse_handover(path: Path) -> dict:
    lines = read_lines(path)
    order = ordered_items(section_lines(lines, "Reihenfolge"))
    start_check = ordered_items(section_lines(lines, "Start-Check"))
    end_check = ordered_items(section_lines(lines, "Abschluss vor Session-Ende"))
    return {
        "source_path": rel(path),
        "order": order,
        "start_check": start_check,
        "end_check": end_check,
    }


def parse_decision(path: Path) -> dict:
    lines = read_lines(path)
    text = "\n".join(lines)
    title = first_heading(lines) or path.stem.replace("-", " ").title()
    summary = first_paragraph(lines)

    outcome = ""
    match = re.search(r"Entscheidung:\s*(.+)", text, flags=re.IGNORECASE)
    if match:
        outcome = clean(match.group(1).replace("*", "").replace("`", ""))
    if not outcome:
        result_lines = section_lines(lines, "Ergebnis")
        result_text = first_paragraph(result_lines) or " ".join(bullet_items(result_lines, limit=1))
        outcome = clean(result_text)
    if not summary:
        summary = outcome

    reevaluate_lines = section_lines(lines, "Re-Evaluationskriterium")
    review_hint = " ".join(ordered_items(reevaluate_lines) or bullet_items(reevaluate_lines, limit=2))
    return {
        "title": title,
        "slug": path.stem,
        "source_path": rel(path),
        "summary": summarize(summary),
        "outcome": summarize(outcome or summary, limit=140),
        "review_hint": summarize(review_hint, limit=140),
        "needs_review": bool(review_hint),
    }


def parse_runbook(path: Path) -> dict:
    lines = read_lines(path)
    title = first_heading(lines) or path.stem.replace("-", " ").title()
    summary = first_paragraph(lines)
    bullets = bullet_items(lines, limit=2)
    if not summary and bullets:
        summary = bullets[0]
    return {
        "title": title,
        "slug": path.stem,
        "source_path": rel(path),
        "summary": summarize(summary),
        "first_steps": bullets,
        "tags": infer_runbook_tags(path.stem),
    }


decisions = [parse_decision(path) for path in sorted(decisions_dir.glob("*.md"))]
runbooks = [parse_runbook(path) for path in sorted(runbooks_dir.glob("*.md"))]
open_work = parse_open_work(open_work_path)
handover = parse_handover(handover_path)

payload = {
    "updated_at": utc_now_iso(),
    "operations": {
        "open_work": open_work,
        "handover": handover,
        "kpis": {
            "open_total": open_work["counts"]["total"],
            "p0": open_work["counts"]["p0"],
            "p1": open_work["counts"]["p1"],
            "start_checks": len(handover["start_check"]),
            "end_checks": len(handover["end_check"]),
        },
        "source_paths": [open_work["source_path"], handover["source_path"]],
    },
    "decisions": {
        "count": len(decisions),
        "review_count": sum(1 for item in decisions if item["needs_review"]),
        "items": decisions,
    },
    "runbooks": {
        "count": len(runbooks),
        "items": runbooks,
    },
}

dest.parent.mkdir(parents=True, exist_ok=True)
fd, tmp = tempfile.mkstemp(prefix=".tmp-ops-brief-", suffix=".json", dir=dest.parent)
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
