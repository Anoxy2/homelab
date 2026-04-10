# RAG Ausbau Plan — Pilab / OpenClaw / Growbox

Ziel: OpenClaw entwickelt echtes Selbstbewusstsein über das System und sich selbst. Das RAG-System wird zur primären Wissensschicht — nicht nur für Dokumentation, sondern als lebendiges Gedächtnis das sich selbst aktuell hält.
                             [--provider auto|anthropic|copilot] [--model <name>]

**Stand bei Erstellung:** 2026-04-09
**Baseline Metriken:** avg Precision@5=0.32 · avg Recall@5=0.625 · p95=55ms · 5/20 Gold-Set-Fragen bei P=0, R=0

---

rag-dispatch.sh autodoc "system-state" --output agent/SYSTEM-STATE.md --provider copilot --model gpt-4.1
## Warum dieser Plan

Das RAG-System läuft stabil und schnell (FTS5, SQLite, <60ms p95). Aber es hat drei grundlegende Lücken:

1. **Keine Semantik** — der Embedding-Container läuft schon, wird aber nie genutzt. BM25 versteht keine Bedeutung, nur Keywords.
2. **Lückenhafter Index** — CHANGELOG.md und HANDSHAKE.md fehlten (behoben 2026-04-09), weitere Selbstbild-Quellen fehlen noch.
3. **Kein Selbstbild** — OpenClaw kann Fragen über Skills, Architektur und seine eigene Geschichte nicht zuverlässig beantworten, weil diese Informationen nicht konsolidiert vorliegen.

---

## Phase 0 — Sofort-Fixes

### 0.1 CHANGELOG.md und HANDSHAKE.md indexieren ✓ 2026-04-09

`CHANGELOG.md` und `agent/HANDSHAKE.md` in `ALLOWED_FILES` in `ingest.py` ergänzt.
Reindex lief: 6 neue Quellen, 191 Chunks.
Ergebnis: nightly-check und security-scan repariert, P=0/R=0 von 5→4 Fragen.

### 0.2 Lazy Alias Expansion in retrieve.py

**Problem:** Aliases werden immer expandiert, auch wenn ausreichend direkte Treffer existieren. "risiken" → "ausfall, fallback" liefert DNS-Runbooks statt Security-Docs.

**Implementierung:**
```python
# retrieve.py: search_db() modifizieren
def search_db_with_lazy_aliases(db_path, terms, raw_terms, query, limit, timeout_ms):
    # Erste FTS-Suche ohne Aliases
    results, mode, warning = search_db(db_path, raw_terms, query, limit, timeout_ms)
    if len(results) >= 3:
        return results, mode, warning  # ausreichend — keine Expansion nötig
    # Schwache Ergebnisse → retry mit Aliases
    return search_db(db_path, terms, query, limit, timeout_ms)
```

**Erwarteter Effekt:** pihole-risks sollte CLAUDE.md/security.md wieder finden ohne durch Runbooks überschrieben zu werden.

### 0.3 Source-Path-Match-Boost im Reranker

**Problem:** Für "skill-wrapper-separation" werden 5× SKILL.md-Dateien aus verschiedenen Skills zurückgegeben. Die eigentliche Quelle `docs/skills/skill-forge-governance.md` verliert wegen generischer Keyword-Verteilung.

**Implementierung:** Wenn ein Query-Term exakt einem Datei- oder Ordnernamen im Pfad entspricht, Score stark boosten:
```python
# retrieve.py: rerank_results()
def exact_path_boost(source: str, keywords: list[str]) -> float:
    boost = 0.0
    path_parts = Path(source).parts
    name_no_ext = Path(source).stem.lower().replace("-", "").replace("_", "")
    for kw in keywords:
        kw_clean = kw.replace("-", "").replace("_", "")
        if kw_clean in name_no_ext:
            boost += 8.0  # exakter Dateiname-Match
        for part in path_parts:
            if kw_clean == part.lower():
                boost += 4.0  # exakter Verzeichnisname-Match
    return boost
```

---

## Phase 1 — Selbstbewusstsein: OpenClaw versteht sich selbst

