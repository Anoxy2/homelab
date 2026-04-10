# Runbook: RAG Reindex Failure Recovery

Ziel: Sichere Wiederherstellung bei fehlgeschlagenem Reindex (partial index, corruption, rollback).

## Symptome

- `reindex.sh` beendet sich mit Fehlercode.
- Retrieval liefert leere/inkonsistente Treffer.
- SQLite-Fehler in Logs (`database disk image is malformed`, Lock-Fehler).
- Reindex-Status zeigt `post_canary_*` Fehler im Feld `detail`.

## Sofortmassnahmen

1. Keine weiteren Reindex-Runs parallel starten.
2. Aktuellen Zustand sichern (forensisch), bevor etwas ersetzt wird.

```bash
cd ~
cp infra/openclaw-data/rag/index.db infra/openclaw-data/rag/index.db.failure.$(date +%F-%H%M%S)
```

## Diagnose

```bash
# Integritaet pruefen
sqlite3 ~/infra/openclaw-data/rag/index.db 'pragma integrity_check;'

# Groesse/mtime pruefen
ls -lh ~/infra/openclaw-data/rag/index.db

# Letzte Reindex-Ausgaben (falls vorhanden)
ls -lah ~/infra/openclaw-data/rag | cat

# Letzten Reindex-Status inkl. Gate-Detail prüfen
cat ~/infra/openclaw-data/rag/.reindex.status
```

## Gate-Verhalten (verbindlich)

- Nach erfolgreichem `ingest.py` und bestandenem `quick_check` läuft automatisch ein Post-Reindex-Canary (`rag-canary-smoke.sh --json`).
- Nur bei bestandenem Canary wird Reindex als `success(post_canary_passed)` markiert.
- Bei Canary-Fehler/Timeout wird auf den letzten Snapshot zurückgerollt (falls vorhanden) und der Reindex als `failed(post_canary_...; restored_snapshot)` markiert.
- Falls kein Snapshot vorhanden ist, bleibt der Lauf auf `failed(post_canary_...; no_snapshot)`.

Optionaler Tuning-Parameter:

```bash
# Timeout fuer Post-Reindex-Canary (Sekunden, default: 120)
export RAG_POST_CANARY_TIMEOUT_SECONDS=180
```

## Recovery-Pfade

## Entscheidungsbaum (degraded retrieval)

1. `health-check.sh` zeigt `FAIL RAG Reindex State` oder `FAIL RAG Chunk Drift`:
	- Primarpfad: Snapshot-Restore/Neuaufbau (Pfad B)
2. `health-check.sh` zeigt `WARN RAG Sanity Query (search_mode=none)`:
	- Primarpfad: Sanity-Query + gezielter Reindex (Pfad C)
3. Retrieval ist langsam/instabil, aber Index-Integritaet ist `ok`:
	- Primarpfad: Timeout-Loop-Diagnose (Pfad D)
4. Reindex/Canary meldet `post_canary_*`:
	- Primarpfad: Gate-Fail-Analyse und Wiederherstellung (Pfad E)

### A) Partial Index (nicht korrupt, aber unvollstaendig)

```bash
~/agent/skills/openclaw-rag/scripts/reindex.sh
```

Danach Smoke-Query:

```bash
python3 ~/agent/skills/openclaw-rag/scripts/retrieve.py "Welche Zielwerte gelten fuer die Growbox-Luftfeuchtigkeit?"
```

### B) Korruption bestaetigt

1. Letztes gesundes Snapshot/Backup zurueckspielen (falls vorhanden).
2. Wenn kein valider Snapshot vorhanden: kompletter Neuaufbau.

```bash
# Vorsicht: ersetzt den bestehenden Index
rm -f ~/infra/openclaw-data/rag/index.db
python3 ~/agent/skills/openclaw-rag/scripts/ingest.py --json
```

3. Retrieval-Smoketest ausfuehren.

### C) Stale Index / Degraded Retrieval (kein harter Korruptionsbefund)

Indikatoren:
- `RAG Index Freshness` ist alt.
- `RAG Sanity Query` liefert keine/zu wenige Treffer.
- Canary kann durchlaufen, aber Recall/Precision sinken.

```bash
# 1) Schnellzustand
cat ~/infra/openclaw-data/rag/.reindex.status

# 2) Inkrementeller Reindex (changed-only)
~/agent/skills/openclaw-rag/scripts/reindex.sh

# 3) Kurze Qualitaetsprobe
python3 ~/agent/skills/openclaw-rag/scripts/evaluate-goldset.py --limit 5 --timeout-ms 1500
```

Wenn weiter degraded:
- Snapshot-Restore pruefen, danach erneut Evaluate + Canary fahren.

### D) Timeout-Loop bei Retrieval/Reindex

Indikatoren:
- wiederholte Timeouts in Evaluate/Canary
- `post_canary_timeout` im Reindex-Detail

```bash
# Reindex- und Canary-Timeout temporar erweitern
export RAG_REINDEX_TIMEOUT_SECONDS=900
export RAG_POST_CANARY_TIMEOUT_SECONDS=180

# Erneuter Lauf
~/agent/skills/openclaw-rag/scripts/reindex.sh
~/agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh --json
```

Wenn Timeouts bleiben:
- Query-/Source-Drift analysieren (Goldset-Fragen, neue Quellen, Chunk-Budget)
- keine Promote-Entscheidung ohne stabile Canary-Passage

### E) Post-Reindex-Canary-Gate fehlgeschlagen

Indikatoren im Status-Detail:
- `post_canary_failed`
- `post_canary_timeout`
- `post_canary_error`

```bash
cat ~/infra/openclaw-data/rag/.reindex.status
tail -n 10 ~/infra/openclaw-data/action-log.jsonl
```

Entscheidung:
- Mit `restored_snapshot`: Snapshot ist aktiv, erst Diagnose, dann neuer Reindex-Versuch.
- Mit `no_snapshot`: priorisiert Snapshot-Basis wiederherstellen oder Full-Rebuild (Pfad B).

## Rollback

Wenn neuer Build unbrauchbar ist:

```bash
# Beispiel: auf vorher gesicherten Stand zurueck
cp ~/infra/openclaw-data/rag/index.db.failure.<TIMESTAMP> ~/infra/openclaw-data/rag/index.db
```

Danach Query-Smoketest wiederholen.

## Abschluss-Check

```bash
~/scripts/health-check.sh
python3 ~/agent/skills/openclaw-rag/scripts/retrieve.py "Wie ist der Recovery-Ablauf bei Pi-hole DNS-Ausfall?"
```

## Nacharbeit

- Ursache dokumentieren (Out-of-memory, Locking, Datenquelle, manueller Eingriff).
- Falls wiederkehrend: Reindex-Fenster entzerren und Quelle/Chunking-Regeln ueberarbeiten.
