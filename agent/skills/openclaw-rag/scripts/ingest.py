#!/usr/bin/env python3

import argparse
import fcntl
import hashlib
import json
import os
import re
import sqlite3
import struct
import sys
import urllib.request
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Iterable


DB_PATH = Path("/home/steges/infra/openclaw-data/rag/index.db")
INGEST_STATE_PATH = Path("/home/steges/infra/openclaw-data/rag/ingest-state.json")
INGEST_LOCK_PATH = Path("/home/steges/infra/openclaw-data/rag/.reindex.lock")
TARGET_TOKENS = 420
OVERLAP_TOKENS = 50
CHUNK_SCHEMA_VERSION = "1.4"  # bump when chunking logic changes
EMBED_URL = "http://192.168.2.101:18790/embed"
EMBED_BATCH_SIZE = 32
EMBED_DIMS = 384
ALLOWED_DIRS = [
    Path("/home/steges/docs"),
    Path("/home/steges/growbox"),
    Path("/home/steges/agent/skills"),  # SKILL.md, agents/*.md, references/*.md per skill
]
ALLOWED_FILES = [
    Path("/home/steges/CLAUDE.md"),
    Path("/home/steges/README.md"),
    Path("/home/steges/CHANGELOG.md"),
    Path("/home/steges/docker-compose.yml"),
    Path("/home/steges/.env.example"),
    Path("/home/steges/caddy/Caddyfile"),
    Path("/home/steges/prometheus/prometheus.yml"),
    Path("/home/steges/prometheus/rules/homelab-alerts.yml"),
    Path("/home/steges/agent/SOUL.md"),
    Path("/home/steges/agent/IDENTITY.md"),
    Path("/home/steges/agent/USER.md"),
    Path("/home/steges/agent/TOOLS.md"),
    Path("/home/steges/agent/HEARTBEAT.md"),
    Path("/home/steges/agent/HANDSHAKE.md"),
    Path("/home/steges/agent/MEMORY.md"),
    Path("/home/steges/agent/LEARNINGS.md"),
    Path("/home/steges/agent/SELF-MODEL.md"),
    Path("/home/steges/agent/SKILL-INVENTORY.md"),
    Path("/home/steges/agent/HISTORY.md"),
    Path("/home/steges/agent/SYSTEM-STATE.md"),
    Path("/home/steges/agent/TO-DO.md"),
    Path("/home/steges/docs/operations/open-work-todo.md"),
    Path("/home/steges/infra/openclaw-data/action-log.jsonl"),
]
EXCLUDED_PATH_PREFIXES = [
    Path("/home/steges/infra/openclaw-data/credentials"),
    Path("/home/steges/agent/skills/openclaw-rag"),      # avoid indexing RAG's own internals
    Path("/home/steges/agent/skills/skill-forge/generated"),  # generated test artifacts, no knowledge value
]
EXCLUDED_PATHS = {
    Path("/home/steges/infra/openclaw-data/identity/device.json"),
}
ACTION_LOG_MAX_LINES = 500
SENSITIVE_PATTERNS = [
    re.compile(pattern, re.IGNORECASE)
    for pattern in (
        r"api[_-]?key\s*[=:]",
        r"token\s*[=:]",
        r"password\s*[=:]",
        r"secret\s*[=:]",
        r"bearer\s+[a-z0-9._-]+",
    )
]


@dataclass
class Section:
    heading: str
    body: str


@dataclass(frozen=True)
class ChunkProfile:
    name: str
    target_tokens: int
    overlap_tokens: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the local RAG FTS + vector index.")
    parser.add_argument("--db", type=Path, default=DB_PATH, help="SQLite index path")
    parser.add_argument(
        "--changed-only",
        action="store_true",
        help="Only re-index files whose checksum changed",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit a JSON summary instead of human-readable text",
    )
    parser.add_argument(
        "--max-chunks-per-run",
        type=int,
        default=0,
        help="Soft chunk budget per run; 0 disables backpressure",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Resume from the saved ingest-state queue if present",
    )
    parser.add_argument(
        "--embed",
        action="store_true",
        help="Generate and store embeddings via rag-embed service",
    )
    parser.add_argument(
        "--embed-backfill",
        action="store_true",
        help="Generate embeddings for ALL chunks missing vectors (regardless of --changed-only)",
    )
    return parser.parse_args()


