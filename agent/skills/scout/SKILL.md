---
name: scout
description: Entdeckt neue Skills in konfigurierbaren Hubs. Deterministischer Discovery-Kern (GitHub-Tree-Walk, Dedup, State-Write) + optionaler --semantic Modus mit Analyst (Relevanz-Scoring) und Curator (lernt neue Suchbegriffe und Hub-Quellen aus Nutzungsmustern).
---

# scout

## Zweck

Findet neue Skills in bekannten Hubs und erweitert kontinuierlich seinen eigenen Suchraum basierend auf dem Nutzungsprofil.

## Wann nutzen

```bash
# Deterministisch (kein API-Call):
~/scripts/skills scout --dry-run [--json]
~/scripts/skills scout --live [N] [--json]
~/scripts/skills scout --summary [--json]
~/scripts/skills scout --add <slug> <source> <version>

# Mit semantischer Erweiterung (opt-in, Analyst + Curator):
~/scripts/skills scout --live [N] --semantic [--json]
~/scripts/skills scout --dry-run --semantic [--json]

# Curator-Vorschläge anwenden:
~/scripts/skills scout --apply-suggestions [--dry-run]
```

Mit `--json` liefern auch die semantischen Scout-Pfade ausschließlich ein parsebares JSON-Envelope auf stdout, ohne Klartext-Header.

Lifecycle-Aufrufe laufen über skill-forge:
```bash
~/scripts/skill-forge scout ...   # Thin Wrapper → delegiert an skills scout
```

## Pipeline

### Deterministischer Pfad (Default)

```
scout-dispatch.sh
    │
    ├─ hubs.json lesen          (konfigurierbare Hub-Liste)
    ├─ GitHub Tree-API abfragen  (pro Hub: SKILL.md-Pfade extrahieren)
    ├─ Dedup + Limit anwenden
    └─ add_discovered() in known-skills.json schreiben
```

### Semantischer Pfad (--semantic)

```
scout-dispatch.sh --semantic
    │
    ├─ [deterministisch] Hubs abfragen + Kandidaten sammeln
    │
    ├─ scout-analyst
    │    Eingabe: discovered candidates + known-skills + profile keywords
    │    Ausgabe: { slug, relevance_score, rationale }[] — nach Score sortiert
    │
    └─ scout-curator
         Eingabe: active/vetted/matured Skills (slugs + letzte Nutzungsmuster)
         Ausgabe: { suggested_terms[], suggested_sources[], confidence }
         → hohe Confidence (>= 0.7): auto-merge in hubs.json search_terms
         → niedrige Confidence: pending in .state/curator-suggestions.json
```

## Agenten-Rollen

| Agent | Aufgabe | State-Write |
|-------|---------|------------|
| scout-analyst | Relevanz-Scoring für entdeckte Kandidaten | Nein |
| scout-curator | Schlägt neue Suchbegriffe + Quellen vor | Ja (curator-suggestions.json, hubs.json) |

`scout-dispatch.sh` ist der einzige direkte State-Writer für `known-skills.json`.

## Hub-Konfiguration

Hubs werden aus `config/hubs.json` gelesen — nicht hardcoded:

```json
{
  "sources": [
    { "name": "...", "type": "github", "owner": "...", "repo": "...", "branch": "main" }
  ],
  "search_terms": ["homelab", "automation", "iot"]
}
```

`search_terms` werden vom Curator über die Zeit erweitert.
Neue Hub-Quellen können manuell oder per `--apply-suggestions` ergänzt werden.

## Scope-Grenzen

| Erlaubt | Verboten |
|---------|----------|
| Lesen von known-skills.json | Schreiben von Lifecycle-Status (vet, canary, promote) |
| Schreiben neuer `discovered`-Einträge | Überschreiben bestehender aktiver Skills |
| Schreiben in hubs.json (nur search_terms, Curator) | Modifikation von policy/, audit-log, .env |
| Lesen des Audit-Logs (read-only) | Direkte Netzwerk-Calls außer GitHub Tree-API |

## Lern-Mechanismus

Der Curator lernt aus:
- Slugs und Namen aktiver/geförderter Skills → welche Themen werden häufig genutzt?
- Bisherigen `search_terms` in `hubs.json`
- Audit-Log-Mustern (welche Quellen liefern viele `vetted`/`active` Skills?)

Neue Suchbegriffe werden automatisch angewendet, wenn `confidence >= 0.7`.
Alle Vorschläge (inkl. abgelehnter) werden in `.state/curator-suggestions.json` protokolliert.
