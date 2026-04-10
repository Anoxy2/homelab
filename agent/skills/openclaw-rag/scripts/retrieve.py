#!/usr/bin/env python3

import argparse
import json
import re
import sqlite3
import time
from datetime import datetime, timezone
from pathlib import Path


DB_PATH = Path("/home/steges/infra/openclaw-data/rag/index.db")
SNAPSHOT_DIR = Path("/home/steges/infra/openclaw-data/rag/snapshots")
EMBED_URL = "http://192.168.2.101:18790/embed"

STOPWORDS = {
    "aus", "auf", "bei", "das", "dem", "den", "der", "des", "die",
    "ein", "eine", "einer", "eines", "es", "fuer", "fuehre", "gelten",
    "gibt", "hat", "ich", "ist", "mit", "nach", "oder", "und", "von",
    "was", "welche", "welcher", "welches", "welchen", "wie", "wir",
    "zu", "sieht",
}

# Keyword-Aliases: nur expandieren wenn FTS-Treffer schwach (lazy expansion)
KEYWORD_ALIASES = {
    "ausfall": ["down", "stoerung", "dns-ausfall", "recovery"],
    "down": ["ausfall", "stoerung", "recovery"],
    "stoerung": ["ausfall", "down", "problem"],
    "wiederherstellung": ["recovery", "restore", "rollback"],
    "recovery": ["wiederherstellung", "restore", "rollback"],
    "restore": ["wiederherstellung", "recovery", "rollback"],
    "zielwerte": ["thresholds", "sollwerte", "alarme"],
    "sollwerte": ["zielwerte", "thresholds"],
    "alarmgrenzen": ["thresholds", "alarme", "schwellwerte", "grenzen"],
    "schwellwerte": ["thresholds", "alarmgrenzen", "alarme"],
    "alarme": ["alarmgrenzen", "thresholds", "schwellwerte"],
    "ports": ["port", "dienste", "services"],
    "port": ["ports", "dienste", "services"],
    "dienste": ["services", "service", "ports"],
    "service": ["services", "dienste", "ports"],
    "check": ["heartbeat", "status", "runbook"],
    "playbook": ["runbook", "checklist", "aktualisieren"],
    "risiken": ["risiko", "sicherheit", "security"],
    "risiko": ["risiken", "sicherheit", "security"],
    "services": ["service", "ports"],
    "update": ["aktualisieren", "wartung"],
    "wartung": ["maintenance", "update", "playbook"],
    "tagebuch": ["diary", "growbox", "daily"],
    "diary": ["tagebuch", "daily", "growbox"],
    "heartbeat": ["openclaw", "health", "daily-health"],
    "lifecycle": ["install", "update", "rollback", "promote", "canary"],
    "trennung": ["separation", "grenze", "boundary"],
    "separation": ["trennung", "grenze", "wrapper"],
    # Identity / self-awareness queries
    "bist": ["self-model", "identity", "identitaet", "openclaw"],
    "identitaet": ["identity", "self-model", "openclaw"],
    "identity": ["identitaet", "self-model", "openclaw"],
    # Skill inventory queries
    "inventory": ["skill-inventory", "skills", "liste"],
    "aufgebaut": ["architecture", "architektur", "system-overview", "komponenten"],
    "komponenten": ["architecture", "system-overview", "services"],
    "geaendert": ["changelog", "history", "historie"],
    "verbessert": ["changelog", "history", "historie"],
    "wochen": ["history", "historie", "changelog"],
    "taeglichen": ["daily", "skill-forge", "policy", "lint"],
    "daily": ["taeglichen", "skill-forge", "policy", "lint"],
    "skillmanager": ["skill-forge", "policy", "lint", "status"],
    "manager": ["skill-forge", "policy", "lint", "status"],
    "skillstruktur": ["handover", "changelog", "skill-structure-check"],
    "repo": ["handover", "changelog", "skill-forge"],
    "kommuniziert": ["handshake", "telegram", "openclaw-communication"],
    "umgekehrt": ["handshake", "telegram"],
    "macht": ["zweck", "purpose"],
}

