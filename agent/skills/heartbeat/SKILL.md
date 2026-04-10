---
name: heartbeat
description: Autonomer OpenClaw-Ops-Heartbeat. Läuft 2x täglich via systemd-Timer, entscheidet adaptiv über Orchestration-Modus (live/dry) und Vet-Score basierend auf Risk-Score, Canary-Status und Rollback-Rate. Triggert Orchestration, Doc-Keeper, Growbox-Berichte, NVMe-SMART, Shell-Tests und Scout. Sendet strukturierte Telegram-Zusammenfassung.
---

# heartbeat

## Zweck

Führt den autonomen Betriebszyklus durch: Orchestration, Growbox-Diary, Doc-Keeper, NVMe-SMART, Shell-Tests (wöchentlich), Scout-Lauf (wöchentlich) und Telegram-Report. Entscheidet selbständig ob live oder dry gefahren wird.

## Automatischer Betrieb (Autonomie)

Der Heartbeat läuft **ohne manuelle Intervention** via systemd-Timer:

| Zeit | Modus |
|------|-------|
| 07:00 Europe/Berlin | live (adaptiv) |
| 19:00 Europe/Berlin | live (adaptiv) |

```bash
# Timer-Status
systemctl status openclaw-heartbeat.timer

# Nächsten Trigger anzeigen
systemctl list-timers openclaw-heartbeat.timer

# Manuell auslösen (ohne auf Timer zu warten)
systemctl start openclaw-heartbeat.service
```

## Adaptive Entscheidungslogik

Vor jedem Orchestrate-Aufruf entscheidet `decide_orchestrate_params()`:

| Bedingung | Modus | Vet-Score |
|-----------|-------|-----------|
| Incident-Freeze aktiv | dry | 70 |
| ≥ 3 Canaries in-flight | dry | 75 |
| ≥ 3 Skills mit Risk ≥ 70 | dry | 80 |
| ≥ 1 Skill mit Risk ≥ 70 | live | 75 |
| avg_rollback_rate > 0.3 | dry | 85 |
| Default | live | 70 |

Die Entscheidung wird im Audit-Log und Action-Log erfasst.

## Manueller Aufruf

```bash
~/scripts/skills heartbeat               # adaptiv (dry/live je nach Zustand)
~/scripts/skills heartbeat --live        # forciert live, vet-score adaptiv
~/scripts/skills heartbeat --live 15 80  # live, max 15 Promotes, vet-score 80
~/scripts/skills heartbeat --dry         # forciert dry
```

## Selbstüberwachung

- Schreibt `$STATE_DIR/heartbeat-last-run.ts` nach jedem erfolgreichen Lauf
- Warnt im Telegram-Report und Failure-Block wenn > 30h kein Lauf stattfand
- Schreibt Self-Reflection in `.learnings/LEARNINGS.md` bei Orchestrate-Fehler

## Abhängigkeiten (direkte Skill-Aufrufe)

| Aufruf | Zweck | Frequenz |
|--------|-------|----------|
| `~/scripts/skills metrics weekly` | Wöchentliche Metriken aggregieren | täglich |
| `~/scripts/skills metrics latest` | Letzten Metriken-Record lesen | täglich |
| `~/scripts/skills metrics risk-report` | Risk-Score aktualisieren | täglich |
| `~/scripts/skills scout --dry-run` | Wöchentlicher Scout-Lauf | wöchentlich |
| `~/scripts/skills rag doc-keeper run --summary-only --autodoc --autodoc-profile daily --autodoc-provider <provider> --autodoc-model <model>` | Tägliche Doc-Keeper-Aktualisierung plus Auto-Doc | im Zeitfenster 06-10h |
| `~/scripts/skills rag doc-keeper run --summary-only --autodoc --autodoc-profile weekly --autodoc-provider <provider> --autodoc-model <model>` | Wöchentlicher Auto-Doc-Lauf fuer `SELF-MODEL` und `HISTORY` | 1x pro 7 Tage |
| `~/scripts/skills learn weekly` | Wöchentliche Learnings distillieren | wöchentlich |

## Lifecycle-Aufrufe (Manager-intern)

| Aufruf | Warum |
|--------|-------|
| `skill-forge/scripts/orchestrate.sh` | Lifecycle-Trigger |
| `skill-forge/scripts/vet.sh` | Auto-Vetting entdeckter Kandidaten (Scout weekly) |

## Telegram-Report Struktur

```
🫀 OpenClaw Heartbeat (live|vet=70) @ pilab
🚦 Laufstatus        — Orchestrate, Doc-Keeper, Growbox, Freeze
🖥️ System             — Container, Disk, Load, NVMe, Shell-Tests, Scout, Learnings
📦 Skills             — Known, Active, Canary, Blacklist
🚨 Risiko             — High/Medium-Count, Top 3 Scores
🕒 24h Digest         — Rejects, Promotes, Rollbacks
📈 Trend vs 7d        — Δ Install-Rate, Rollback-Rate, Decision-Time
⚠️ Fehler             — Task-Failures der aktuellen Session
📊 Metrics            — Run-ID, Live-Flag, Rates
```

## Scope-Grenzen

| Erlaubt | Verboten |
|---------|----------|
| Orchestration triggern (Lifecycle-Aufruf) | Direkte Skill-Status-Änderungen |
| Telegram senden | Modifikation von policy/, .env |
| Growbox-Diary anlegen | Mehr als read-only auf Sensor-State |
| Last-run-Timestamp schreiben | Direkte Canary-Manipulation |
