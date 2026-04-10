# Entscheidung: Web-Suche fuer OpenClaw

## Bewertete Optionen

- Self-hosted SearXNG (`searxng/searxng`)
- Externe Search-API (z. B. Tavily)
- Bestehende OpenClaw/Web-Fetch Faehigkeiten ohne neuen lokalen Suchdienst

## Entscheidung

**Kein SearXNG-Deployment im aktuellen Stand.**

## Begruendung

- aktueller Fokus liegt auf Stabilitaet, Skill-Manager-Hardening und Growbox-Automation
- zusaetzlicher Suchdienst erhoeht Betriebs- und Sicherheitsaufwand
- vorhandene Web-Fetch/Recherche-Workflows decken die meisten Operator-Use-Cases derzeit ab

## Contract-Auswirkung

`web.search` wird erst erweitert, wenn ein konkreter Suchdienst produktiv eingefuehrt ist.

## Re-Evaluationskriterium

Neu bewerten, wenn:
- regelmaessige webbasierte Recherche als Kernworkflow auftritt
- externe API-Kosten/Rate-Limits den Betrieb behindern
- reproduzierbare, private Suchindizes notwendig werden