# Minimale FTS-Trefferanzahl unter der Aliases aktiviert werden
def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Query the local RAG index (FTS + optional Hybrid).")
    parser.add_argument("query", help="Search query")
    parser.add_argument("--db", type=Path, default=DB_PATH, help="SQLite index path")
    parser.add_argument("--limit", type=int, default=5, help="Maximum result count")
    parser.add_argument(
        "--timeout-ms",
        type=int,
        default=1500,
        help="Per-query timeout in milliseconds",
    )
    parser.add_argument(
        "--disable-rewrites",
        action="store_true",
        help="Disable keyword alias rewrites",
    )
    parser.add_argument(
        "--no-hybrid",
        action="store_true",
        help="Disable hybrid search even if embedding service is available",
    )
    return parser.parse_args()


def latest_snapshot_db() -> Path | None:
    if not SNAPSHOT_DIR.exists():
        return None
    candidates = sorted(SNAPSHOT_DIR.glob("index.db.*"), key=lambda p: p.stat().st_mtime, reverse=True)
    return candidates[0] if candidates else None


def configure_connection(conn: sqlite3.Connection, timeout_ms: int) -> None:
    conn.execute(f"PRAGMA busy_timeout={max(timeout_ms, 1)}")
    conn.execute("PRAGMA temp_store=MEMORY")
    conn.execute("PRAGMA cache_size=-20000")
    conn.execute("PRAGMA mmap_size=134217728")


def load_sqlite_vec(conn: sqlite3.Connection) -> bool:
    """sqlite-vec laden — gibt False zurück wenn nicht verfügbar."""
    try:
        import sqlite_vec
        conn.enable_load_extension(True)
        sqlite_vec.load(conn)
        conn.enable_load_extension(False)
        return True
    except Exception:
        return False


def fetchall_with_timeout(
    conn: sqlite3.Connection,
    sql: str,
    params: tuple[object, ...],
    timeout_ms: int,
) -> list[tuple[object, ...]]:
    deadline = time.monotonic() + (max(timeout_ms, 1) / 1000.0)

    def progress_handler() -> int:
        return 1 if time.monotonic() >= deadline else 0

    conn.set_progress_handler(progress_handler, 2000)
    try:
        return conn.execute(sql, params).fetchall()
    except sqlite3.OperationalError as exc:
        if "interrupted" in str(exc).lower():
            raise TimeoutError(f"query timeout after {timeout_ms}ms") from exc
        raise
    finally:
        conn.set_progress_handler(None, 0)


def extract_keywords(query: str, allow_aliases: bool = True) -> tuple[list[str], list[str], list[dict[str, object]]]:
    """
    Gibt zurück: (terms_with_aliases, raw_terms_only, rewrites)
    raw_terms_only: Terme ohne Alias-Expansion (für lazy-first-pass)
    """
    lowered = query.lower()
    raw_terms: list[str] = []
    rewrites: list[dict[str, object]] = []

    def add_raw(term: str) -> None:
        if len(term) <= 2 or term in STOPWORDS or term in raw_terms:
            return
        raw_terms.append(term)

    for raw_term in re.findall(r"[\w.-]+", lowered):
        collapsed = re.sub(r"[-.]", "", raw_term)
        parts = re.split(r"[-.]", raw_term)
        add_raw(collapsed)
        for part in parts:
            add_raw(part)

    if not allow_aliases:
        return raw_terms, raw_terms, []

    # Aliases sammeln
    terms_with_aliases = list(raw_terms)
    for term in list(raw_terms):
        aliases = KEYWORD_ALIASES.get(term, [])
        if aliases:
            rewrites.append({"term": term, "aliases": aliases})
            for alias in aliases:
                if alias not in terms_with_aliases:
                    terms_with_aliases.append(alias)

    return terms_with_aliases, raw_terms, rewrites


def build_fts_query(terms: list[str]) -> str:
    if not terms:
        return '""'
    return " OR ".join(f'"{term}"' for term in terms)


def diary_recency_boost(source: str) -> float:
    match = re.search(r"/growbox/diary/(\d{2})\.(\d{2})\.(\d{4})\.md$", source)
    if not match:
        return 0.0
    try:
        day, month, year = int(match.group(1)), int(match.group(2)), int(match.group(3))
        diary_dt = datetime(year, month, day)
        age_days = max(0, (datetime.now(timezone.utc).replace(tzinfo=None) - diary_dt).days)
    except ValueError:
        return 0.0
    if age_days == 0:
        return 10.0
    if age_days == 1:
        return 8.0
    if age_days <= 3:
        return 5.0
    if age_days <= 7:
        return 2.0
    return 0.0