def acquire_ingest_lock() -> tuple[object, int]:
    """Acquire exclusive non-blocking lock; returns (file_handle, pid_from_file)."""
    INGEST_LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    lock_fp = INGEST_LOCK_PATH.open("a+", encoding="utf-8")

    lock_fp.seek(0)
    existing = lock_fp.read().strip()
    existing_pid = int(existing) if existing.isdigit() else 0

    try:
        fcntl.flock(lock_fp.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        lock_fp.close()
        return None, existing_pid

    lock_fp.seek(0)
    lock_fp.truncate(0)
    lock_fp.write(str(os.getpid()))
    lock_fp.flush()
    return lock_fp, existing_pid


def utc_now() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat()


def token_count(text: str) -> int:
    return len(re.findall(r"\S+", text))


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def load_ingest_state() -> dict[str, object]:
    if not INGEST_STATE_PATH.exists():
        return {}
    try:
        return json.loads(INGEST_STATE_PATH.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}


def save_ingest_state(payload: dict[str, object]) -> None:
    INGEST_STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    INGEST_STATE_PATH.write_text(json.dumps(payload, ensure_ascii=True, indent=2), encoding="utf-8")


def chunk_profile_for_path(path: Path) -> ChunkProfile:
    path_str = str(path)
    if path.name == "action-log.jsonl":
        return ChunkProfile("action-log", 120, 0)
    if "/growbox/diary/" in path_str:
        return ChunkProfile("growbox-diary", 180, 20)
    if "/docs/runbooks/" in path_str:
        return ChunkProfile("runbook", 320, 40)
    if "/docs/" in path_str:
        return ChunkProfile("docs", 420, 50)
    if "/agent/skills/" in path_str:
        return ChunkProfile("skill-doc", 320, 40)
    if "/agent/" in path_str:
        return ChunkProfile("agent-doc", 280, 30)
    return ChunkProfile("default", TARGET_TOKENS, OVERLAP_TOKENS)


def is_allowed(path: Path) -> bool:
    if path.name in {".env", "secrets.yaml", "passwd"}:
        return False
    if path.suffix == ".json" and path.name.endswith(".token.json"):
        return False
    if path in EXCLUDED_PATHS:
        return False
    return not any(prefix in path.parents or path == prefix for prefix in EXCLUDED_PATH_PREFIXES)


def collect_sources() -> list[Path]:
    paths: list[Path] = []
    for directory in ALLOWED_DIRS:
        if directory.exists():
            paths.extend(sorted(path for path in directory.rglob("*.md") if path.is_file()))
    for file_path in ALLOWED_FILES:
        if file_path.exists():
            paths.append(file_path)
    deduped = sorted({path.resolve() for path in paths})
    return [path for path in deduped if is_allowed(path)]


def filter_sensitive_lines(text: str) -> str:
    filtered_lines: list[str] = []
    for line in text.splitlines():
        if any(pattern.search(line) for pattern in SENSITIVE_PATTERNS):
            continue
        filtered_lines.append(line.rstrip())
    return "\n".join(filtered_lines).strip() + "\n"


def split_sections(text: str) -> list[Section]:
    sections: list[Section] = []
    current_heading = "Document"
    current_lines: list[str] = []

    for line in text.splitlines():
        if re.match(r"^#{1,6}\s+", line):
            body = "\n".join(current_lines).strip()
            if body:
                sections.append(Section(current_heading, body))
            current_heading = line.lstrip("#").strip()
            current_lines = []
            continue
        current_lines.append(line)

    body = "\n".join(current_lines).strip()
    if body:
        sections.append(Section(current_heading, body))

    return sections or [Section("Document", text.strip())]


def split_blocks(body: str) -> list[str]:
    blocks: list[str] = []
    current: list[str] = []

    for line in body.splitlines():
        if line.strip():
            current.append(line)
            continue
        if current:
            blocks.append("\n".join(current).strip())
            current = []

    if current:
        blocks.append("\n".join(current).strip())

    return blocks


def trailing_overlap_blocks(blocks: list[str], overlap_tokens: int) -> list[str]:
    selected: list[str] = []
    total = 0
    for block in reversed(blocks):
        selected.insert(0, block)
        total += token_count(block)
        if total >= overlap_tokens:
            break
    return selected


def chunk_section(heading: str, body: str, profile: ChunkProfile) -> list[str]:
    blocks = split_blocks(body)
    heading_prefix = "" if heading == "Document" else f"## {heading}"
    heading_tokens = token_count(heading_prefix)
    chunks: list[str] = []
    current_blocks: list[str] = []
    current_tokens = heading_tokens

    for block in blocks:
        block_tokens = token_count(block)
        if current_blocks and current_tokens + block_tokens > profile.target_tokens:
            parts = current_blocks[:]
            chunk = "\n\n".join(([heading_prefix] if heading_prefix else []) + parts).strip()
            if chunk:
                chunks.append(chunk)
            current_blocks = trailing_overlap_blocks(parts, profile.overlap_tokens)
            current_tokens = heading_tokens + sum(token_count(item) for item in current_blocks)
        current_blocks.append(block)
        current_tokens += block_tokens

    if current_blocks:
        chunk = "\n\n".join(([heading_prefix] if heading_prefix else []) + current_blocks).strip()
        if chunk:
            chunks.append(chunk)

    return chunks


def normalize_action_log(path: Path, keep_last: int = ACTION_LOG_MAX_LINES) -> str:
    lines = [line.strip() for line in path.read_text(encoding="utf-8", errors="ignore").splitlines() if line.strip()]
    selected = lines[-keep_last:]
    normalized: list[str] = []
    for raw in selected:
        try:
            row = json.loads(raw)
        except json.JSONDecodeError:
            normalized.append(raw)
            continue
        normalized.append(
            " | ".join([
                str(row.get("ts", "")),
                str(row.get("skill", "")),
                str(row.get("action", "")),
                str(row.get("result", "")),
                str(row.get("triggered_by", "")),
            ]).strip()
        )
    return "\n".join(normalized) + "\n"


def build_chunks(path: Path) -> tuple[list[tuple], str, str, str]:
    if path.name == "action-log.jsonl":
        raw_text = normalize_action_log(path)
    else:
        raw_text = path.read_text(encoding="utf-8")
    filtered_text = filter_sensitive_lines(raw_text)
    file_checksum = sha256_text(filtered_text)
    updated_at = datetime.fromtimestamp(path.stat().st_mtime, UTC).replace(microsecond=0).isoformat()
    profile = chunk_profile_for_path(path)
    chunks: list[tuple] = []
    chunk_index = 0

    for section in split_sections(filtered_text):
        for chunk in chunk_section(section.heading, section.body, profile):
            chunks.append((str(path), chunk_index, section.heading, chunk, updated_at))
            chunk_index += 1

    return chunks, file_checksum, updated_at, profile.name


# ─── sqlite-vec ──────────────────────────────────────────────────────────────

def load_sqlite_vec(conn: sqlite3.Connection) -> bool:
    try:
        import sqlite_vec
        conn.enable_load_extension(True)
        sqlite_vec.load(conn)
        conn.enable_load_extension(False)
        return True
    except Exception:
        return False


def ensure_vec_schema(conn: sqlite3.Connection) -> None:
    """chunk_vectors Tabelle anlegen (nur wenn sqlite-vec geladen ist)."""
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS chunk_vectors (
            chunk_id INTEGER PRIMARY KEY REFERENCES chunks(id) ON DELETE CASCADE,
            embedding BLOB NOT NULL
        );
    """)
    # vec0 Virtual Table — nur anlegen wenn noch nicht vorhanden
    try:
        conn.execute("SELECT COUNT(*) FROM chunk_vec_idx LIMIT 1")
    except sqlite3.OperationalError:
        conn.execute(f"CREATE VIRTUAL TABLE chunk_vec_idx USING vec0(embedding float[{EMBED_DIMS}])")


# ─── Embedding Service ────────────────────────────────────────────────────────

def embed_texts(texts: list[str], timeout: float = 30.0) -> list[list[float]] | None:
    """Batch-Embedding via rag-embed Service. None bei Fehler."""
    try:
        payload = json.dumps({"texts": texts}).encode()
        req = urllib.request.Request(
            EMBED_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read())
            return data["vectors"]
    except Exception:
        return None


def check_embed_service() -> bool:
    try:
        with urllib.request.urlopen(
            "http://192.168.2.101:18790/health", timeout=3.0
        ) as resp:
            return json.loads(resp.read()).get("status") == "ok"
    except Exception:
        return False


def store_embeddings(
    conn: sqlite3.Connection,
    chunk_ids: list[int],
    vectors: list[list[float]],
) -> int:
    stored = 0
    for chunk_id, vec in zip(chunk_ids, vectors):
        blob = struct.pack(f"{len(vec)}f", *vec)
        conn.execute(
            "INSERT OR REPLACE INTO chunk_vectors (chunk_id, embedding) VALUES (?, ?)",
            (chunk_id, blob),
        )
        conn.execute(
            "INSERT OR REPLACE INTO chunk_vec_idx (rowid, embedding) VALUES (?, ?)",
            (chunk_id, blob),
        )
        stored += 1
    return stored


def generate_embeddings_for_source(
    conn: sqlite3.Connection,
    source: str,
) -> int:
    """Alle Chunks einer Quelle einbetten (die noch kein Embedding haben)."""
    rows = conn.execute(
        """
        SELECT c.id, c.text FROM chunks c
        LEFT JOIN chunk_vectors cv ON cv.chunk_id = c.id
        WHERE c.source = ? AND cv.chunk_id IS NULL
        """,
        (source,),
    ).fetchall()
    if not rows:
        return 0

    stored = 0
    for i in range(0, len(rows), EMBED_BATCH_SIZE):
        batch = rows[i : i + EMBED_BATCH_SIZE]
        ids = [r[0] for r in batch]
        texts = [r[1] for r in batch]
        vectors = embed_texts(texts)
        if vectors is None:
            break
        stored += store_embeddings(conn, ids, vectors)
    return stored


def backfill_all_embeddings(conn: sqlite3.Connection, summary: dict) -> None:
    """Alle Chunks ohne Embedding nachholen."""
    rows = conn.execute(
        """
        SELECT c.id, c.source, c.text FROM chunks c
        LEFT JOIN chunk_vectors cv ON cv.chunk_id = c.id
        WHERE cv.chunk_id IS NULL
        ORDER BY c.source, c.chunk_index
        """
    ).fetchall()

    if not rows:
        summary["embed_backfill_chunks"] = 0
        return

    stored_total = 0
    batch_total = (len(rows) + EMBED_BATCH_SIZE - 1) // EMBED_BATCH_SIZE
    for i in range(0, len(rows), EMBED_BATCH_SIZE):
        batch = rows[i : i + EMBED_BATCH_SIZE]
        ids = [r[0] for r in batch]
        texts = [r[2] for r in batch]
        vectors = embed_texts(texts)
        if vectors is None:
            print(
                f"embed_backfill warning: embed service unreachable at batch {(i // EMBED_BATCH_SIZE) + 1}/{batch_total}",
                file=sys.stderr,
            )
            break
        stored_total += store_embeddings(conn, ids, vectors)
        if ((i // EMBED_BATCH_SIZE) + 1) % 25 == 0:
            print(
                f"embed_backfill progress: {(i // EMBED_BATCH_SIZE) + 1}/{batch_total} batches, stored={stored_total}",
                file=sys.stderr,
            )

    summary["embed_backfill_chunks"] = stored_total


# ─── Schema ──────────────────────────────────────────────────────────────────

def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS chunks (
          id INTEGER PRIMARY KEY,
          source TEXT NOT NULL,
          section TEXT DEFAULT '',
          chunk_index INTEGER NOT NULL,
          text TEXT NOT NULL,
          updated_at TEXT,
          checksum TEXT,
          UNIQUE(source, chunk_index)
        );

        CREATE TABLE IF NOT EXISTS file_index (
          source TEXT PRIMARY KEY,
          checksum TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          indexed_at TEXT NOT NULL,
          chunk_count INTEGER NOT NULL,
          is_complete INTEGER NOT NULL DEFAULT 1
        );

        CREATE TABLE IF NOT EXISTS index_meta (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );

        CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
          text,
          content='chunks',
          content_rowid='id'
        );

        CREATE TRIGGER IF NOT EXISTS chunks_ai AFTER INSERT ON chunks BEGIN
          INSERT INTO chunks_fts(rowid, text) VALUES (new.id, new.text);
        END;

        CREATE TRIGGER IF NOT EXISTS chunks_ad AFTER DELETE ON chunks BEGIN
          INSERT INTO chunks_fts(chunks_fts, rowid, text) VALUES('delete', old.id, old.text);
        END;

        CREATE TRIGGER IF NOT EXISTS chunks_au AFTER UPDATE ON chunks BEGIN
          INSERT INTO chunks_fts(chunks_fts, rowid, text) VALUES('delete', old.id, old.text);
          INSERT INTO chunks_fts(rowid, text) VALUES (new.id, new.text);
        END;

        CREATE INDEX IF NOT EXISTS idx_chunks_source_updated ON chunks(source, updated_at);
        CREATE INDEX IF NOT EXISTS idx_chunks_checksum ON chunks(checksum);
        """
    )

    # Schema-Migrationen
    columns = {row[1] for row in conn.execute("PRAGMA table_info(chunks)")}
    if "section" not in columns:
        conn.execute("ALTER TABLE chunks ADD COLUMN section TEXT DEFAULT ''")

    fi_columns = {row[1] for row in conn.execute("PRAGMA table_info(file_index)")}
    if "is_complete" not in fi_columns:
        conn.execute("ALTER TABLE file_index ADD COLUMN is_complete INTEGER NOT NULL DEFAULT 1")


