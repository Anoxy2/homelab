# Runbook: RAG Qualitaetsreport (Samstag)

Ziel: Woechentliche Qualitaetssicht auf Retrieval-Qualitaet und Betriebszustand.

## Frequenz

- Woechentlich samstags (empfohlen: vormittags, nach regularem Health-Check).

## Kernmetriken

- Precision@5: Anteil relevanter Treffer in Top-5.
- Recall@5: Anteil abgedeckter Soll-Information in Top-5.
- p95-Latenz: 95. Perzentil der Retrieval-Antwortzeit.
- Index-Freshness: Alter des `index.db` in Stunden.

## Ablauf

1. Basiszustand pruefen:

```bash
~/scripts/health-check.sh
```

2. RAG-DB Bestand prüfen:

```bash
sqlite3 ~/infra/openclaw-data/rag/index.db 'select count(*) as chunks, count(distinct source) as sources from chunks;'
```

3. Testfragen gegen Retrieval laufen lassen (Gold-Set, falls vorhanden):

```bash
python3 ~/agent/skills/openclaw-rag/scripts/retrieve.py "Welche Zielwerte gelten fuer die Growbox-Luftfeuchtigkeit?"
python3 ~/agent/skills/openclaw-rag/scripts/retrieve.py "Wie ist der Recovery-Ablauf bei Pi-hole DNS-Ausfall?"
python3 ~/agent/skills/openclaw-rag/scripts/evaluate-goldset.py --limit 5 --timeout-ms 1500
```

4. Ergebnis protokollieren (Template unten) und Trends vergleichen.

## Report-Template

```text
Datum:
Ausfuehrender:

Precision@5:
Recall@5:
p95-Latenz (ms):
Index-Freshness (h):

Anzahl Chunks:
Anzahl Quellen:

Auffaelligkeiten:
Massnahmen:
```

## Eskalation

- Wenn Index-Freshness > 48h: Reindex einplanen und Ursache dokumentieren.
- Wenn Precision/Recall deutlich fallen: Datenquellen und Chunking-Regeln pruefen.
- Wenn p95-Latenz steigt: Systemlast und embedding/retrieval Pfad pruefen.
