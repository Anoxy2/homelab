# Learning Memory Datei-zu-Raum Mapping

Stand: 2026-04-10

Diese Zuordnung ist die kanonische Mapping-Basis fuer Learning-Memory-Recall im Pilab.

## Ziel

- Konsistente Raumzuordnung fuer semantische Suche
- Reproduzierbare Herkunftslogik innerhalb des lokalen RAG-Stacks
- Klare Abgrenzung sensibler, nicht erlaubter Quellen

## Mapping-Tabelle

| Quelle (Glob) | Wing | Room | Zweck |
|---|---|---|---|
| `docs/operations/**` | `wing_ops` | `room_operations` | Betriebsablaeufe, Wartung, Runbooks |
| `docs/skills/**` | `wing_skills` | `room_skills` | Skill-Governance, Integrationsmuster |
| `docs/decisions/**` | `wing_architecture` | `room_decisions` | ADRs und Architekturentscheidungen |
| `growbox/**` | `wing_growbox` | `room_growbox` | Grow-Kontext, Schwellwerte, Tagebuch |
| `agent/*.md` | `wing_agent_context` | `room_agent_context` | Agent-Identitaet, Handover, Betriebskontext |

## Namenskonvention

- Wing: `wing_<domain>`
- Room: `room_<topic>`
- Nur ASCII, lowercase, underscore
- Keine dynamischen Namen aus User-Input ohne Normalisierung

## Sperrlisten (nie schreiben/indexieren)

- `.env`, `.env.*`
- `**/secrets.yaml`
- Dateien mit offensichtlichen Token/Passwort-Inhalten
- `**/memory/**` mit sensiblen Inhalten

## Integrationshinweis

- `openclaw-rag` markiert Quellenherkunft explizit mit `source` und `section`
- Bei Mapping-Miss gilt: kein Write, stattdessen Warnung + lokale RAG-Suche
