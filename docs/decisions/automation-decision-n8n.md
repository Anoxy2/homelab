# Entscheidung: n8n fuer Growbox-Automatisierung

## Kontext

Geprueft wurde, ob `n8n` als Glue zwischen MQTT, OpenClaw (Claude API) und Home Assistant notwendig ist.

## Bewertungsrahmen

- Betriebsaufwand auf Pi 5 (RAM/CPU, Backup, Security)
- Integrationsmehrwert gegenueber vorhandenem Stack
- Fehlertoleranz und Debugbarkeit
- Zusatzzustand/Komplexitaet im 24/7 Betrieb

## Ergebnis

Entscheidung: **vorerst kein n8n-Deployment**.

Begruendung:
- Vorhandene Faehigkeiten decken Kernbedarf bereits ab:
  - `pi-control` fuer sichere Pi/Docker-Operationen
  - `ha-control` fuer whitelisted HA REST Calls
  - OpenClaw Heartbeat/Skill-Manager fuer orchestrierte Ablaufe
- zusaetzlicher Dienst erhoeht Betriebs- und Sicherheitsflaeche (Updates, Backup, Credentials, Monitoring)
- fuer aktuelle Growbox-Use-Cases ist direkte Skill-Orchestrierung klarer und leichter nachvollziehbar

## Alternative (aktiv)

- MQTT/HA Trigger direkt ueber OpenClaw + bestehende Skills verarbeiten
- Entscheidungslogik in dokumentierten Runbooks und Skill-Contracts halten

## Re-Evaluationskriterium

n8n wird erneut geprueft, wenn mindestens eines zutrifft:
- >10 aktive, verknuepfte Automationsfluesse mit haeufigen Aenderungen
- wiederkehrender Bedarf an visueller Workflow-Editor-Kollaboration
- direkte Integrationen ohne vertretbaren Skill-Aufwand notwendig werden
