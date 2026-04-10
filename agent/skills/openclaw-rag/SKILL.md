---
name: openclaw-rag
description: Retrieval-augmented capability for homelab knowledge with source-grounded answers and update-safe lifecycle gates.
---

# openclaw-rag

## Purpose
Provide stable, source-grounded retrieval for OpenClaw across docs, growbox context, and selected agent runbooks.

## Trigger
Use when users ask for:
- operating procedures or runbooks
- growbox thresholds/entities/history explanations
- architecture/service references from local docs
- "what do we know about X" style knowledge queries
- direct lookup prompts like "welche ports", "welche zielwerte", "daily skill-forge check", "pi-hole risiko"

## Steps
1. Validate query intent and sensitivity.
2. Retrieve only from approved local sources.
3. Return concise answer with evidence references.
4. If evidence is weak, state uncertainty and suggest next check.
5. If source files changed recently, prefer reindex before declaring stale results.

## Commands

Ad-hoc retrieval:

```bash
python3 ~/agent/skills/openclaw-rag/scripts/retrieve.py "Welche Services laufen auf dem Pi und auf welchen Ports?"
```

Full ingest:

```bash
python3 ~/agent/skills/openclaw-rag/scripts/ingest.py --json
```

Incremental reindex:

```bash
~/agent/skills/openclaw-rag/scripts/reindex.sh
```

Gold-Set Evaluation:

```bash
python3 ~/agent/skills/openclaw-rag/scripts/evaluate-goldset.py --limit 5 --timeout-ms 1500
```

Skill-manager contract names:
- `rag.retrieve`
- `rag.reindex`
- `doc.keeper` (ueber `rag doc-keeper run`)

Doc-Keeper (integriert in RAG):

```bash
~/scripts/skills rag doc-keeper run --reason "manual"
~/scripts/skills rag doc-keeper run --daily --autodoc
```

Auto-Doc (Topic-Synthese):

```bash
~/scripts/skills rag autodoc "system-state" --output /home/steges/agent/SYSTEM-STATE.md
~/scripts/skills rag autodoc "system-state" --output /home/steges/agent/SYSTEM-STATE.md --provider copilot --model gpt-4.1
~/scripts/skills rag doc-keeper run --daily --autodoc --autodoc-provider copilot --autodoc-model gpt-4.1
```

Nach erfolgreichem Live-Write fuehrt Auto-Doc automatisch einen direkten Index-Refresh aus, damit neue Marker-Bloecke sofort retrieval-faehig sind. Standardpfad ist `reindex.sh --changed-only`; faellt nur das Post-Canary-Gate, nutzt Auto-Doc transparent `ingest.py --changed-only` als Fallback.

## Boundaries
- No secrets in outputs.
- No indexing of `.env`, `secrets.yaml`, password stores, or token files.
- Respect incident freeze and policy gates for lifecycle actions.
- Promotion requires canary window + provenance.

## Approved Sources
- `/home/steges/docs/`
- `/home/steges/growbox/`
- `/home/steges/agent/*.md`

## Retrieval Behavior
- Prefer sources that answer the question directly over pointer-only references.
- Surface `section` and `source` so follow-up inspection is cheap.
- For "what do we know about X" queries, automatically treat RAG as the first lookup path.
- If no convincing evidence is found, say so explicitly instead of inferring.

## Related Docs
- `/home/steges/agent/skills/openclaw-rag/ARCHITECTURE.md`
- `/home/steges/agent/skills/openclaw-rag/GOLD-SET.json`
- `/home/steges/agent/skills/openclaw-rag/RAG-SOURCES.md`
- `/home/steges/agent/skills/openclaw-rag/TEST-QUESTIONS.md`

## Lifecycle
- Author via: `~/scripts/skill-forge author skill openclaw-rag --mode auto --reason "RAG capability"`
- Canary start: `~/scripts/skill-forge canary start openclaw-rag 24`
- Promote: `~/scripts/skill-forge canary promote openclaw-rag`
- Rollback: `~/scripts/skill-forge rollback openclaw-rag`
- Provenance required before production promotion.
