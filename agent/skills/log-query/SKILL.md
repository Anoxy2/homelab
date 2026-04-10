---
name: log-query
description: Echtzeit-Log-Zugriff für OpenClaw via Loki. Kein RAG-Schreiben – nur Live-Abfragen.
---

# log-query

## Zweck

OpenClaw kann gezielt Container-Logs aus Loki abrufen und analysieren,
ohne rohe Logs in den RAG-Index zu laden. RAG bleibt für Dokumentation reserviert.

## Wann nutzen

- Fehler oder Anomalien in einem bestimmten Service untersuchen
- Aktuelle Logs nach einem Incident oder Restart prüfen
- Muster über mehrere Services suchen (z. B. "alle 401-Fehler der letzten Stunde")
- Log-Freshness / Promtail-Betrieb verifizieren

## Architektur-Prinzip

```
Container → Docker-Log → Promtail → Loki
                                      ↑
                             OpenClaw fragt hier live ab (log-query Skill)
                             RAG wird NICHT mit Logs beschrieben
```

## Aufrufe

```bash
# Letzte 50 Zeilen eines Services (Standard: letzte Stunde)
~/scripts/skills log-query query --service openclaw

# Mit Zeitfenster und Zeilenlimit
~/scripts/skills log-query query --service homeassistant --lines 100 --since 30m

# Gefiltert nach Pattern
~/scripts/skills log-query query --service pihole --since 2h --grep "blocked"

# Rohe LogQL-Query
~/scripts/skills log-query query --query '{container="caddy"} |= "error"' --lines 20

# Alle verfügbaren Container in Loki auflisten
~/scripts/skills log-query query --services
```

## Grenzen

- Loki muss laufen (http://192.168.2.101:3100)
- Retention: 30 Tage (konfiguriert in loki/config/loki.yml)
- Nur lesend — keine Schreiboperationen
- Keine Log-Interpretation durch den Skill selbst (das macht OpenClaw/Claude)

## Eskalation

Wenn Loki nicht erreichbar → melde als `blocked`, nicht selbst debuggen.
Wenn Log-Inhalt auf kritischen Incident hindeutet → `escalated` an steges.
