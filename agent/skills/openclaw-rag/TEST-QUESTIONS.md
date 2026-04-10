# RAG Test Questions (Expected Evidence)

1. Frage: Welche Services laufen auf dem Pi und auf welchen Ports?
Expected evidence:
- `docs/core/services-and-ports.md`
- `README.md`

2. Frage: Welche Zielwerte gelten fuer die Growbox-Luftfeuchtigkeit?
Expected evidence:
- `growbox/THRESHOLDS.md`

3. Frage: Wie fuehre ich den taeglichen Skill-Manager-Check aus?
Expected evidence:
- `docs/skills/skill-forge-governance.md`
- `agent/skills/skill-forge/SKILL.md`

4. Frage: Welche Risiken gibt es bei Pi-hole im Betrieb?
Expected evidence:
- `CLAUDE.md`
- `docs/core/security-baseline.md`

5. Frage: Wie sieht das OpenClaw-Update-Playbook aus?
Expected evidence:
- `docs/operations/maintenance-and-backups.md`
- `docs/operations/open-work-todo.md`

Pass criteria:
- Jede Antwort nennt belastbare Quelle(n).
- Keine erfundenen Pfade/Kommandos.
- Unsicherheit wird explizit gemacht, wenn Evidenz fehlt.
