# RAG Sources and Exclusions

## Whitelist
- `/home/steges/docs/`
- `/home/steges/growbox/`
- `/home/steges/README.md`
- `/home/steges/CLAUDE.md`
- `/home/steges/CHANGELOG.md`
- `/home/steges/agent/SOUL.md`
- `/home/steges/agent/IDENTITY.md`
- `/home/steges/agent/USER.md`
- `/home/steges/agent/TOOLS.md`
- `/home/steges/agent/HEARTBEAT.md`
- `/home/steges/agent/HANDSHAKE.md`
- `/home/steges/agent/MEMORY.md`
- `/home/steges/docs/operations/open-work-todo.md`
- `/home/steges/infra/openclaw-data/action-log.jsonl` (letzte Eintraege, normalisiert)
- `/home/steges/agent/SELF-MODEL.md`
- `/home/steges/agent/SKILL-INVENTORY.md`
- `/home/steges/agent/HISTORY.md`
- `/home/steges/agent/SYSTEM-STATE.md`
- `/home/steges/agent/TO-DO.md` (autodoc-generiert aus open-work-todo; täglich)
- `/home/steges/growbox/GROW-SUMMARY.md` (via growbox/ Verzeichnis)

## Geplante Erweiterungen
- `/home/steges/infra/openclaw-data/audit-log.jsonl` (Phase 4)

## Exclusions (hard deny)
- `**/.env`
- `**/secrets.yaml`
- `**/passwd`
- `**/*.token.json`
- `/home/steges/infra/openclaw-data/credentials/`
- `/home/steges/infra/openclaw-data/identity/device.json`

## Log-Exclusions (explizit: Logs gehören in Loki, nicht in RAG)
- `**/mosquitto/log/**`
- `**/logs/**/*.log`
- `**/*.log`
- `/home/steges/infra/openclaw-data/logs/**`
- `/home/steges/infra/openclaw-data/rag/chunks/**`
- `/home/steges/loki/**`
- `/home/steges/promtail/**`
# Logs sind über den log-query Skill (Loki) live abrufbar.
# RAG-Whitelist ist positiv (nur explizit gelistete Quellen); diese Einträge
# dienen als Dokumentation und als Guardrail gegen versehentliche Erweiterungen.

## Chunking Rules
- `docs/`: target 420, overlap 50
- `docs/runbooks/`: target 320, overlap 40
- `growbox/diary/`: target 180, overlap 20
- `agent/skills/*`: target 320, overlap 40
- `agent/*.md`: target 280, overlap 30
- `action-log.jsonl`: target 120, overlap 0
- Prefer markdown headings as chunk boundaries.
- Keep headings with their first paragraph.
- Keep tables intact where possible.
- Add metadata: `source_path`, `section`, `updated_at`.

## Backpressure / Resume
- `ingest.py --max-chunks-per-run N` begrenzt einen Lauf ueber einen Soft-Budget-Cutoff.
- Nicht abgearbeitete Quellen werden in `infra/openclaw-data/rag/ingest-state.json` gespeichert.
- `ingest.py --resume` setzt mit der gespeicherten `remaining_sources` Queue fort.

## Sensitive Pre-Filter
- Exclude lines containing likely secrets before indexing.
- Pattern denylist (case-insensitive):
	- `api[_-]?key\s*[=:]`
	- `token\s*[=:]`
	- `password\s*[=:]`
	- `secret\s*[=:]`
	- `bearer\s+[a-z0-9._-]+`

## Evidence Format
Responses should include at least one source reference per factual claim.
