from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
import sqlite3
import subprocess
from pathlib import Path


class EmbedRequest(BaseModel):
    texts: list[str]


class RagSearchRequest(BaseModel):
    query: str
    limit: int = 5


app = FastAPI(title="openclaw-rag-embed")
model = SentenceTransformer("all-MiniLM-L6-v2")
RAG_DB = Path("/data/rag/index.db")
REINDEX_SCRIPT = Path("/home/steges/agent/skills/openclaw-rag/scripts/reindex.sh")


def _fts_query(query: str) -> str:
    terms = [p.strip().lower() for p in query.replace("-", " ").replace(".", " ").split()]
    terms = [t for t in terms if len(t) > 1]
    if not terms:
        return '""'
    return " OR ".join(f'"{t}"' for t in terms)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/embed")
def embed(req: EmbedRequest) -> dict[str, list[list[float]]]:
    vectors = model.encode(req.texts, normalize_embeddings=True).tolist()
    return {"vectors": vectors}


@app.get("/rag/status")
def rag_status() -> dict[str, object]:
    if not RAG_DB.exists():
        return {
            "status": "unavailable",
            "doc_count": 0,
            "last_indexed": "missing index",
        }
    try:
        conn = sqlite3.connect(RAG_DB)
        try:
            doc_count = conn.execute("SELECT COUNT(DISTINCT source) FROM chunks").fetchone()[0]
        finally:
            conn.close()
        last = RAG_DB.stat().st_mtime
        return {
            "status": "ready",
            "doc_count": int(doc_count or 0),
            "last_indexed": int(last),
        }
    except Exception as err:
        return {
            "status": "error",
            "doc_count": 0,
            "last_indexed": str(err),
        }


@app.post("/rag/search")
def rag_search(req: RagSearchRequest) -> dict[str, object]:
    query = (req.query or "").strip()
    limit = max(1, min(int(req.limit or 5), 20))
    if not query:
        return {"results": []}
    if not RAG_DB.exists():
        return {"results": []}

    conn = sqlite3.connect(RAG_DB)
    try:
        sql = """
            SELECT c.source, c.section, c.chunk_index, c.text, -bm25(chunks_fts) AS score
            FROM chunks_fts
            JOIN chunks c ON c.id = chunks_fts.rowid
            WHERE chunks_fts MATCH ?
            ORDER BY bm25(chunks_fts)
            LIMIT ?
        """
        rows = conn.execute(sql, (_fts_query(query), limit)).fetchall()
        results = [
            {
                "source": row[0],
                "section": row[1],
                "chunk_index": row[2],
                "text": row[3],
                "score": round(float(row[4]), 6),
            }
            for row in rows
        ]
        return {"results": results}
    except sqlite3.OperationalError:
        return {"results": []}
    finally:
        conn.close()


@app.post("/rag/reindex")
def rag_reindex() -> dict[str, object]:
    if not REINDEX_SCRIPT.exists():
        return {"ok": False, "error": "reindex script not mounted"}
    try:
        proc = subprocess.run(
            ["bash", str(REINDEX_SCRIPT)],
            capture_output=True,
            text=True,
            timeout=180,
            check=False,
        )
        return {
            "ok": proc.returncode == 0,
            "code": proc.returncode,
            "stdout": proc.stdout[-1200:],
            "stderr": proc.stderr[-1200:],
        }
    except Exception as err:
        return {"ok": False, "error": str(err)}
