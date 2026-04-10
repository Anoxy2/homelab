# Evaluierung: Drei-Tier-Memory fuer OpenClaw

## Ausgangspunkt

Vorgeschlagenes Pattern: Session -> Working -> Distilled (mit TTL), inkl. haeufigem Reindex (`memsearch-watch`).

## Abgleich mit aktuellem Setup

- Bereits vorhanden: persistente Agent-Memory unter `agent/memory/` und skill-forge Lifecycle-Gates
- Der aktuelle Betrieb priorisiert klare, dateibasierte Nachvollziehbarkeit und geringe Hintergrundlast
- Zusätzliche 5s-Reindex-Jobs wuerden dauerhaft Last erzeugen und Monitoring/Fehlerpfade vergroessern

## Ergebnis

**Keine Einfuehrung eines separaten Drei-Tier-Memory-Subsystems im aktuellen Stand.**

Stattdessen:
- bestehende Memory-Dateien beibehalten
- Promoting/Distillation nur bewusst im Rahmen von Skill-Manager-/Doku-Workflows
- kein permanenter 5s memsearch-watch Daemon

## Re-Evaluationskriterium

Neu bewerten, wenn:
- Memory-Bloat messbar den Betrieb beeinflusst
- Suchqualitaet trotz RAG-Optimierungen sinkt
- klarer Nutzen einer automatisierten Distillation gegen Betriebsaufwand nachgewiesen ist
