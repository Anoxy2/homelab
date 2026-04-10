---
title: "HEARTBEAT.md Template"
summary: "Workspace template for HEARTBEAT.md"
read_when:
  - Bootstrapping a workspace manually
---

# HEARTBEAT.md Template

# Homelab Health Checks
# Nicht alle Checks bei jedem Heartbeat – rotieren um API-Calls zu sparen.

Vor Rueckmeldungen an Claude das Protokoll in `/home/steges/agent/HANDSHAKE.md` anwenden. Status, Eskalation und naechste Schritte sollen dem dort definierten Antwortformat folgen.

## Docker Status (bei jedem Heartbeat)
Prüfe ob alle Container laufen:
`docker ps --format "table {{.Names}}\t{{.Status}}"`
Erwartete Container: pihole, homeassistant, esphome, tailscale, mosquitto, portainer, watchtower, openclaw
→ Bei "Exited" oder "Restarting": steges sofort benachrichtigen + Logs prüfen

## Service Health (alle 2-3 Heartbeats)
- Pi-hole: `curl -sf http://192.168.2.101:8080/admin` → LAN-DNS hängt dran!
- Home Assistant: `curl -sf http://192.168.2.101:8123`
- Portainer: `curl -sf http://192.168.2.101:9000`
→ Bei Ausfall: steges benachrichtigen

## Disk (täglich, morgens zwischen 08:00-10:00 Europe/Berlin)
`df -h /` – Warnen wenn >80% belegt
`df -h /home/steges` – Workspace-Verzeichnis

## Pi Temperatur (bei jedem 2. Heartbeat)
`vcgencmd measure_temp`
- >70C: Warnung
- >80C: kritisch, sofort melden

## Growbox Sensorwerte (alle 2-3 Heartbeats, wenn HA_TOKEN gesetzt)
```bash
curl -s -H "Authorization: Bearer $HA_TOKEN" \
  http://192.168.2.101:8123/api/states/sensor.growbox_temperatur
```
Zielwerte: `/home/steges/growbox/THRESHOLDS.md`
Alarme (sofort melden):
- Temperatur >30°C oder <18°C
- Luftfeuchtigkeit >75% oder <35%
- State = "unavailable" → ESP32 offline

## Skill-Manager Zustand (bei jedem 2. Heartbeat)
Kurzstatus:
`/home/steges/scripts/skill-forge status`

Wenn auffaellig:
- `incident-freeze: on` ohne bekannten Incident -> sofort melden
- `pending-blacklist` steigt ueber mehrere Heartbeats -> melden
- viele `rollback` oder `pending-review` Stati -> melden

## Skill-Manager Wartung (taeglich, morgens 06:00-08:00 Europe/Berlin)
Sicherer Daily-Block:
1. `/home/steges/scripts/skill-forge policy lint`
2. `/home/steges/scripts/skill-forge blacklist promote`
3. `/home/steges/scripts/skill-forge health`
4. `/home/steges/scripts/skill-forge budget`

Bei Fehlern im Daily-Block:
- nicht still ignorieren
- Fehlertext kurz zusammenfassen
- steges benachrichtigen

## Skill-Manager Security-Check (alle 3-4 Heartbeats)
`/home/steges/scripts/skill-forge audit --rejected`

Interpretation:
- neue REJECT-Eintraege sind normal, solange Quarantaene/Promotion korrekt laeuft
- REJECT-Spike in kurzer Zeit -> moeglicher Source-Incident, empfehlen: `incident freeze on`

## RAG Index-Freshness (alle 3 Heartbeats)
Vergleiche letzte Index-Zeit mit den Quellen:
1. `python3 /home/steges/agent/skills/openclaw-rag/scripts/retrieve.py "heartbeat health" >/dev/null`
2. Pruefe `indexed_at` in `file_index` gegen Dateizeitstempel der Quellen unter `/home/steges/docs`, `/home/steges/growbox`, `/home/steges/agent`.
3. Wenn Quellen neuer sind als Index: `~/agent/skills/openclaw-rag/scripts/reindex.sh` ausfuehren.

Rueckmeldung in Heartbeat-Status:
- Reindex ausgelöst: ja/nein
- Neue Chunks: Anzahl
- Dauer: Sekunden

## Geplante Aufgaben / Scheduled Skills

Taegliche Aufgaben (systemd-Timer aktiv):
- 03:15 — Nightly Self-Check (`nightly-self-check.timer`: Policy-Lint, Stale Canaries, Pending-Review, Health)
- 07:00 / 19:00 — OpenClaw Heartbeat (`openclaw-heartbeat.timer`: Orchestration, Growbox, Doc-Keeper, Metrics, Scout, NVMe, Shell-Tests, Learnings, Telegram)

Woechentliche Aufgaben (systemd-Timer aktiv):
- Samstag 10:00 — RAG-Qualitaetsreport (`rag-quality-report.timer`: Precision@5 / Recall@5 / p95, Gate-Bewertung, Telegram)
- Sonntag 09:00 — Backup-Verifikation (`backup-verify.timer`: Restic-Snapshot, Alter-Check max 48h, Telegram)

Hinweis:
- Wenn ein geplanter Check fehlschlaegt: Fehler nicht still ignorieren, kurz zusammenfassen und melden.

## Ruhige Zeiten
Zwischen 23:00 und 08:00 (Europe/Berlin): nur bei kritischen Problemen (Container down, Disk >90%, Growbox-Alarm) melden.

Zusaetzlich als kritisch behandeln:
- skill-forge incident freeze unerwartet aktiv
- policy lint dauerhaft fehlschlaegt
- canary faellt bei produktivem Skill auf rollback
