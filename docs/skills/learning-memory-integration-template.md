# Learning Memory Integration Template (RAG + Learn)

Ziel: lokales Learning-Memory als standardisierte Vorlage fuer bestehende Pilab-Skills nutzen.

## Zielbild

- Semantic Search mit lokalem RAG (BM25 + Vector)
- Learn als zentrale lokale Memory-Quelle fuer Betriebsbeobachtungen
- Einheitliches RAG-Datei-Mapping auf Wings/Rooms
- Kein direkter Write in sensible Secrets/privaten Datenpfaden

## Referenz-Patterns aus Learn + RAG

- Learn Weekly Distill: stabile Learning-IDs + Zusammenfassungen
- RAG Retrieve: semantische Suche ueber lokale Quellen
- Struktur: `wing -> room -> drawer` bleibt als internes Mapping-Muster
- Optional: Fakten-Relationen als spaetere Erweiterung

## Pilab Mapping

### RAG-Datei-zu-Wing/Room

- `docs/operations/*` -> Wing `wing_ops`, Room `room_operations`
- `docs/skills/*` -> Wing `wing_skill_forge`, Room `room_skills`
- `growbox/*` -> Wing `wing_growbox`, Room `room_growbox`
- `agent/*.md` -> Wing `wing_rag`, Room `room_agent_context`
- Room-Konvention: `room_<topic>` (z. B. `room_health_checks`)
- Kanonische Mapping-Quelle: `docs/skills/learning-memory-file-room-mapping.md`

### Datenquellen

- Erlaubt: `docs/`, `growbox/`, ausgewaehlte `agent/*.md`
- Verboten: `.env`, `secrets.yaml`, Passwort- oder Token-Dateien
- Verbindliche Sicherheitsrichtlinie: `docs/skills/learning-memory-security-frame.md`

## Skill-Integrationsprofil

### 1) openclaw-rag

- Lokale semantische Suche als Default (`retrieve`)
- Kein externer Fallback-Pfad
- Antwort immer mit Source-Hinweis + Herkunft (`local-rag`)

### 2) learn

- Weekly-Learnings lokal in `.learnings/LEARNINGS.md` schreiben
- Learning-ID als Referenz im Eintrag mitfuehren
- Dedupe ueber Wochen-Status (`learn-weekly.json`)

### 3) heartbeat

- Tägliche/woechentliche Checks fuer lokale Pipelines (Learn, Scout, Tests)
- Kein externer Memory-Health-Check erforderlich
- Fehler in Telegram-Summary als normaler Task-Block

## Minimales Tool-Profil

- `skills learn weekly --json`
- `rag-dispatch retrieve <query>`
- `rag-dispatch status`

## Validierung (Definition of Done)

- Search-Smoke: 3 Queries, davon mindestens 2 mit relevanten Treffern
- Learn-Smoke: weekly distill liefert `ok` oder `skipped` ohne Fehler
- Sicherheitscheck: keine Write-Versuche auf gesperrte Pfade
- Laufzeitcheck: Heartbeat-Task faellt nicht durch Learn/RAG aus

## Rollout-Phasen

1. Phase A: lokales Learn-Weekly stabilisieren
2. Phase B: RAG-Indexabdeckung + semantische Qualitaet sichern
3. Phase C: Learn->RAG Signals fuer Priorisierung erweitern
4. Phase D: Metriken (Recall/Latenz/Hit-Rate) in weekly-report

Ops-Runbook: `docs/runbooks/learning-memory-operations.md`
Validierungskatalog: `docs/skills/learning-memory-validation-catalog.md`
