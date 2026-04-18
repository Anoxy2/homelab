#!/bin/bash

# status.sh - Statusausgabe fuer RAG Index/Embed-Service

status_cmd() {
  python3 - "$DB_PATH" "$EMBED_HEALTH" <<'PY'
import json, sqlite3, sys, urllib.request
from datetime import datetime, timezone
from pathlib import Path

db_path = Path(sys.argv[1])
embed_health_url = sys.argv[2]

result = {
    "db_exists": False,
    "db_size_kb": 0,
    "sources": 0,
    "chunks_total": 0,
    "chunks_with_vectors": 0,
    "vector_coverage_pct": 0.0,
    "index_age_hours": None,
    "last_ingest_at": None,
    "last_embed_backfill_at": None,
    "embed_service": "unknown",
    "snapshots": 0,
    "warnings": [],
}

try:
    with urllib.request.urlopen(embed_health_url, timeout=3) as r:
        h = json.loads(r.read())
        result["embed_service"] = "healthy" if h.get("status") == "ok" else "degraded"
except Exception:
    result["embed_service"] = "unreachable"

if not db_path.exists():
    result["warnings"].append("index.db does not exist — run reindex first")
    print(json.dumps(result, indent=2))
    sys.exit(0)

result["db_exists"] = True
result["db_size_kb"] = round(db_path.stat().st_size / 1024)

snapshot_dir = db_path.parent / "snapshots"
if snapshot_dir.exists():
    result["snapshots"] = len(list(snapshot_dir.glob("index.db.*")))

try:
    vec_available = False
    conn = sqlite3.connect(str(db_path))
    try:
        import sqlite_vec
        conn.enable_load_extension(True)
        sqlite_vec.load(conn)
        conn.enable_load_extension(False)
        vec_available = True
    except Exception:
        pass

    result["sources"] = conn.execute("SELECT COUNT(DISTINCT source) FROM chunks").fetchone()[0]
    result["chunks_total"] = conn.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]

    if vec_available:
        try:
            result["chunks_with_vectors"] = conn.execute("SELECT COUNT(*) FROM chunk_vectors").fetchone()[0]
        except Exception:
            result["chunks_with_vectors"] = 0
    else:
        result["chunks_with_vectors"] = 0
        result["warnings"].append("sqlite-vec not available — vector stats unavailable")

    total = result["chunks_total"]
    vecs = result["chunks_with_vectors"]
    result["vector_coverage_pct"] = round(vecs / total * 100, 1) if total else 0.0

    meta = dict(conn.execute("SELECT key, value FROM index_meta").fetchall())
    result["last_ingest_at"] = meta.get("last_ingest_at")
    result["last_embed_backfill_at"] = meta.get("last_embed_backfill_at")

    if result["last_ingest_at"]:
        ts = result["last_ingest_at"].replace("Z", "+00:00")
        try:
            last = datetime.fromisoformat(ts).replace(tzinfo=timezone.utc)
            age = (datetime.now(timezone.utc) - last).total_seconds() / 3600.0
            result["index_age_hours"] = round(age, 1)
            if age > 24:
                result["warnings"].append(f"index stale: {age:.0f}h since last ingest")
        except Exception:
            pass

    conn.close()

    if result["vector_coverage_pct"] < 95:
        result["warnings"].append(
            f"vector coverage low: {result['vector_coverage_pct']}% "
            f"({result['chunks_with_vectors']}/{result['chunks_total']}) — run: ingest.py --embed-backfill"
        )

except Exception as e:
    result["warnings"].append(f"db-error: {e}")

print(json.dumps(result, indent=2))
PY
}
