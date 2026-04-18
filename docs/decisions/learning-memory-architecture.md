# ADR: Learning Memory Architektur fuer Pilab

- Status: akzeptiert
- Datum: 2026-04-10
- Scope: lokale Learn+RAG Integration (`openclaw-rag`, `learn`, `heartbeat`)

## Kontext

Pilab laeuft lokal auf Raspberry Pi 5 (arm64), 24/7, Docker-basiert.

Rahmenbedingungen:
- RAG ist bereits lokal produktiv (BM25 + Vector).
- Learn ist die zentrale Wissensquelle fuer Betriebs-Learnings.
- Sicherheitsregel: keine Writes aus Secrets-Pfaden.
- Betriebsziel: moeglichst wenig externe Abhaengigkeiten und klare Ownership im Skill-Layer.

## Entscheidung

Learning Memory wird lokal ueber die Kombination aus Learn-Skill und RAG umgesetzt.

- `learn` bleibt Memory-Owner (Distill, Struktur, IDs in `.learnings/LEARNINGS.md`).
- `openclaw-rag` bleibt Retrieval-Owner (semantische Suche ueber lokale Quellen).
- `heartbeat` beobachtet lokale Pipeline-Qualitaet (ohne externe Memory-Bridge).

## Begruendung

- Geringere Betriebs-Komplexitaet: keine externe Bridge/zusatzliches Runtime-Tool.
- Klare Verantwortlichkeiten in bestehenden Skills statt neue Skill-Domain.
- Lokal besser testbar und reproduzierbar.
- Reduzierte Ausfallflaeche im 24/7 Pi-Betrieb.

## Konsequenzen

- Kein externer Memory-Fallback in `rag-dispatch retrieve`.
- Learnings bleiben lokal nachvollziehbar und werden via RAG semantisch durchsuchbar.
- Erweiterungen erfolgen im Learn-Skill und nicht als separate Memory-Skill-Domain.

## Akzeptanzkriterien fuer diese Entscheidung

- `learn weekly --json` liefert stabil `ok` oder `skipped`.
- `rag-dispatch retrieve` liefert lokale semantische Treffer ohne externen Fallback.
- Quellenkennzeichnung bleibt transparent (`source`, `section`).
- Keine sensiblen Quellen werden geschrieben/indexiert.

## Re-Evaluation Trigger

Neuentscheidung noetig, wenn einer der Punkte eintritt:
- Lokale Learn+RAG Pipeline deckt Recall-Anforderungen nicht mehr ab.
- Betriebsaufwand steigt durch lokale Pflege unvertretbar.
- Externe Abhaengigkeit bringt nachweislich klaren Mehrwert bei gleicher Stabilitaet.
