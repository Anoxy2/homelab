#!/usr/bin/env python3

import argparse
import json
import math
import statistics
import subprocess
import time
from pathlib import Path

ROOT = Path("/home/steges")
RETRIEVE = ROOT / "agent/skills/openclaw-rag/scripts/retrieve.py"
DEFAULT_GOLD = ROOT / "agent/skills/openclaw-rag/GOLD-SET.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate RAG retrieval against a local gold set.")
    parser.add_argument("--gold-set", type=Path, default=DEFAULT_GOLD, help="Path to GOLD-SET.json")
    parser.add_argument("--limit", type=int, default=5, help="Top-k cutoff")
    parser.add_argument("--timeout-ms", type=int, default=1500, help="Timeout forwarded to retrieve.py")
    parser.add_argument(
        "--disable-rewrite-ab",
        action="store_true",
        help="Skip additional A/B run without query rewrites (faster evaluation, less insight)",
    )
    return parser.parse_args()


def source_matches(source: str, expected: str) -> bool:
    source = source.strip()
    expected = expected.strip()
    return source == expected or source.endswith(expected)


def run_retrieve(query: str, limit: int, timeout_ms: int, disable_rewrites: bool = False) -> tuple[dict | None, float, str, bool]:
    cmd = [
        "python3",
        str(RETRIEVE),
        query,
        "--limit",
        str(limit),
        "--timeout-ms",
        str(timeout_ms),
    ]
    if disable_rewrites:
        cmd.append("--disable-rewrites")

    started = time.perf_counter()
    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        check=False,
    )
    elapsed_ms = round((time.perf_counter() - started) * 1000.0, 2)

    payload = None
    warning = ""
    if proc.returncode == 0 and proc.stdout.strip():
        try:
            payload = json.loads(proc.stdout)
            warning = str(payload.get("warning", ""))
        except json.JSONDecodeError as exc:
            warning = f"invalid-json: {exc}"
    else:
        warning = (proc.stderr or proc.stdout or "retrieve-failed").strip()

    low_warning = warning.lower()
    timed_out = "timeout" in low_warning or "interrupted" in low_warning
    return payload, elapsed_ms, warning, timed_out


def question_metrics(payload: dict | None, expected_evidence: list[str], limit: int) -> tuple[float, float, list[str], list[str]]:
    results = payload.get("results", []) if payload else []
    matched_expected = set()
    relevant_hits = 0
    top_sources = []

    for item in results[:limit]:
        source = str(item.get("source", ""))
        top_sources.append(source)
        for expected in expected_evidence:
            if source_matches(source, expected):
                relevant_hits += 1
                matched_expected.add(expected)
                break

    precision = (relevant_hits / limit) if limit else 0.0
    recall = (len(matched_expected) / len(expected_evidence)) if expected_evidence else 0.0
    return precision, recall, sorted(matched_expected), top_sources


def evaluate_question(query: str, expected_evidence: list[str], limit: int, timeout_ms: int) -> dict:
    payload, elapsed_ms, warning, timed_out = run_retrieve(query, limit, timeout_ms, disable_rewrites=False)
    precision, recall, matched_expected, top_sources = question_metrics(payload, expected_evidence, limit)

    search_mode = payload.get("search_mode") if payload else None
    rewrite_count = len(payload.get("query_rewrites", [])) if payload else 0

    return {
        "query": query,
        "expected_evidence": expected_evidence,
        "latency_ms": elapsed_ms,
        "precision_at_k": round(precision, 4),
        "recall_at_k": round(recall, 4),
        "matched_expected": matched_expected,
        "top_sources": top_sources,
        "warning": warning,
        "timed_out": timed_out,
        "search_mode": search_mode,
        "query_rewrites": payload.get("query_rewrites", []) if payload else [],
        "rewrite_count": rewrite_count,
    }


