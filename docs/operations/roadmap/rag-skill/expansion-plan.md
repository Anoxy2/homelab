# PLAN: OpenClaw RAG Skill – Ausbau & Analyse

## Ziel
Weiterentwicklung des bestehenden openclaw-rag Skills zu einem maximal robusten, wartbaren und fehlerresistenten Wissenssystem.

## Bestandsanalyse (Status 2026-04-13)
- SQLite + FTS5, Optional Vektor-Search sqlite-vec
- Embedding-Service via rag-embed
- Sources-Whitelist: file-basiert, fein granuliert
- Chunk-Regeln für verschiedene Source-Typen
- Sensitive Pre-Filter, Resume/backpressure, Evidence-Format
- Geplante Exclusions: eventlogs, autodoc

## Ausbauideen
- [ ] „Cold Storage“ für alte Chunks, Aging/Archiving-Prinzip für unnötige Wissenseinträge
- [ ] Review-Kommentare/Qualitäts-Metadaten direkt im Index speichern
- [ ] Live-Query-API für externe Tools (CLI/CANVAS)
- [ ] Mehrsprachige Chunking/Prompts
- [ ] Integration von auto-doc promote Workflow
- [ ] Bessere Policy/Exclusion-Handhabung (dynamisch per Tag, nicht nur Pfad)
- [ ] Statistik/Health-Monitoring für den Index (Chunk Count, Source Drift, Recency-Alerts)
- [ ] History- und Diff-Viewer für Chunks

## Technische Tasks
- [ ] RAG-SOURCES.md updaten: autodoc/* & eventlogs rausnehmen
- [ ] ingest.py erweitern: Promoted-Tags als Chunk-Source
- [ ] reindex.sh/CLI: Support für „Promote“/„Archive“/„Remove“ Workflows
- [ ] Embedding- und Retrieval-Health automatisieren

## Success-Kriterien
- Sauberer, wartbarer Index, kein Event-Log Noise
- „Promoted Knowledge“ stets auffindbar, Rest im Archiv/Autodoc

Letztes Update: 2026-04-13
