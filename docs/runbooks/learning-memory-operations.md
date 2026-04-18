# Runbook: Learning Memory Betrieb

Stand: 2026-04-10

## Zweck

Betriebsanleitung fuer lokale Learn+RAG Memory-Nutzung ohne externe Bridge.

## Voraussetzungen

- Lokaler RAG-Index vorhanden
- Learn-Skill aktiv (`~/scripts/skills learn ...`)

## Setup

1. Learn Weekly pruefen:
   ```bash
   ~/scripts/skills learn weekly --json
   ```
2. RAG-Status pruefen:
   ```bash
   bash /home/steges/agent/skills/openclaw-rag/scripts/rag-dispatch.sh status
   ```
3. Such-Smoke:
   ```bash
   bash /home/steges/agent/skills/openclaw-rag/scripts/rag-dispatch.sh retrieve "openclaw heartbeat" --limit 3
   ```

## Backup/Restore

Relevante lokale Daten:
- `~/.learnings/LEARNINGS.md`
- `/home/steges/infra/openclaw-data/rag/index.db`

Backup (manuell):
```bash
mkdir -p ~/backups/$(date +%F)
cp ~/.learnings/LEARNINGS.md ~/backups/$(date +%F)/LEARNINGS.md
cp /home/steges/infra/openclaw-data/rag/index.db ~/backups/$(date +%F)/rag-index.db
```

## Reindex / Repair

1. Index neu aufbauen/auffuellen:
   ```bash
   bash /home/steges/agent/skills/openclaw-rag/scripts/rag-dispatch.sh reindex --changed-only --embed-backfill
   ```
2. Suchprobe auf Referenzbegriff:
   ```bash
   bash /home/steges/agent/skills/openclaw-rag/scripts/rag-dispatch.sh retrieve "docs operations" --limit 3
   ```
3. Bei anhaltendem Fehler: Index-Snapshot wiederherstellen und Reindex erneut fahren.

## Fehlerbilder

- `learn weekly failed`:
   - Ursache: inkonsistente State-Datei oder Schreibproblem.
   - Aktion: `learn-weekly.json` pruefen und Weekly-Lauf erneut starten.

- `retrieve failed` / `status failed`:
   - Ursache: RAG-Index/Embedding-Pfad inkonsistent.
   - Aktion: Reindex mit Embed-Backfill erneut ausfuehren.

## Betriebschecks

Taeglich:
```bash
~/scripts/skills learn show | tail -n 20
bash /home/steges/agent/skills/openclaw-rag/scripts/rag-dispatch.sh status
```

Woechentlich:
```bash
~/scripts/skills learn weekly --json
bash /home/steges/agent/skills/openclaw-rag/scripts/rag-dispatch.sh reindex --changed-only --embed-backfill
```
