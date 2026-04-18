---
name: autodoc
description: Eigenständige Dokumentsynthese aus RAG-Kontext. Generiert versionierte Markdown-Dokumente (Systemzustand, Grow-Zusammenfassung, Skill-Inventar etc.) via LLM auf Basis lokaler RAG-Retrieval-Ergebnisse. Kein RAG-Rückschreiben – nur Quell-Retrieval.
---

# autodoc

## Zweck

Synthesisiert aktuelle Markdown-Dokumente aus RAG-Kontext (retrieve-only) über ein LLM.
Eigenständiger Skill – kein Teil des RAG-Skills. Nutzt RAG ausschließlich als Lesequelle.

Schreibt keine Daten zurück in den RAG-Index. Nur explizit promotete Outputs können
per manuellem Trigger in den RAG-Index aufgenommen werden.

## Trigger

Nutze autodoc wenn:
- ein Systemzustand-Dokument (`SYSTEM-STATE.md`) aktualisiert werden soll
- eine Growbox-Zusammenfassung generiert werden soll
- Skill-Inventar oder Betriebshistorie synthetisiert werden soll
- ein täglicher/wöchentlicher Dokumentations-Digest läuft (via Heartbeat)

## Commands

Einzelnes Dokument synthetisieren:

```bash
~/scripts/skills autodoc "system-state" --output /home/steges/agent/SYSTEM-STATE.md
~/scripts/skills autodoc "growbox-summary" --output /home/steges/growbox/GROW-SUMMARY.md
~/scripts/skills autodoc "system-state" --output /home/steges/agent/SYSTEM-STATE.md --provider copilot --model gpt-4.1
~/scripts/skills autodoc "system-state" --output /home/steges/agent/SYSTEM-STATE.md --dry-run
```

Profil-basierter Lauf:

```bash
~/scripts/skills autodoc profile daily
~/scripts/skills autodoc profile weekly
~/scripts/skills autodoc profile post-promote
~/scripts/skills autodoc profile daily --dry-run --provider copilot --model gpt-4.1
```

## Profile

| Profil | Outputs |
|--------|---------|
| `daily` | `agent/SYSTEM-STATE.md`, `growbox/GROW-SUMMARY.md`, `agent/TO-DO.md` |
| `post-promote` | `agent/SKILL-INVENTORY.md` |
| `weekly` | `agent/SELF-MODEL.md`, `agent/HISTORY.md` |

## Provider

| Flag | Verhalten |
|------|-----------|
| `--provider auto` | Nimmt ersten verfügbaren Key (Anthropic vor Copilot) |
| `--provider anthropic` | Anthropic Claude Haiku |
| `--provider copilot` | Copilot/OpenAI-kompatibler Endpoint |

## Dispatch-Struktur

```
scripts/autodoc-dispatch.sh   CLI-Dispatcher (topic / profile)
```

## Abhängigkeiten

- RAG retrieve (`agent/skills/openclaw-rag/scripts/retrieve.py`) – nur lesend
- RAG reindex (`agent/skills/openclaw-rag/scripts/reindex.sh`) – nur nach erfolgreichem Write

## Scope-Grenzen

| Erlaubt | Verboten |
|---------|----------|
| RAG retrieval lesen | RAG-Index direkt beschreiben |
| Output-Dokumente schreiben | Secrets in Outputs |
| Index-Refresh nach eigenem Write | Direkte Skill-Status-Änderungen |
| Dry-Run Preview | Destructive Aktionen |

## Lifecycle

- Skill ist eigenständig; kein Canary-Gate für reguläre Nutzung
- Wird vom Heartbeat via `~/scripts/skills autodoc profile daily/weekly` aufgerufen
- Doc-Keeper ruft `~/agent/skills/autodoc/scripts/autodoc-dispatch.sh profile <profil>` direkt auf