def exact_path_boost(source: str, keywords: list[str]) -> float:
    """Boost wenn Query-Terms exakt auf Datei-/Verzeichnisnamen passen."""
    boost = 0.0
    path = Path(source)
    stem = path.stem.lower().replace("-", "").replace("_", "")
    parts_lower = [p.lower() for p in path.parts]

    for kw in keywords:
        kw_clean = kw.lower().replace("-", "").replace("_", "")
        if len(kw_clean) < 3:
            continue
        # Exakter Dateiname-Match (ohne Extension)
        if kw_clean == stem:
            boost += 12.0
        elif kw_clean in stem and len(kw_clean) >= 5:
            boost += 5.0
        # Verzeichnisname-Match
        for part in parts_lower:
            part_clean = part.replace("-", "").replace("_", "")
            if kw_clean == part_clean and len(kw_clean) >= 4:
                boost += 4.0
    return boost


def autodoc_penalty(source: str, text: str) -> float:
    """Generated Auto-Doc soll im Index bleiben, aber hinter Primärquellen ranken."""
    lowered_source = source.lower()
    lowered_text = text.lower()
    penalty = 0.0

    if "doc_keeper_auto_start" in lowered_text or "generated by: rag-dispatch.sh autodoc" in lowered_text:
        penalty += 10.0
    if "generiert von openclaw autodoc" in lowered_text:
        penalty += 6.0

    # Diese Dateien sollen retrieval-fähig bleiben, aber im Zweifel eher als zusammenfassende
    # Sekundärquelle dienen statt Primärbeleg zu verdrängen.
    if lowered_source.endswith((
        "/agent/self-model.md",
        "/agent/system-state.md",
        "/agent/skill-inventory.md",
        "/agent/history.md",
        "/agent/to-do.md",
        "/growbox/grow-summary.md",
    )):
        penalty += 2.5

    if "/agent/skills/" in lowered_source and "/agents/" in lowered_source:
        penalty += 6.0
    if "/agent/skills/" in lowered_source and "/references/" in lowered_source:
        penalty += 4.0
    if lowered_source.endswith("/.learnings/learnings.md"):
        penalty += 4.0

    return penalty


def intent_source_boost(source: str, keywords: list[str], query: str) -> float:
    """Leichte, intent-basierte Boosts fuer bekannte Operator-Queries."""
    src = source.lower()
    q = query.lower()
    kw = {k.lower() for k in keywords}
    boost = 0.0

    # Heartbeat-Fragen sollen primär zur Skill-Doku, nicht zur allgemeinen Template-Datei.
    if "heartbeat" in kw:
        if src.endswith("/agent/skills/heartbeat/skill.md"):
            boost += 12.0
        if src.endswith("/agent/heartbeat.md"):
            boost -= 8.0

    # Änderungs-/Historienfragen priorisieren HISTORY + CHANGELOG.
    if kw.intersection({"geaendert", "verbessert", "wochen", "history", "historie", "changelog"}):
        if src.endswith("/agent/history.md"):
            boost += 8.0
        if src.endswith("/changelog.md"):
            boost += 8.0

    # Skill-Forge Daily/Checks priorisieren Governance-Doku.
    if kw.intersection({"skillmanager", "skillforge", "manager", "daily", "taeglichen", "check", "policy", "lint"}):
        if src.endswith("/docs/skills/skill-forge-governance.md"):
            boost += 8.0
        if src.endswith("/agent/skills/skill-forge/skill.md"):
            boost += 7.0

    # Struktur-/Repo-Checks referenzieren im Betrieb v. a. Handover/Changelog.
    if kw.intersection({"skillstruktur", "struktur", "repo", "pruefe"}):
        if src.endswith("/docs/operations/session-handover.md"):
            boost += 6.0
        if src.endswith("/changelog.md"):
            boost += 4.0

    # Kommunikationsfragen: Handshake + Kommunikationsdoku.
    if kw.intersection({"kommuniziert", "umgekehrt", "telegram", "handshake"}):
        if src.endswith("/agent/handshake.md"):
            boost += 8.0
        if src.endswith("/docs/openclaw/openclaw-communication.md"):
            boost += 6.0

    # Wrapper-Separation explizit.
    if "scripts/skills" in q and "scripts/skill-forge" in q:
        if src.endswith("/docs/skills/skill-forge-governance.md"):
            boost += 9.0
        if src.endswith("/agent/handshake.md"):
            boost += 7.0

    # Sicherheits-/Pi-hole-Risiko-Fragen.
    if kw.intersection({"risiko", "risiken", "sicherheit", "security", "pihole"}):
        if src.endswith("/docs/core/security-baseline.md"):
            boost += 6.0
        if src.endswith("/claude.md"):
            boost += 4.0

    return boost


