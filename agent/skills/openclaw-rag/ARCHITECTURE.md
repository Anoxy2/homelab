# OpenClaw RAG Architecture

## Decision

RAG laeuft lokal mit SQLite als Primarspeicher.

- Volltext: FTS5 (in SQLite enthalten, keine zusaetzlichen Services)
- Optional semantisch: sqlite-vec (nur wenn Vektor-Suche benoetigt wird)
- Embeddings: separater Python-Container mit sentence-transformers
- Modell: all-MiniLM-L6-v2

Warum:

- ARM64-freundlich, kein separater Vektor-Cluster
- Geringe Betriebs-Komplexitaet auf Raspberry Pi
- Daten bleiben lokal im Homelab

## Storage Layout

- SQLite-Datei: /home/steges/infra/openclaw-data/rag/index.db
- Input-Sources: /home/steges/docs, /home/steges/growbox, /home/steges/agent/*.md, /home/steges/README.md, /home/steges/CLAUDE.md

## Scripts

- Ingest: /home/steges/agent/skills/openclaw-rag/scripts/ingest.py
- Retrieve: /home/steges/agent/skills/openclaw-rag/scripts/retrieve.py
- Reindex: /home/steges/agent/skills/openclaw-rag/scripts/reindex.sh

## FTS5 Schema (MVP)

```sql
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
  chunk_count INTEGER NOT NULL
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
```

## Embedding Service

- Service-Name: rag-embed
- HTTP: 192.168.2.101:18790
- Endpoint: POST /embed
- Health: GET /health
- Runtime: python:3.11-slim

Der Service laedt das Modell einmal beim Start und bleibt warm, um Cold-Start-Latenz bei Folge-Requests zu vermeiden.

## ARM64 Hinweise

- sqlite-vec 0.1.9 hat ein fertiges ARM64-Wheel auf PyPI/piwheels: `sqlite_vec-0.1.9-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl` (160 KB). Kein Source-Build noetig.
  - Installation: `pip3 install sqlite-vec --break-system-packages`
  - Verifiziert auf: aarch64, Python 3.11.2, SQLite 3.40.1, Debian 12 Bookworm (2026-04-09)
- sentence-transformers benoetigt beim ersten Modell-Load deutlich laenger als bei Folgeaufrufen.
- Kein blindes `pip install torch` auf ARM erwarten; Wheels und Basis-Image muessen ARM64-tauglich sein.
- Erster `encode()`-Aufruf kann 10-20 Sekunden dauern, daher den Embedding-Prozess warm halten.
- Keine x86-only Binaries verwenden.
- Debian 12 ist externally-managed — `--break-system-packages` ist auf diesem Homelab akzeptiert.