def percentile(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    if len(values) == 1:
        return float(values[0])
    values = sorted(float(v) for v in values)
    index = math.ceil(p * len(values)) - 1
    index = max(0, min(index, len(values) - 1))
    return round(values[index], 2)


def main() -> int:
    args = parse_args()
    data = json.loads(args.gold_set.read_text(encoding="utf-8"))
    questions = data.get("questions", [])

    rows = []
    for item in questions:
        rows.append(
            {
                "id": item.get("id"),
                **evaluate_question(item["query"], item.get("expected_evidence", []), args.limit, args.timeout_ms),
            }
        )

    if not args.disable_rewrite_ab:
        for row in rows:
            payload_no_rw, _, warning_no_rw, _ = run_retrieve(
                row["query"],
                args.limit,
                args.timeout_ms,
                disable_rewrites=True,
            )
            precision_no_rw, recall_no_rw, _, _ = question_metrics(
                payload_no_rw,
                row["expected_evidence"],
                args.limit,
            )
            row["ab_no_rewrite"] = {
                "precision_at_k": round(precision_no_rw, 4),
                "recall_at_k": round(recall_no_rw, 4),
                "search_mode": payload_no_rw.get("search_mode") if payload_no_rw else None,
                "warning": warning_no_rw,
            }
            row["rewrite_effect"] = {
                "delta_precision_at_k": round(float(row["precision_at_k"]) - precision_no_rw, 4),
                "delta_recall_at_k": round(float(row["recall_at_k"]) - recall_no_rw, 4),
            }

    precisions = [float(r["precision_at_k"]) for r in rows]
    recalls = [float(r["recall_at_k"]) for r in rows]
    latencies = [float(r["latency_ms"]) for r in rows]
    timeout_count = sum(1 for r in rows if bool(r.get("timed_out")))

    mode_counts: dict[str, int] = {}
    fallback_count = 0
    for row in rows:
        mode = str(row.get("search_mode") or "none")
        mode_counts[mode] = mode_counts.get(mode, 0) + 1
        if mode != "fts":
            fallback_count += 1

    rewrite_count_total = sum(int(r.get("rewrite_count", 0)) for r in rows)
    rewrite_questions = sum(1 for r in rows if int(r.get("rewrite_count", 0)) > 0)

    rewrite_delta_precision_values = [
        float(r.get("rewrite_effect", {}).get("delta_precision_at_k", 0.0))
        for r in rows
        if "rewrite_effect" in r
    ]
    rewrite_delta_recall_values = [
        float(r.get("rewrite_effect", {}).get("delta_recall_at_k", 0.0))
        for r in rows
        if "rewrite_effect" in r
    ]

    payload = {
        "gold_set": str(args.gold_set),
        "question_count": len(rows),
        "k": args.limit,
        "timeout_ms": args.timeout_ms,
        "avg_precision_at_k": round(statistics.mean(precisions), 4) if precisions else 0.0,
        "avg_recall_at_k": round(statistics.mean(recalls), 4) if recalls else 0.0,
        "p95_latency_ms": percentile(latencies, 0.95),
        "questions_with_full_recall": sum(1 for r in rows if float(r["recall_at_k"]) >= 1.0),
        "latency": {
            "p50_ms": percentile(latencies, 0.50),
            "p90_ms": percentile(latencies, 0.90),
            "p95_ms": percentile(latencies, 0.95),
            "p99_ms": percentile(latencies, 0.99),
            "max_ms": round(max(latencies), 2) if latencies else 0.0,
            "mean_ms": round(statistics.mean(latencies), 2) if latencies else 0.0,
            "timeout_count": timeout_count,
        },
        "search_mode_counts": mode_counts,
        "fallback": {
            "count": fallback_count,
            "ratio": round((fallback_count / len(rows)), 4) if rows else 0.0,
        },
        "rewrite": {
            "ab_enabled": not args.disable_rewrite_ab,
            "rewrite_count_total": rewrite_count_total,
            "questions_with_rewrites": rewrite_questions,
            "avg_delta_precision_at_k": round(statistics.mean(rewrite_delta_precision_values), 4)
            if rewrite_delta_precision_values
            else 0.0,
            "avg_delta_recall_at_k": round(statistics.mean(rewrite_delta_recall_values), 4)
            if rewrite_delta_recall_values
            else 0.0,
            "better_recall_questions": sum(1 for d in rewrite_delta_recall_values if d > 0),
            "worse_recall_questions": sum(1 for d in rewrite_delta_recall_values if d < 0),
        },
        "results": rows,
    }
    print(json.dumps(payload, ensure_ascii=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