def filter_existing_sources(results: list[dict[str, object]]) -> tuple[list[dict[str, object]], list[str]]:
    filtered: list[dict[str, object]] = []
    stale: list[str] = []
    for item in results:
        source = str(item.get("source", ""))
        if source and Path(source).exists():
            filtered.append(item)
        else:
            stale.append(source)
    return filtered, stale


def rerank_results(
    results: list[dict[str, object]],
    keywords: list[str],
    query: str,
    limit: int,
) -> list[dict[str, object]]:
    reranked: list[dict[str, object]] = []
    for item in results:
        source = str(item["source"]).lower()
        section = str(item.get("section", "")).lower()
        text = str(item["text"]).lower()
        score = float(item["score"])

        matched_keywords = 0
        for keyword in keywords:
            source_hits = min(source.count(keyword), 1)
            section_hits = min(section.count(keyword), 1)
            text_hits = min(text.count(keyword), 2)
            if source_hits or section_hits or text_hits:
                matched_keywords += 1
            score += source_hits * 3.0
            score += section_hits * 4.0
            score += text_hits * 1.2

        score += matched_keywords * 5.0
        score += diary_recency_boost(source)
        score += exact_path_boost(source, keywords)
        score += intent_source_boost(source, keywords, query)
        score -= autodoc_penalty(source, text)

        reranked.append({**item, "score": round(score, 6)})

    reranked.sort(key=lambda x: float(x["score"]), reverse=True)

    # Deduplication: max 1 chunk per source to force result diversity
    seen_sources: set[str] = set()
    deduplicated: list[dict[str, object]] = []
    for item in reranked:
        src = str(item["source"])
        if src not in seen_sources:
            deduplicated.append(item)
            seen_sources.add(src)
        if len(deduplicated) >= limit:
            break

    return deduplicated


def fts_results(
    conn: sqlite3.Connection,
    terms: list[str],
    limit: int,
    timeout_ms: int,
) -> list[dict[str, object]]:
    sql = """
        SELECT c.source, c.section, c.chunk_index, c.text, -bm25(chunks_fts) AS score
        FROM chunks_fts
        JOIN chunks c ON c.id = chunks_fts.rowid
        WHERE chunks_fts MATCH ?
        ORDER BY bm25(chunks_fts)
        LIMIT ?
    """
    rows = fetchall_with_timeout(conn, sql, (build_fts_query(terms), max(limit * 20, 100)), timeout_ms)
    return [
        {
            "source": row[0], "section": row[1], "chunk_index": row[2],
            "score": round(float(row[4]), 6), "text": row[3],
        }
        for row in rows
    ]


def like_results(
    conn: sqlite3.Connection,
    query: str,
    limit: int,
    timeout_ms: int,
) -> list[dict[str, object]]:
    words = [w for w in re.findall(r"[\w.-]+", query.lower()) if len(w) > 1 and w not in STOPWORDS]
    words = list(dict.fromkeys(words))[:12]
    if not words:
        return []
    score_expr = " + ".join(["(instr(lower(c.text), ?) > 0)"] * len(words))
    where_expr = " OR ".join(["instr(lower(c.text), ?) > 0"] * len(words))
    sql = f"""
        SELECT c.source, c.section, c.chunk_index, c.text, ({score_expr}) AS score
        FROM chunks c
        WHERE {where_expr}
        ORDER BY score DESC, c.updated_at DESC
        LIMIT ?
    """
    params: tuple[object, ...] = tuple(words + words + [max(limit * 20, 100)])
    rows = fetchall_with_timeout(conn, sql, params, timeout_ms)
    return [
        {
            "source": row[0], "section": row[1], "chunk_index": row[2],
            "score": float(row[4]), "text": row[3],
        }
        for row in rows
    ]


