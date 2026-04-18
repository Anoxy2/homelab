# Open Work Todo

Stand: 2026-04-13

Diese Datei enthaelt nur offene Arbeit. Erledigte Punkte werden nach Implementierung, Validierung und Doku-Update entfernt.

## Verbindliche Reihenfolge

- Implementieren
- Validieren
- Dokumentieren (inkl. `CHANGELOG.md` und betroffener Fachdoku)
- Erst danach Todo entfernen

---

## P2 Aktive Prioritaeten

### Infrastruktur & Betrieb

- [ ] Caddy Bridge-Mode gegen Host-Mode bewerten (Risiko/Nutzen, Migrationsplan)
- [ ] Docker-Volume-Backups fuer verbleibende optionale Pfade entscheiden und ggf. nachziehen (`searxng/config`, `unbound/config`, `loki/config`, `promtail/config`)
- [ ] Loki/Promtail Structured-Logging-Pipeline verbessern (JSON-Parsing, Label-Extraktion, Query-Kosten senken)
- [ ] Monatlichen Docker-Socket-Proxy-Audit definieren (Logs, Checkliste, Verantwortlichkeit)

---

## P3 Backlog

### Skill-Forge & Skills

- [ ] Restliche Skill-Haertungen einzeln priorisieren und umsetzen (Timeouts, Retry, Failover, Input-Validierung)
- [ ] Wiederkehrende TODO/FIXME-Hotspots in Skripten schrittweise abbauen
- [ ] Skill-Assessment-Pipeline aufbauen: Smoke-, Regression-, Health- und Canary-Tests fuer alle aktiven Skills; Ergebnisprotokoll im Doc-Keeper
- [ ] Verwaiste/ungenutzte Skills identifizieren, quarantaenisieren oder entfernen

### Monitoring & Alerting

- [ ] Proaktives Monitoring: periodische Self-Checks aus heartbeat/health-Skills orchestrieren, Pattern-Detection fuer Container-Crash-Loops und Ressourcenengpaesse einbauen
- [ ] Smarte Eskalation: Eskalations-Schwellen nach Schweregrad und Tageszeit in Policy hinterlegen, Escalation-Skill bauen
- [ ] Integrity & Recovery: Routine-Selftest fuer Skills, Cronjobs, Netzwerk; Probe-Backup/Restore-Simulation als periodische Routine einrichten

### Self-Documentation

- [ ] Auto-Doc Skill anlegen: Protokollformat und Rotationsregeln definieren, Hooks fuer Self-Heal/Incident/Audit in Skills einklinken
- [ ] Digest/Reporting: Wochen-Report-Funktion via CLI/Canvas bereitstellen
- [ ] RAG-SOURCES.md und ingest.py: auto-doc/ und event-logs aus Index ausschliessen (Noise-Bereinigung, nur promoted Eintraege indexieren)

### RAG-System

- [ ] Cold-Storage/Aging: Archivierungslogik fuer alte/verwaiste Chunks implementieren
- [ ] Promoted-Tag-Workflow: ingest.py und reindex.sh unterstuetzen `promote`-Flag aus auto-doc
- [ ] Index-Health-Monitoring: Chunk Count, Source Drift, Recency-Alerts automatisieren

### Interfaces & Feedback

- [ ] Quick-Actions-Skill: Standard-Tasks (Restart, Log, Health, Backup, Update) per Telegram und Canvas bedienbar machen
- [ ] Feedback-Loop: periodischer Feedback-Prompt an steges; Fehler-/Timeout-Aggregation aus Logs ins Backlog

### Dokumentation

- [ ] Dokumentationskonsolidierung fortsetzen (Dubletten entfernen, Referenzen harmonisieren)

---

## P4 Vision / Langfristig

- [ ] Event-Driven Intelligence: Event-Bus fuer System- und Sensor-Events, Trigger-Action-Engine fuer autonome Self-Heal-Aktionen, Energiemanagement-Policies
- [ ] Context-Aware Policies: Policy-Anpassung nach Tageszeit, Userpraesenz und Last (Smart Quiet Mode, Notification-Tuning)
- [ ] Adaptives Skill-Learning: Automatische Bedarfserkennung aus Logs, Skill-Recommendation-System, (halb-)autonomes Onboarding neuer Services
- [ ] Multimodale Interaktion: Interface-Detection (Telegram/Canvas/Voice), adaptive Antwortlaenge und -form je Kanal
- [ ] Peer Learning: anonymisierter Austausch von Best Practices mit anderen OpenClaw-Instanzen (benoetigt externe Infrastruktur)
