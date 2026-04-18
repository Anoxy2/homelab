# Session Handover

Kurzleitfaden fuer die naechste Session, damit Todo-Umsetzung und Doku konsistent bleiben.

## Reihenfolge (verbindlich)

1. Implementieren
2. Validieren
3. Dokumentieren
4. Changelog bei Verhaltens-/Prozessaenderung
5. Erst dann Todo-Eintrag entfernen

Quelle der Regel:
- `/home/steges/.github/instructions/todo-lifecycle.instructions.md`

## Start-Check (5 Minuten)

1. `cat /home/steges/CLAUDE.md`
2. `cat /home/steges/agent/HANDSHAKE.md`
3. `cat /home/steges/docs/operations/open-work-todo.md`
4. `~/scripts/skill-forge policy lint`
5. `~/scripts/skill-forge status`

## Pflichtchecks bei Skill-Manager-Aenderungen

- `~/scripts/skill-forge policy lint`
- `bash -n` fuer geaenderte Shell-Skripte
- mind. ein Smoke-Check auf den geaenderten Pfad

Wenn ein Check fehlschlaegt:
- keine Todo-Entfernung
- Fehler zuerst beheben oder sauber als Blocker dokumentieren

## Doku-Mapping

- Lifecycle/Skill-Manager-Verhalten: `docs/skills/skill-forge-governance.md`
- Prozess/Governance-Aenderung: `CHANGELOG.md`
- Service/Runtime/Architektur: `docs/core/services-and-ports.md`, `docs/core/system-architecture.md`, `docs/operations/maintenance-and-backups.md`
- Handover-Konsistenz: `README.md`, `docs/operations/open-work-todo.md` und `docs/operations/session-handover.md` immer gemeinsam aktuell halten

## Offene Schwerpunkte (aktuell)

Aktuelle Prioritaeten ausschliesslich in `docs/operations/open-work-todo.md` gepflegt.

Hinweis zur Historie:
- Abgeschlossene Arbeiten und Session-Historie stehen ausschliesslich in `CHANGELOG.md`.

## Abschluss vor Session-Ende

1. Relevante Dokus aktualisieren
2. Offene Todos pruefen und nur erledigte entfernen
3. Kurzstatus in Commit/Session-Notiz festhalten