def embed_query(query: str, timeout_ms: int) -> list[float] | None:
    """Query embedden — None wenn Service nicht erreichbar."""
    try:
        import urllib.request
        payload = json.dumps({"texts": [query]}).encode()
        req = urllib.request.Request(
            EMBED_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=max(timeout_ms, 500) / 1000.0) as resp:
            data = json.loads(resp.read())
            return data["vectors"][0]
    except Exception:
        return None


def vector_results(
    conn: sqlite3.Connection,
    query_vec: list[float],
    limit: int,
    timeout_ms: int,
) -> list[dict[str, object]]:
    """ANN-Suche via sqlite-vec chunk_vec_idx."""
    import struct
    blob = struct.pack(f"{len(query_vec)}f", *query_vec)
    try:
        rows = fetchall_with_timeout(
            conn,
            """
            SELECT cv.chunk_id, vec_distance_cosine(cv.embedding, ?) AS distance
            FROM chunk_vectors cv
            ORDER BY distance
            LIMIT ?
            """,
            (blob, max(limit * 5, 50)),
            timeout_ms,
        )
    except (sqlite3.OperationalError, TimeoutError):
        return []

    if not rows:
        return []

    chunk_ids = {int(row[0]): 1.0 - float(row[1]) for row in rows}
    placeholders = ",".join("?" * len(chunk_ids))
    chunk_rows = conn.execute(
        f"SELECT id, source, section, chunk_index, text FROM chunks WHERE id IN ({placeholders})",
        list(chunk_ids.keys()),
    ).fetchall()
    return [
        {
            "source": r[1], "section": r[2], "chunk_index": r[3],
            "score": round(chunk_ids[r[0]], 6), "text": r[4],
        }
        for r in chunk_rows
    ]


def rrf_merge(
    bm25: list[dict[str, object]],
    vec: list[dict[str, object]],
    k: int = 60,
) -> list[dict[str, object]]:
    """Reciprocal Rank Fusion — keine Score-Normalisierung nötig."""
    scores: dict[str, float] = {}
    store: dict[str, dict[str, object]] = {}

    for rank, item in enumerate(bm25):
        key = f"{item['source']}::{item['chunk_index']}"
        scores[key] = scores.get(key, 0.0) + 1.0 / (k + rank + 1)
        store[key] = item

    for rank, item in enumerate(vec):
        key = f"{item['source']}::{item['chunk_index']}"
        scores[key] = scores.get(key, 0.0) + 1.0 / (k + rank + 1)
        if key not in store:
            store[key] = item

    merged = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    return [{**store[k], "score": round(s * 1000, 6)} for k, s in merged]


