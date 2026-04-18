# Learning Memory Sicherheitsrahmen

Stand: 2026-04-10

Ziel: verbindliche Regeln, welche Daten im lokalen Learn+RAG Memory verarbeitet werden duerfen und welche strikt ausgeschlossen sind.

## Datenklassifizierung

- Klasse A (erlaubt): Betriebsdoku, Runbooks, Skill-Dokumentation, Architekturentscheidungen, growbox-Fachinhalte ohne Credentials.
- Klasse B (bedingt erlaubt): Agent-Kontextdateien (`agent/*.md`) nur ohne geheime Inhalte.
- Klasse C (verboten): Secrets, Tokens, Passwoerter, private Schluessel, `.env` und aehnliche Dateien.

## Erlaubte Quellen

- `docs/**`
- `growbox/**`
- ausgewaehlte `agent/*.md`

## Verbotene Quellen

- `.env`, `.env.*`
- `**/secrets.yaml`
- Passwort-/Token-/Key-Dateien
- Credentials in beliebigen Dateiformaten
- alle Dateien ausserhalb der erlaubten Quellliste

## Schutzregeln

- Default-Deny: neue Quellpfade sind verboten, bis sie explizit freigegeben sind.
- Read-first: lokale Recall-Pfade bleiben priorisiert, keine blind automatischen Massen-Writes.
- Dedupe vor Write: identische Learning-IDs werden nicht erneut geschrieben.
- Graceful Degrade: bei Teilfehlern bleibt lokaler RAG/Heartbeat funktionsfaehig.

## Logging & Nachvollziehbarkeit

- Jeder Learn/RAG-Task schreibt Observability-Signale in Audit-/Action-Log.
- Ergebniskennzeichnung im RAG-Pfad ueber `source` und `section`.
- Fehler werden als Warnsignal dokumentiert, aber nicht als Hard-Block fuer den Gesamtzyklus.

## Betriebsfreigabe-Kriterien

- `learn weekly` und `rag retrieve/status` stabil und reproduzierbar.
- Keine Writes aus Klasse-C-Quellen im Log nachweisbar.
- Woechentlicher Learn-Distill im Heartbeat aktiv.
- Runbook deckt Setup, Backup/Restore, Reindex/Repair ab.