def existing_checksum(conn: sqlite3.Connection, source: str) -> str | None:
    row = conn.execute(
        "SELECT checksum FROM file_index WHERE source = ?", (source,)
    ).fetchone()
    return None if row is None else row[0]


def replace_file_chunks(
    conn: sqlite3.Connection,
    source: str,
    checksum: str,
    updated_at: str,
    chunks: list[tuple],
) -> int:
    indexed_at = utc_now()
    conn.execute("DELETE FROM chunks WHERE source = ?", (source,))
    conn.executemany(
        "INSERT INTO chunks (source, chunk_index, section, text, updated_at, checksum) VALUES (?, ?, ?, ?, ?, ?)",
        [(cs, ci, sec, txt, upd, checksum) for cs, ci, sec, txt, upd in chunks],
    )
    conn.execute(
        """
        INSERT INTO file_index (source, checksum, updated_at, indexed_at, chunk_count)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(source) DO UPDATE SET
          checksum = excluded.checksum,
          updated_at = excluded.updated_at,
          indexed_at = excluded.indexed_at,
          chunk_count = excluded.chunk_count
        """,
        (source, checksum, updated_at, indexed_at, len(chunks)),
    )
    return len(chunks)


def upsert_partial_file_chunks(
    conn: sqlite3.Connection,
    source: str,
    checksum: str,
    updated_at: str,
    chunks: list[tuple],
    start_offset: int,
    end_offset: int,
    is_complete: bool,
) -> int:
    indexed_at = utc_now()
    partial = chunks[start_offset:end_offset]

    if start_offset == 0:
        conn.execute("DELETE FROM chunks WHERE source = ?", (source,))

    conn.executemany(
        "INSERT OR REPLACE INTO chunks (source, chunk_index, section, text, updated_at, checksum) VALUES (?, ?, ?, ?, ?, ?)",
        [(cs, ci, sec, txt, upd, checksum) for cs, ci, sec, txt, upd in partial],
    )

    conn.execute(
        """
        INSERT INTO file_index (source, checksum, updated_at, indexed_at, chunk_count, is_complete)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(source) DO UPDATE SET
          checksum = excluded.checksum,
          updated_at = excluded.updated_at,
          indexed_at = excluded.indexed_at,
          chunk_count = excluded.chunk_count,
          is_complete = excluded.is_complete
        """,
        (source, checksum, updated_at, indexed_at, end_offset, 1 if is_complete else 0),
    )
    return len(partial)