def search_db(
    db_path: Path,
    terms_with_aliases: list[str],
    raw_terms: list[str],
    query: str,
    limit: int,
    timeout_ms: int,
    use_hybrid: bool = True,
) -> tuple[list[dict[str, object]], str, str]:
    conn = sqlite3.connect(
        f"file:{db_path}?mode=ro",
        uri=True,
        timeout=max(timeout_ms, 1) / 1000.0,
    )
    configure_connection(conn, timeout_ms)
    vec_available = use_hybrid and load_sqlite_vec(conn)

    try:
        fts_warning = ""
        bm25_rows: list[dict[str, object]] = []

        # --- Raw Terms + Alias Union ---
        # Roh-Treffer bleiben Primärsignal; Alias-Treffer werden ergänzend beigemischt
        # und erst danach im Reranker zusammengeführt.
        try:
            bm25_rows = fts_results(conn, raw_terms, limit, timeout_ms)
            if terms_with_aliases != raw_terms:
                alias_rows = fts_results(conn, terms_with_aliases, limit, timeout_ms)
                merged_rows: dict[tuple[str, int], dict[str, object]] = {}
                for row in bm25_rows + alias_rows:
                    key = (str(row.get("source", "")), int(row.get("chunk_index", 0)))
                    if key not in merged_rows or float(row.get("score", 0.0)) > float(merged_rows[key].get("score", 0.0)):
                        merged_rows[key] = row
                bm25_rows = list(merged_rows.values())
        except (sqlite3.Error, TimeoutError) as exc:
            fts_warning = f"fts-fallback: {exc}"

        # --- Hybrid: BM25 + Vector ---
        if vec_available and bm25_rows:
            query_vec = embed_query(query, min(timeout_ms, 800))
            if query_vec is not None:
                vec_rows = vector_results(conn, query_vec, limit, timeout_ms)
                if vec_rows:
                    merged = rrf_merge(bm25_rows, vec_rows)
                    return merged, "hybrid", fts_warning
            # Embed-Service nicht erreichbar → nur FTS
            if bm25_rows:
                return bm25_rows, "fts", fts_warning

        if bm25_rows:
            return bm25_rows, "fts", fts_warning

        # --- LIKE-Fallback ---
        try:
            like_rows = like_results(conn, query, limit, timeout_ms)
        except (sqlite3.Error, TimeoutError) as exc:
            warn = f"{fts_warning}; like-fallback: {exc}" if fts_warning else f"like-fallback: {exc}"
            return [], "none", warn
        return like_rows, "like", fts_warning

    finally:
        conn.close()


def get_index_age_hours(db_path: Path) -> float | None:
    """Stunden seit letztem Ingest aus index_meta."""
    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=1.0)
        row = conn.execute("SELECT value FROM index_meta WHERE key='last_ingest_at'").fetchone()
        conn.close()
        if not row:
            return None
        ts = row[0].replace("Z", "+00:00")
        from datetime import timezone
        last = datetime.fromisoformat(ts).replace(tzinfo=timezone.utc)
        now = datetime.now(timezone.utc)
        return round((now - last).total_seconds() / 3600.0, 1)
    except Exception:
        return None


def main() -> int:
    args = parse_args()
    terms_with_aliases, raw_terms, rewrites = extract_keywords(
        args.query, allow_aliases=not args.disable_rewrites
    )
    db_used = args.db
    fallback_used = False
    warning = ""
    use_hybrid = not args.no_hybrid

    try:
        results, search_mode, warning = search_db(
            db_used, terms_with_aliases, raw_terms,
            args.query, args.limit, args.timeout_ms, use_hybrid=use_hybrid,
        )
    except sqlite3.Error as exc:
        warning = f"primary-db-error: {exc}"
        results = []
        search_mode = "none"

    if not results:
        snapshot = latest_snapshot_db()
        if snapshot is not None and snapshot != db_used:
            try:
                fb_results, fb_mode, fb_warn = search_db(
                    snapshot, terms_with_aliases, raw_terms,
                    args.query, args.limit, args.timeout_ms, use_hybrid=False,
                )
                if fb_results:
                    results = fb_results
                    search_mode = f"snapshot-{fb_mode}"
                    db_used = snapshot
                    fallback_used = True
                    warning = "; ".join(filter(None, [warning, fb_warn]))
            except sqlite3.Error as exc:
                warning = "; ".join(filter(None, [warning, f"snapshot-db-error: {exc}"]))

    results, stale_sources = filter_existing_sources(results)
    results = rerank_results(results, raw_terms, args.query, args.limit)

    index_age = get_index_age_hours(args.db)
    if index_age is not None and index_age > 24:
        stale_warn = f"index stale: {index_age:.0f}h since last ingest"
        warning = "; ".join(filter(None, [warning, stale_warn]))

    payload = {
        "query": args.query,
        "keywords": raw_terms,
        "terms_with_aliases": terms_with_aliases,
        "search_mode": search_mode,
        "db_used": str(db_used),
        "fallback_used": fallback_used,
        "timeout_ms": args.timeout_ms,
        "query_rewrites": rewrites,
        "index_age_hours": index_age,
        "warning": warning,
        "count": len(results),
        "stale_sources_dropped": stale_sources,
        "results": results,
    }
    print(json.dumps(payload, ensure_ascii=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
