# PLAN: Self-Documentation (Auto-Doc Skill)

**Ziel:**
Alle Agentenaktionen, Changes, Self-Heal-Events und Incidents werden strukturiert, versioniert
und nachvollziehbar als Audit- und Change-Protokoll gefuehrt – unabhaengig vom RAG-Index.
Nur explizit promotete Eintraege gelangen in den RAG-Index.

## Architektur

1. auto-doc erstellt relevante Audit- und Ereignisdateien (Markdown / YAML / JSON)
2. Jeder Eintrag erhaelt Metadaten: Hash, Zeit, Tag, Status, `promote: true/false`
3. Nach Review werden promotefaehige Inhalte explizit per ingest.py/reindex.sh in den RAG-Index geschickt
4. Der RAG-Index bleibt schlank – nur persistentes Wissen, keine Noise- oder Eventlogs

## Meilensteine

- M1: Skill-Ordner `auto-doc` anlegen; Protokollformat und Rotationsregeln definieren
- M2: Hooks/Trigger in Skills, Event- und Self-Heal-Pipeline fuer auto-doc-Log schreiben
- M3: Digest/Reporting: Tages-/Wochen-Reports, Review-/Compare-Funktionen via CLI/Canvas
- M4: Integration in Doc Keeper fuer Human-Review (NICHT in RAG-Chunking)
- M5: RAG-Quellenfilter anpassen: auto-doc/ und event-logs aus Index ausschliessen
- M6: Historische Self-Doc-Chunks archivieren/readonly setzen (optional)

## Migration von bestehendem Self-Doc-RAG-Anteil

- [ ] RAG-SOURCES.md anpassen: auto-doc/ ausschliessen
- [ ] auto-doc als Erstschreiber fuer Self-Heal, Incident, Audit, Actions einrichten
- [ ] RAG-Indexierung beschraenken auf Policies, Runbooks, manuelle Doku
- [ ] Digest-Viewer/Skill dediziert (nicht RAG-abfragbar)

## Success-Kriterien

- Jede Aktion ist lueckenlos im auto-doc History-Log nachvollziehbar
- auto-doc Infos sind im Keeper editier-/reviewbar, nicht automatisch gechunkt
- RAG-Index schlank und frei von dynamischen Event-/Audit-Logs

Letztes Update: 2026-04-13
