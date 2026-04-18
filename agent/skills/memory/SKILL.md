---
name: memory
description: Explizites, kategorisiertes Langzeitwissen fuer OpenClaw und steges. CRUD-Operationen auf memory.jsonl, lesbare Sicht in agent/MEMORY.md (RAG-approved). Trennung von learn (reaktiv) vs. memory (proaktiv).
---

# memory

## Zweck

Speichert explizites Wissen wie Entscheidungen, Patterns, Config-Fakten und Incident-Lernziele.
Kein automatisches Schreiben aus System-Events. Jeder Eintrag wird bewusst gesetzt.

## Wann nutzen

```bash
~/scripts/skills memory remember "<text>" [--cat decision|pattern|config|incident|fact] [--tags x,y] [--actor claude|steges|openclaw]
~/scripts/skills memory recall [--cat x] [--tag y] [--since 30d] [--json]
~/scripts/skills memory search "<query>" [--json]
~/scripts/skills memory forget <id>
~/scripts/skills memory update <id> "<new text>"
~/scripts/skills memory ingest
~/scripts/skills memory stats [--json]
```

## Storage

- Backing-Store: `skill-forge/.state/memory.jsonl` (JSONL, strukturiert)
- Lesbare Sicht: `/home/steges/agent/MEMORY.md` (bereits in ALLOWED_FILES in ingest.py)
- Chunk-Profil: agent-doc (280 tokens, 30 overlap)

## Kategorien

| Kategorie | Beispiel |
|-----------|---------|
| decision | "Caddy laeuft host-mode wegen host-mode Backends" |
| pattern | "Atomic writes via tempfile + os.replace() in allen State-Skripten" |
| config | "OpenClaw OPENCLAW_NO_RESPAWN=1 ist absichtlich" |
| incident | "Mocked tests bestanden, prod-Migration fehlgeschlagen -> immer echte DB in Tests" |
| fact | "Raspberry Pi 5, aarch64, 8GB RAM, NVMe 232GB" |

## Scope-Grenzen

| Erlaubt | Verboten |
|---------|----------|
| Lesen + Schreiben in memory.jsonl | Direkte RAG-Index-Aenderungen |
| Schreiben MEMORY.md (via ingest) | Lifecycle-Operationen |
| reindex.sh aufrufen (via ingest) | Secrets in Eintraegen |
