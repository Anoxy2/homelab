---
name: vuln-watch
description: Woechentliche GitHub-Suche nach neuen AI/LLM-Sicherheitsluecken (Prompt Injection, Jailbreak, LLM CVEs). Dedupliziert per URL, schreibt in docs/monitoring/vuln-log.md, sendet Top-5 via Telegram. Kein API-Key noetig.
---

# vuln-watch

## Zweck

Sucht wöchentlich auf GitHub nach neuen Issues/PRs zu AI-Security-Themen:
- Prompt Injection / Jailbreak
- LLM CVEs und Sicherheitslücken
- OpenClaw-spezifische Security-Findings

Dedupliziert gegen bekannte URLs, schreibt neue Funde in `~/docs/monitoring/vuln-log.md`,
sendet Top-5 via Telegram.

## Wann nutzen

```bash
~/scripts/skills vuln-watch --weekly [--dry-run]   # Suche + Dedup + Log + Telegram
~/scripts/skills vuln-watch --summary              # Letzte Funde anzeigen
~/scripts/skills vuln-watch --json                 # JSON-Summary
```

## Suchanfragen (GitHub Issues API)

| Term | Zweck |
|---|---|
| `prompt injection` | Klassische Prompt-Injection-Findings |
| `jailbreak LLM` | Jailbreak-Techniken gegen LLMs |
| `LLM vulnerability` | Allgemeine LLM-Schwachstellen |
| `AI security CVE` | CVE-referenzierte AI-Sicherheitsprobleme |
| `openclaw security` | Eigener Stack |

Zeitraum: letzte 7 Tage. Rate-Limit: 10 req/min (unauthenticated) — 7s Pause pro Query.

## Output

### vuln-log.md (Append-only)
```markdown
| Datum | Titel | URL | Typ |
|---|---|---|---|
| 2026-04-08 | [Titel] | https://github.com/... | prompt injection |
```

### Telegram (Top 5 neue Funde)
```
🔐 Vuln-Watch — 2026-04-08
3 neue AI-Security-Funde:

1. [Titel] — prompt injection
   https://github.com/...
```

## Heartbeat-Integration

Wöchentlich (Montag 07:00) durch heartbeat:
```bash
~/scripts/skills vuln-watch --weekly --json
```

## Scope-Grenzen

| Erlaubt | Verboten |
|---|---|
| GitHub Search API (GET) | Authentifizierte API-Calls |
| Schreiben in `~/docs/monitoring/vuln-log.md` | Ändern anderer Dateien |
| Telegram senden | Direktes GitHub-Scraping |