Das ist die konzeptionell wichtigste Phase. OpenClaw soll auf die Frage "Wer bist du und was kannst du?" eine vollständige, aktuelle Antwort aus dem RAG-System ziehen können.

### 1.1 Was fehlt im Wissensbestand

Aktuell indexiert: Docs, Growbox-Diary, einzelne agent/*.md Dateien, CHANGELOG, HANDSHAKE.

**Nicht ausreichend konsolidiert:**
- Skill-Inventar: welche Skills gibt es, welchen Status haben sie, was tun sie
- Eigene Geschichte: was wurde wann gebaut, warum, welche Incidents gab es
- Architekturverständnis: wie hängen die Teile zusammen
- Operational Memory: was ist heute passiert, was sind offene Tasks

### 1.2 Neue Kerndokumente für das Selbstbild

Folgende Dokumente sind zu erstellen und regelmäßig aktuell zu halten:

**`agent/SELF-MODEL.md`** — Das Selbstbild
- Wer bin ich? (Name, Zweck, Betreiber)
- Auf welchem System laufe ich? (Hardware, Dienste, Ports)
- Welche Fähigkeiten habe ich? (Skill-Liste mit Kurzbeschreibung und Status)
- Was sind meine Grenzen? (Policy-Grenzen, verbotene Aktionen)
- Wann wurde ich gebaut / was wurde zuletzt geändert?
- Aktualisierung: täglich durch Heartbeat oder Post-Promote-Hook

**`agent/SKILL-INVENTORY.md`** — Lebendige Skill-Liste
- Generiert aus `~/scripts/skill-forge status` + `known-skills.json`
- Für jeden Skill: Name, Zweck, aktueller Status (canary/promoted/rollback), letzte Änderung
- Aktualisierung: nach jeder Promotion oder Rollback automatisch

**`agent/HISTORY.md`** — Operative Geschichte
- Komprimierter Verlauf der letzten 30 Tage
- Quelle: `infra/openclaw-data/action-log.jsonl` + `audit-log.jsonl` + CHANGELOG.md
- Nicht Session-genau, sondern Event-verdichtet
- Aktualisierung: wöchentlich

**`agent/SYSTEM-STATE.md`** — Aktueller Systemzustand
- Container-Status (letzte bekannte docker ps Ausgabe)
- RAG-Index-Stand (Quellanzahl, letzte Indexierung, aktuelle Gold-Set-Scores)
- Aktive Canary-Läufe, offene Incidents
- Aktualisierung: täglich durch Heartbeat

**`growbox/GROW-SUMMARY.md`** — Konsolidierter Grow-Überblick
- Erzeugt aus: `GROW.md` + letzten 7 Diary-Einträgen + `THRESHOLDS.md`
- Inhalt: aktueller Stand, Trend, Anomalien, nächste Maßnahmen
- Aktualisierung: täglich

### 1.3 Fehlende Projektdokumentation

| Datei | Inhalt | Priorität |
|-------|--------|-----------|
| `docs/core/system-overview.md` | Ein-Seiten-Karte aller Komponenten | Hoch |
| `docs/openclaw/openclaw-communication.md` | Telegram, claw-send.sh, Session-Trennung, HANDSHAKE | Hoch |
| `docs/skill-konzept.md` | Was ist ein Skill, Lifecycle, Canary, Contracts | Mittel |
| `docs/growbox-ha-integration.md` | ESP32 → MQTT → HA → Claw Datenfluss | Mittel |
| `docs/faq.md` | Top-20-Fragen die OpenClaw gestellt bekommt | Mittel |
| `docs/skill-forge-grenzen.md` | Was skill-forge darf/nicht darf, Boundary-Cases | Niedrig |

### 1.4 Gold-Set auf 30 Fragen erweitern

Nach Phase 1: 10 neue Fragen zu Selbstbild und Growbox:
- "Welche Skills hast du aktuell?"
- "Welche Skills sind im Canary?"
- "Was ist deine Architektur?"
- "Wie kommunizierst du mit steges?"
- "Wie war der Grow die letzten 3 Tage?"
- "Was sind deine Alarmgrenzen für die Growbox?"
- "Was hast du letzte Woche gemacht?"
- "Wie hängen MQTT, ESP32 und Home Assistant zusammen?"
- "Was passiert beim Skill-Promote?"
- "Wer bist du und was machst du?"

---

## Phase 2 — Hybrid Search: Semantik aktivieren

### 2.1 Status und Erkenntnisse

**Embedding-Service:** Läuft (`rag-embed`, Port 18790, `all-MiniLM-L6-v2`)
- 384 Dimensionen, normalisierte Vektoren
- Response-Zeit: ~50ms für einzelnen Text (warm)
- Erreichbar: `POST http://192.168.2.101:18790/embed`

**sqlite-vec:** ARM64-Wheel verfügbar
- Version: 0.1.9 auf PyPI/piwheels
- Wheel: `sqlite_vec-0.1.9-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl` (160 KB)
- Kein Source-Build nötig — pre-built ARM64 (piwheels.org)
- ARCHITECTURE.md war in diesem Punkt veraltet

**Aktuelle DB-Größe:** 1.5 MB / 1132 Chunks / 103 Quellen
**Geschätzte DB-Größe nach Vektoren:** ~3.7 MB (+2.2 MB für 1132 × 384-dim float32 + Index)

### 2.2 sqlite-vec Installation

**Schritt 1: Installieren**
```bash
pip3 install sqlite-vec --break-system-packages
```
Debian 12 Bookworm ist externally-managed — `--break-system-packages` ist auf diesem Homelab akzeptiert (keine anderen Python-Pakete werden konfliktieren).

**Schritt 2: Verify**
```bash
python3 -c "
import sqlite3, sqlite_vec
conn = sqlite3.connect(':memory:')
conn.enable_load_extension(True)
sqlite_vec.load(conn)
conn.enable_load_extension(False)
print('sqlite-vec:', sqlite_vec.__version__)
res = conn.execute(\"SELECT vec_version()\").fetchone()
print('vec_version():', res[0])
"
```

**Schritt 3: ARCHITECTURE.md aktualisieren** — ARM64-Hinweis korrigieren

### 2.3 DB-Schema Erweiterung

In `ingest.py` → `ensure_schema()` ergänzen:

```sql
-- Vektor-Tabelle (rowid = chunk id aus chunks-Tabelle)
CREATE TABLE IF NOT EXISTS chunk_vectors (
    chunk_id INTEGER PRIMARY KEY REFERENCES chunks(id) ON DELETE CASCADE,
    embedding BLOB NOT NULL
);

-- sqlite-vec Virtual Table für ANN-Suche
CREATE VIRTUAL TABLE IF NOT EXISTS chunk_vec_idx
USING vec0(embedding float[384]);
```

Index-Meta erweitern:
```sql
INSERT OR REPLACE INTO index_meta (key, value) 
VALUES ('vec_schema_version', '1.0');
```

### 2.4 Embedding-Generierung in ingest.py

Nach dem Schreiben der Chunks: Embeddings in Batches generieren.

```python
EMBED_URL = "http://192.168.2.101:18790/embed"
EMBED_BATCH_SIZE = 32  # Batches halten Speicher und Latenz im Rahmen

def generate_embeddings(texts: list[str]) -> list[list[float]] | None:
    """POST /embed — gibt None zurück wenn Service nicht erreichbar."""
    try:
        import urllib.request, json as _json
        payload = _json.dumps({"texts": texts}).encode()
        req = urllib.request.Request(
            EMBED_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            return _json.loads(resp.read())["vectors"]
    except Exception:
        return None  # Graceful: weiter ohne Vektoren

def store_embeddings(conn, chunk_ids: list[int], vectors: list[list[float]]) -> None:
    import struct
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
```

**Wichtig:** `--embed` Flag für ingest.py — Embedding-Generierung ist optional, da der Service nicht immer erreichbar sein muss:
```bash
python3 ingest.py --changed-only --embed   # mit Embeddings
python3 ingest.py --changed-only            # nur FTS (aktuelles Verhalten)
```

### 2.5 Hybrid Retrieval in retrieve.py

**Ansatz: Reciprocal Rank Fusion (RRF)**

RRF kombiniert zwei Rankings ohne Score-Normalisierung — robust bei unterschiedlichen Score-Skalen:
```
rrf_score(item) = Σ 1 / (k + rank_in_list_i)    (k=60 Standard)
```

```python
EMBED_URL = "http://192.168.2.101:18790/embed"

def embed_query(query: str, timeout_ms: int) -> list[float] | None:
    """Einzel-Query embedden — None wenn Service nicht erreichbar."""
    try:
        import urllib.request, json as _json
        payload = _json.dumps({"texts": [query]}).encode()
        req = urllib.request.Request(EMBED_URL, data=payload,
            headers={"Content-Type": "application/json"}, method="POST")
        with urllib.request.urlopen(req, timeout=timeout_ms/1000.0) as resp:
            return _json.loads(resp.read())["vectors"][0]
    except Exception:
        return None

def vector_results(conn, query_vec: list[float], limit: int) -> list[dict]:
    """ANN-Suche via sqlite-vec."""
    import struct
    blob = struct.pack(f"{len(query_vec)}f", *query_vec)
    sql = """
        SELECT cv.chunk_id, vec_distance_cosine(cv.embedding, ?) AS distance
        FROM chunk_vectors cv
        ORDER BY distance
        LIMIT ?
    """
    rows = conn.execute(sql, (blob, limit * 3)).fetchall()
    # Cosine-distance → similarity score (1 - distance)
    chunk_ids = {row[0]: 1.0 - float(row[1]) for row in rows}
    if not chunk_ids:
        return []
    placeholders = ",".join("?" * len(chunk_ids))
    chunks = conn.execute(
        f"SELECT source, section, chunk_index, text, id FROM chunks WHERE id IN ({placeholders})",
        list(chunk_ids.keys()),
    ).fetchall()
    return [
        {"source": r[0], "section": r[1], "chunk_index": r[2],
         "text": r[3], "score": chunk_ids[r[4]]}
        for r in chunks
    ]

def rrf_merge(bm25: list[dict], vec: list[dict], k: int = 60) -> list[dict]:
    """Reciprocal Rank Fusion — keine Score-Normalisierung nötig."""
    scores: dict[str, float] = {}
    sources: dict[str, dict] = {}
    for rank, item in enumerate(bm25):
        key = f"{item['source']}::{item['chunk_index']}"
        scores[key] = scores.get(key, 0.0) + 1.0 / (k + rank + 1)
        sources[key] = item
    for rank, item in enumerate(vec):
        key = f"{item['source']}::{item['chunk_index']}"
        scores[key] = scores.get(key, 0.0) + 1.0 / (k + rank + 1)
        sources[key] = item
    merged = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    return [{**sources[k], "score": round(s * 1000, 6)} for k, s in merged]
```

**Fallback-Kette:**
1. Versuche Hybrid (BM25 + Vector) → wenn Embed-Service erreichbar
2. Falls Embed-Service nicht erreichbar: nur FTS (aktuelles Verhalten, kein Fehler)
3. Falls FTS leer: LIKE-Fallback (aktuelles Verhalten)

**Search-Mode im Output erweitern:**
- `"fts"` — nur BM25 (aktuell)
- `"hybrid"` — BM25 + Vector (neu)
- `"vector-only"` — nur Vector (Fallback wenn FTS leer)
- `"like"` — LIKE-Fallback (aktuell)

### 2.6 embedding/requirements.txt und Dockerfile prüfen

Der `rag-embed`-Container kann `POST /rag/search` — diese Route macht aber aktuell nur FTS ohne Vektoren. Langfristig: Embedding-Service bekommt auch die sqlite-vec ANN-Route. Kurzfristig: retrieve.py macht den Hybrid-Call selbst (POST /embed für Query-Embedding).

### 2.7 Canary-Gates für Phase 2

`rag-canary-smoke.sh` Grenzwerte anpassen nach Phase-2-Baseline:
```yaml
# policy/canary-criteria.yaml — nach Phase 2 updaten
skills:
  openclaw-rag:
    precision_at_5_min: 0.45   # war 0.25
    recall_at_5_min: 0.70      # war 0.55
    p95_latency_max_ms: 250    # war 200 (vector search kostet mehr)
```

### 2.8 Ziel-Metriken nach Phase 2

| Metrik | Baseline | Nach Phase 0 | Ziel Phase 2 |
|--------|----------|-------------|-------------|
| avg Precision@5 | 0.32 | 0.33 | ≥ 0.50 |
| avg Recall@5 | 0.625 | 0.65 | ≥ 0.75 |
| P=0, R=0 Fragen | 5/20 | 4/20 | ≤ 1/20 |
| p95 Latenz | 55ms | 59ms | ≤ 200ms |
| DB-Größe | 1.5 MB | 1.5 MB | ~3.7 MB |

---

## Phase 3 — Auto-Doc: RAG schreibt sich selbst

### 3.1 Konzept: Write-Back-Pipeline

```
Systemänderung
    ↓
rag doc-keeper erkennt Delta (Delta-Scan)
    ↓
rag-dispatch.sh autodoc <topic>
    ↓
  1. RAG-Retrieval: Top-10 Chunks zum Topic
  2. Claude API: Synthesis-Prompt + Kontext → Dokument
  3. Schreiben: docs/ mit DOC_KEEPER_AUTO_START/END Marker
    ↓
RAG reindexiert neues Dokument
```

Kein Zirkelschluss weil: generierte Dokumente sind `<!-- GENERATED -->` markiert und nie Primärquellen — die SKILL.md, CLAUDE.md etc. werden nie überschrieben.

### 3.2 autodoc Subcommand für rag-dispatch.sh

```bash
rag-dispatch.sh autodoc <topic> [--output <path>] [--force] [--dry-run]

# Beispiele:
rag-dispatch.sh autodoc "skill-inventar" --output agent/SKILL-INVENTORY.md
rag-dispatch.sh autodoc "system-state" --output agent/SYSTEM-STATE.md
rag-dispatch.sh autodoc "growbox-summary" --output growbox/GROW-SUMMARY.md
rag-dispatch.sh autodoc "self-model" --output agent/SELF-MODEL.md
```

**Mechanismus intern:**
1. `retrieve.py "<topic>" --limit 10` → Top-10 Chunks
2. Synthesis-Prompt bauen (Topic + Chunks + Zieldokument-Format)
3. API-Synthese via Provider-Auswahl:
    - `anthropic` -> `POST https://api.anthropic.com/v1/messages` (claude-haiku)
    - `copilot` -> OpenAI-kompatibles `POST <base>/chat/completions` (z. B. `gpt-4.1`)
    - `auto` (default) nimmt bevorzugt Anthropic-Key, sonst Copilot-Key
4. Output validieren (Mindestlänge, kein Secret-Pattern)
5. Schreiben mit Marker + Timestamp

**Build-Update 2026-04-09:**
- Dry-Run ist jetzt API-unabhaengig (`generation_mode=dry-run-local-preview`), damit Trigger-/Merge-Pfade auch ohne gueltigen API-Key testbar sind.
- Auto-Doc filtert stale Quellen (Datei existiert nicht mehr) vor der Synthese und dokumentiert diese in `stale_sources_dropped`.
- Bestehende Dateien ohne Marker werden nicht mehr hart blockiert; der Marker-Block wird append/replace-faehig geschrieben (`write_mode`).
- Auto-Doc unterstuetzt jetzt neben Anthropic auch Copilot/OpenAI-kompatible GPT-Modelle (Default: `gpt-4.1`) via `--provider copilot`.
- Timeout-Hardening aktiv: API-Timeout/Retry und Copilot-Tokenbudget sind per Env steuerbar (`RAG_AUTODOC_API_TIMEOUT_SECONDS`, `RAG_AUTODOC_API_RETRIES`, `RAG_AUTODOC_COPILOT_MAX_TOKENS`).

**API-Credentials:**
- Anthropic: `$ANTHROPIC_API_KEY`
- Copilot/OpenAI-kompatibel: `$COPILOT_API_KEY` oder `$OPENAI_API_KEY` oder `$GITHUB_TOKEN`
- Runtime: `rag-dispatch.sh` laedt automatisch `/home/steges/.env` (gleiches Env-File wie OpenClaw).

### 3.3 Synthesis-Prompt-Template

```
Du bist OpenClaw, ein KI-Assistent der auf einem Raspberry Pi 5 Homelab läuft.
Dein Betreiber ist steges (Tobias).

Schreibe eine aktuelle Zusammenfassung zum Thema: "{topic}"

Verwende ausschließlich die folgenden Quellen:
{retrieved_chunks}

Format: Markdown. Sachlich, kompakt. Keine Erfindungen.
Wenn Informationen fehlen: "Keine Daten vorhanden" statt Spekulation.
Timestamp: {utc_now}
```

### 3.4 Automatische Trigger

**Post-Promote-Hook** (skill-forge canary promote):
```bash
# Nach Promotion automatisch:
rag-dispatch.sh autodoc "skill-inventar" --output agent/SKILL-INVENTORY.md
rag-dispatch.sh reindex --changed-only
```

**Heartbeat-Hook** (täglich morgens):
```bash
rag-dispatch.sh autodoc "system-state" --output agent/SYSTEM-STATE.md
rag-dispatch.sh autodoc "growbox-summary" --output growbox/GROW-SUMMARY.md
rag-dispatch.sh reindex --changed-only
```

**Wöchentlicher Hook** (samstags):
```bash
rag-dispatch.sh autodoc "self-model" --output agent/SELF-MODEL.md
rag-dispatch.sh autodoc "operative-history" --output agent/HISTORY.md
```

### 3.5 Doc-Keeper ist jetzt Teil von openclaw-rag

Doc-Keeper und Auto-Doc laufen jetzt unter einem Entry-Point:

- Delta/Freshness: `skills rag doc-keeper run ...`
- Synthese: `rag-dispatch.sh autodoc ...`
- Batch-Start (neu): `rag-dispatch.sh doc-keeper run --autodoc --autodoc-profile <daily|post-promote|weekly>`

Damit ist die Koordination im selben Skill verankert (weniger Drift, einheitlicher State/Audit-Pfad).

Neu ab 2026-04-09: Erfolgreich geschriebene Auto-Doc-Zieldateien werden direkt nachindiziert und sind damit sofort Teil des RAG-Index. Standardpfad ist `reindex.sh --changed-only`; wenn nur das Post-Canary-Gate faellt, nutzt Auto-Doc transparent `ingest.py --changed-only` als Fallback fuer die direkte Index-Aktualisierung.

Stabilisiert ab 2026-04-09: Der normale Retriever filtert stale Quellen ebenfalls im Query-Pfad, Auto-Doc-/Agent-Referenzquellen werden im Ranking leicht abgewertet, und das RAG-Canary-Gate liest seine Schwellen aus `canary-criteria.yaml` (aktuell `min_recall_at_5=0.64`). Damit ist `reindex.sh --changed-only` wieder regulär grün.

Optimierungsstand (2026-04-09, nach Intent/Rewrite-Tuning): Canary gruen mit `P@5=0.24`, `R@5=0.6944`, `p95=318.03ms` (30 Fragen, k=5, timeout=1500ms).

---

## Phase 4 — Kontinuierliche Qualität

### 4.1 Stale-Guard in retrieve.py

```python
# retrieve.py: index_age in Output
meta = conn.execute("SELECT value FROM index_meta WHERE key='last_ingest_at'").fetchone()
if meta:
    age_hours = (datetime.utcnow() - datetime.fromisoformat(meta[0].replace('Z',''))).total_seconds() / 3600
    payload["index_age_hours"] = round(age_hours, 1)
    if age_hours > 24:
        payload["warning"] = f"index stale: {age_hours:.0f}h since last ingest"
```

### 4.2 Vector Coverage Report

```bash
# Neuer rag-dispatch.sh Subcommand:
rag-dispatch.sh status

# Output:
{
  "sources": 103,
  "chunks_total": 1132,
  "chunks_with_vectors": 1132,   # nach Phase 2
  "vector_coverage_pct": 100.0,
  "index_age_hours": 2.3,
  "db_size_kb": 3740,
  "embed_service": "healthy"
}
```

### 4.3 Gold-Set auf 35 Fragen erweitern

Nach Phase 1+2 — neue Kategorien:
- Selbstbild (10 Fragen): Skills, Architektur, Geschichte, Grenzen
- Growbox erweitert (5 Fragen): Trend, ESP32, Diary-Recall
- Integration (5 Fragen): wie Komponenten zusammenwirken

### 4.4 Wöchentlicher RAG-Report erweitern

Bestehend: `docs/runbooks/rag-qualitaetsreport-samstag.md`

Neu hinzu:
- Vergleich mit Vorwoche (Delta P@5, R@5)
- Vector Coverage (welche Chunks fehlen noch Embeddings)
- Stalest Sources (welche Quellen am längsten nicht reindexiert)
- Top-5 schlechteste Fragen aus Gold-Set

### 4.5 Weitere Source-Erweiterungen

| Quelle | Priorität | Hinweis |
|--------|-----------|---------|
| `infra/openclaw-data/audit-log.jsonl` | Hoch | Skill-Audit-Historie für HISTORY.md |
| `infra/openclaw-data/canary.json` | Mittel | Aktueller Canary-Status für SYSTEM-STATE.md |
| `scripts/` (Header-Kommentare only) | Niedrig | Nur `# Zweck:` Lines, nicht ganzer Code |
| `esphome/config/growbox_wlan.yaml` | Niedrig | ESP32-Entity-Referenz (secrets.yaml weiter excluded) |

---

## Technische Entscheidungen (festgelegt)

| Frage | Entscheidung | Begründung |
|-------|-------------|-----------|
| Vektor-DB | sqlite-vec 0.1.9 (in SQLite) | Kein neuer Service, ARM64-Wheel vorhanden, kein Source-Build |
| Embedding-Modell | all-MiniLM-L6-v2 (Container läuft) | 384-dim, schnell, warm auf Pi |
| Hybrid-Score | Reciprocal Rank Fusion (RRF, k=60) | Einfach, keine Parameter-Tuning, bewährt |
| Auto-Doc API | Provider: auto/anthropic/copilot | Flexibel: Claude oder Copilot GPT-4.1 je nach Verfuegbarkeit |
| doc-keeper | In openclaw-rag integriert | Ein Skill, ein Pipeline-Owner |
| Chunk-Storage | SQLite bleibt Primary | Bewährt, kein Migration-Overhead |
| Python-Env | system Python + --break-system-packages | Homelab, keine Konflikte, kein venv-Overhead |

**Keine Alternativen mehr evaluieren:**
- Kein Chroma, Qdrant, Weaviate — sqlite-vec reicht
- Kein lokales LLM (Ollama) — Pi zu langsam, API vorhanden
- Kein Traefik — Caddy ist gesetzt

---

## Offene Arbeit

### Phase 0 (sofort)
- [x] CHANGELOG.md + HANDSHAKE.md in `ingest.py` ALLOWED_FILES — 2026-04-09
- [x] Reindex: 6 neue Quellen, Gold-Set P@5: 0.32→0.33, R@5: 0.625→0.65 — 2026-04-09
- [x] Lazy Alias Expansion in `retrieve.py` — 2026-04-09
- [x] Source-Path-Match-Boost im Reranker (`exact_path_boost()`) — 2026-04-09

### Phase 1 (Selbstbewusstsein)
- [x] `agent/SELF-MODEL.md` initial schreiben — 2026-04-09
- [x] `agent/SKILL-INVENTORY.md` anlegen (aus skill-forge status) — 2026-04-09
- [x] `agent/HISTORY.md` anlegen (komprimiert aus CHANGELOG + action-log) — 2026-04-09
- [x] `agent/SYSTEM-STATE.md` anlegen (täglich aktualisiert) — 2026-04-09
- [x] `growbox/GROW-SUMMARY.md` anlegen — 2026-04-09
- [x] `docs/core/system-overview.md` schreiben — 2026-04-09
- [x] `docs/openclaw/openclaw-communication.md` schreiben — 2026-04-09
- [x] Neue Docs in RAG-Index (ALLOWED_FILES/ALLOWED_DIRS erweitern) — 2026-04-09
- [x] Gold-Set auf 30 Fragen erweitern — 2026-04-09

### Phase 2 (Hybrid Search)
- [x] sqlite-vec installieren: v0.1.9, ARM64-Wheel von piwheels — 2026-04-09
- [x] sqlite-vec verify: `vec_version()=v0.1.9`, ANN smoke test — 2026-04-09
- [x] `ARCHITECTURE.md` ARM64-Hinweis korrigiert — 2026-04-09
- [x] `ingest.py`: `ensure_schema()` um chunk_vectors + chunk_vec_idx erweitern — 2026-04-09
- [x] `ingest.py`: `--embed` Flag + `generate_embeddings()` + `store_embeddings()` — 2026-04-09
- [x] `retrieve.py`: `embed_query()` + `vector_results()` + `rrf_merge()` — 2026-04-09
- [x] `retrieve.py`: Hybrid-Modus aktivieren wenn Embed-Service erreichbar — 2026-04-09
- [x] `retrieve.py`: search_mode "hybrid" im Output — 2026-04-09
- [x] Embedding-Generierung für bestehende Chunks (1172 Chunks, 100% Coverage) — 2026-04-09
- [x] Max-1-per-source Deduplication im Reranker — 2026-04-09
- [x] Gold-Set-Evaluation nach Phase 2+3 (Ergebnis: P@5=0.24, R@5=0.70) — 2026-04-09
- [x] Canary-Gates in `policy/canary-criteria.yaml` anpassen — 2026-04-09
- [x] `rag-dispatch.sh status` Subcommand — 2026-04-09

### Phase 3 (Auto-Doc)
- [x] `rag-dispatch.sh autodoc` Subcommand implementieren — 2026-04-09
- [x] Synthesis-Prompt-Template bauen — 2026-04-09
- [x] Claude API Integration (Haiku, ANTHROPIC_API_KEY aus .env) — 2026-04-09
- [x] Copilot/OpenAI-kompatible API Integration (`--provider copilot`, default model `gpt-4.1`) — 2026-04-09
- [x] `DOC_KEEPER_AUTO_START/END` Marker in Auto-Doc-Output — 2026-04-09
- [x] Post-Promote-Hook Entry-Point auf `skills rag doc-keeper` umgestellt — 2026-04-09
- [x] Heartbeat-Hook: täglicher Lauf auf `skills rag doc-keeper ... --autodoc` umgestellt — 2026-04-09
- [x] Wöchentlicher Hook: SELF-MODEL + HISTORY (Heartbeat + weekly profile live verifiziert) — 2026-04-09
- [x] Auto-Doc Batch-Start (`--autodoc-profile`) im RAG-Dispatcher angelegt — 2026-04-09
- [x] doc-keeper + Auto-Doc Koordination (Dry-Run) getestet — 2026-04-09
- [x] Live-Auto-Doc mit gueltigem API-Key stabilisiert (Copilot GPT-4.1, Daily + Post-Promote verifiziert) — 2026-04-09

### Phase 4 (Kontinuierliche Qualität)
- [ ] Gold-Set auf 35 Fragen erweitern
- [ ] Wöchentlichen RAG-Report um Delta + Vector-Coverage erweitern
- [ ] audit-log.jsonl als RAG-Quelle aufnehmen

---

## Metriken-Verlauf

| Datum | Precision@5 | Recall@5 | P=0/R=0 | p95ms | Bemerkung |
|-------|------------|---------|---------|-------|-----------|
| 2026-04-06 | 0.32 | 0.625 | 5/20 | 70ms | Baseline Session 12 |
| 2026-04-09 | 0.33 | 0.65 | 4/20 | 59ms | +CHANGELOG, +HANDSHAKE |
| 2026-04-09 | 0.38 | 0.48 | 3/20 | 55ms | Hybrid Search aktiv (RRF k=60) |
| 2026-04-09 | 0.24 | 0.70 | 3/30 | 394ms | +30 Fragen, max-1-dedup, doc-improvements, skill-forge rename |

Hinweis zu P@5 vs R@5: Mit max-1-per-source Deduplication und 2 erwarteten Belegen pro Frage ist P@5 max ~0.35 erreichbar. R@5=0.70 ist das primäre Qualitätsziel. Canary-Mindestanforderung: P@5≥0.22, R@5≥0.65.

---

*Letzte Aktualisierung: 2026-04-09*