# ─── Main ─────────────────────────────────────────────────────────────────────

def main() -> int:
    args = parse_args()
    args.db.parent.mkdir(parents=True, exist_ok=True)

    lock_fp, lock_pid = acquire_ingest_lock()
    if lock_fp is None:
        payload = {
            "status": "skipped",
            "reason": "ingest_locked",
            "lock_file": str(INGEST_LOCK_PATH),
            "owner_pid": lock_pid or None,
        }
        if args.json:
            print(json.dumps(payload, ensure_ascii=True, indent=2))
        else:
            print(
                f"Ingest skipped: lock active ({INGEST_LOCK_PATH}, owner_pid={lock_pid or 'unknown'}).",
                file=sys.stderr,
            )
        return 0

    conn = sqlite3.connect(args.db, timeout=15)
    try:
        conn.execute("PRAGMA busy_timeout=15000")
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA synchronous=NORMAL")
        conn.execute("PRAGMA temp_store=MEMORY")
        conn.execute("PRAGMA cache_size=-20000")
        conn.execute("PRAGMA mmap_size=134217728")
        conn.execute("PRAGMA foreign_keys=ON")
        ensure_schema(conn)

        do_embed = args.embed or args.embed_backfill
        vec_available = False
        if do_embed:
            vec_available = load_sqlite_vec(conn)
            if vec_available:
                ensure_vec_schema(conn)

        embed_service_ok = False
        if do_embed and vec_available:
            embed_service_ok = check_embed_service()

        summary: dict[str, object] = {
            "db": str(args.db),
            "indexed_files": 0,
            "indexed_chunks": 0,
            "skipped_files": 0,
            "deferred_files": 0,
            "resumed": False,
            "max_chunks_per_run": args.max_chunks_per_run,
            "embed_enabled": do_embed,
            "embed_service_ok": embed_service_ok,
            "embedded_chunks": 0,
            "sources": [],
        }

        resume_state = load_ingest_state()
        pending_source = str(resume_state.get("current_source", "") or "")
        pending_chunk_offset = int(resume_state.get("next_chunk_offset", 0) or 0)
        if args.resume and resume_state.get("remaining_sources"):
            sources = [Path(p) for p in resume_state.get("remaining_sources", [])]
            summary["resumed"] = True
        else:
            sources = collect_sources()
            pending_source = ""
            pending_chunk_offset = 0

        for idx, path in enumerate(sources):
            chunks, checksum, updated_at, profile_name = build_chunks(path)
            if args.changed_only and existing_checksum(conn, str(path)) == checksum:
                summary["skipped_files"] += 1
                continue

            start_offset = pending_chunk_offset if pending_source and str(path) == pending_source else 0
            remaining_chunk_count = max(0, len(chunks) - start_offset)

            remaining_budget = (
                args.max_chunks_per_run - int(summary["indexed_chunks"])
                if args.max_chunks_per_run > 0
                else 0
            )

            if args.max_chunks_per_run > 0 and remaining_budget <= 0:
                remaining = [str(p) for p in sources[idx:]]
                summary["deferred_files"] = len(remaining)
                save_ingest_state({
                    "chunk_schema_version": CHUNK_SCHEMA_VERSION,
                    "last_run_at": utc_now(),
                    "current_source": str(path),
                    "next_chunk_offset": start_offset,
                    "remaining_sources": remaining,
                    "last_completed_source": summary["sources"][-1]["source"] if summary["sources"] else None,
                })
                break

            if args.max_chunks_per_run > 0 and remaining_chunk_count > remaining_budget > 0:
                end_offset = start_offset + remaining_budget
                chunk_count = upsert_partial_file_chunks(
                    conn, str(path), checksum, updated_at, chunks,
                    start_offset, end_offset, False,
                )
                summary["indexed_files"] = int(summary["indexed_files"]) + 1
                summary["indexed_chunks"] = int(summary["indexed_chunks"]) + chunk_count
                summary["sources"].append({
                    "source": str(path), "chunks": chunk_count,
                    "updated_at": updated_at, "chunk_profile": profile_name,
                    "partial": True, "next_chunk_offset": end_offset,
                })
                remaining = [str(path)] + [str(p) for p in sources[idx + 1:]]
                summary["deferred_files"] = len(remaining)
                save_ingest_state({
                    "chunk_schema_version": CHUNK_SCHEMA_VERSION,
                    "last_run_at": utc_now(),
                    "current_source": str(path),
                    "next_chunk_offset": end_offset,
                    "remaining_sources": remaining,
                    "last_completed_source": summary["sources"][-1]["source"] if summary["sources"] else None,
                })
                break

            if start_offset > 0:
                chunk_count = upsert_partial_file_chunks(
                    conn, str(path), checksum, updated_at, chunks,
                    start_offset, len(chunks), True,
                )
            else:
                chunk_count = replace_file_chunks(conn, str(path), checksum, updated_at, chunks)

            summary["indexed_files"] = int(summary["indexed_files"]) + 1
            summary["indexed_chunks"] = int(summary["indexed_chunks"]) + chunk_count

            embedded = 0
            if do_embed and vec_available and embed_service_ok:
                conn.commit()
                embedded = generate_embeddings_for_source(conn, str(path))
                summary["embedded_chunks"] = int(summary["embedded_chunks"]) + embedded

            summary["sources"].append({
                "source": str(path), "chunks": chunk_count,
                "updated_at": updated_at, "chunk_profile": profile_name,
                "partial": False, "embedded": embedded,
            })

        now = utc_now()
        for key, value in (
            ("chunk_schema_version", CHUNK_SCHEMA_VERSION),
            ("last_ingest_at", now),
        ):
            conn.execute(
                "INSERT INTO index_meta (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                (key, value),
            )

        if args.embed_backfill and vec_available and embed_service_ok:
            conn.commit()
            backfill_all_embeddings(conn, summary)
            conn.execute(
                "INSERT INTO index_meta (key, value) VALUES ('last_embed_backfill_at', ?) "
                "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                (now,),
            )

        if vec_available and do_embed:
            conn.execute(
                "INSERT INTO index_meta (key, value) VALUES ('vec_schema_version', '1.0') "
                "ON CONFLICT(key) DO UPDATE SET value = excluded.value"
            )

        conn.execute("PRAGMA optimize")
        conn.commit()
    except sqlite3.OperationalError as exc:
        payload = {
            "status": "error",
            "reason": "sqlite_operational_error",
            "error": str(exc),
        }
        if args.json:
            print(json.dumps(payload, ensure_ascii=True, indent=2))
        else:
            print(f"Ingest failed: {exc}", file=sys.stderr)
        return 2
    finally:
        conn.close()
        try:
            fcntl.flock(lock_fp.fileno(), fcntl.LOCK_UN)
            lock_fp.close()
        except Exception:
            pass

    if summary["deferred_files"] == 0:
        save_ingest_state({
            "chunk_schema_version": CHUNK_SCHEMA_VERSION,
            "last_run_at": utc_now(),
            "remaining_sources": [],
            "last_completed_source": summary["sources"][-1]["source"] if summary["sources"] else None,
        })

    if args.json:
        print(json.dumps(summary, ensure_ascii=True, indent=2))
    else:
        embed_info = (
            f", embedded {summary['embedded_chunks']} chunks"
            if do_embed
            else ""
        )
        backfill_info = (
            f" (backfill: {summary.get('embed_backfill_chunks', 0)} chunks)"
            if args.embed_backfill
            else ""
        )
        print(
            f"Indexed {summary['indexed_files']} files, {summary['indexed_chunks']} chunks"
            f"{embed_info}{backfill_info}; skipped {summary['skipped_files']} unchanged."
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
