---
name: web-search
description: Web-Suche via lokalem SearXNG (privacy-first, kein Google-API-Key nötig).
---

# web-search

## Zweck

OpenClaw kann über den lokalen SearXNG-Proxy im LAN Websuchen durchführen.
Keine Cloud-Abhängigkeit, kein API-Key, keine Tracking-Cookie-Weitergabe.

## Wann nutzen

- Aktuelle Informationen zu einem Thema (CVEs, Changelogs, Doku)
- Fehlersuche wenn RAG keine Treffer liefert
- Software-Versionen, Kompatibilität, bekannte Issues
- Allgemeine Wissensfragen die nicht im RAG-Index sind

## Aufrufe

```bash
# Einfache Suche (top 5 Treffer, lesbar)
~/scripts/skills web-search search "Docker Loki arm64 config"

# Ergebnisanzahl steuern
~/scripts/skills web-search search "Home Assistant ESPHome MQTT" --limit 3

# Gezielt auf bestimmte Engines
~/scripts/skills web-search search "CVE-2024-1234" --engines google,duckduckgo

# JSON-Output (für maschinelle Weiterverarbeitung)
~/scripts/skills web-search search "Raspberry Pi 5 NVMe" --json

# SearXNG erreichbar?
~/scripts/skills web-search check
```

## Verfügbare Engines

| Engine | Shortcut | Stärke |
|---|---|---|
| google | g | Allgemein, aktuell |
| duckduckgo | ddg | Privacy, allgemein |
| bing | b | Allgemein |
| wikipedia | wp | Faktenwissen |
| github | gh | Code, Issues, Repos |
| stackoverflow | so | Programmierung |
| dockerhub | dh | Docker-Images |
| pypi | pypi | Python-Pakete |

## Grenzen

- Ergebnisse sind öffentlich zugängliche Webseiten — nicht verifiziert
- Kein Seiteninhalt wird gescraped (nur Snippets aus den Suchergebnissen)
- Bei Rate-Limiting durch externe Engines: Engine wechseln oder Pause einlegen
- SearXNG läuft unter http://search.lan / 192.168.2.101:8085

## Eskalation

Bei konsequent leeren Ergebnissen: `skills web-search check` ausführen,
dann `docker compose logs searxng` prüfen.
