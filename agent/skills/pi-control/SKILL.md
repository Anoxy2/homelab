---
name: pi-control
description: Deterministic Raspberry Pi operations skill for safe homelab checks and low-risk service actions.
---

# pi-control

## Purpose
Provide a bounded way for OpenClaw to inspect the Pi and execute a small set of operational actions without ad-hoc shell access.

## Trigger
Use when users ask for:
- Docker service status, restart, or recent logs
- disk usage or backup footprint checks
- system health values like temperature, RAM, or uptime
- a manual backup run
- Telegram commands: `/status`, `/logs <service>`, `/backup`

## Steps
1. Match the requested action to an approved subcommand.
2. Validate input, especially service names.
3. Run the dedicated script for the action type.
4. Return concise output and mention the next safe follow-up if relevant.

## Allowed Actions

Docker via `docker-compose.sh`:
- `ps`
- `restart <service>`
- `logs <service> [tail]`
- `stats` — CPU/RAM aller laufenden Container (kein Stream)
- `inspect <service>` — Ports, Volumes, Env-Keys (keine Values), Status
- `images` — Alle Images mit Größe und Alter

Disk via `disk.sh`:
- `df`
- `backups`

System metrics via `metrics.sh`:
- `temp`
- `ram`
- `uptime`
- `load` — Load-Average 1/5/15min
- `swap` — Swap-Nutzung
- `network` — RX/TX kB/s der Default-Route (1s Messung)
- `all` — Kompakter Block: CPU + RAM + Swap + Load + Disk

Status-Report via `status-full.sh`:
- Vollständiger System-Report: Metriken + Container-Liste + Top-3-CPU-Stats

Backup via `backup.sh`:
- `run`

## Boundaries
- No arbitrary shell commands.
- No `reboot`, `shutdown`, `docker system prune -a`, or `rm -rf`.
- No writes outside the approved backup flow.
- Docker actions are limited to services defined in `/home/steges/docker-compose.yml`.
- Logs are tail-limited to prevent excessive output.

## Commands

```bash
~/agent/skills/pi-control/scripts/docker-compose.sh ps
~/agent/skills/pi-control/scripts/docker-compose.sh restart homeassistant
~/agent/skills/pi-control/scripts/docker-compose.sh logs openclaw 50
~/agent/skills/pi-control/scripts/docker-compose.sh stats
~/agent/skills/pi-control/scripts/docker-compose.sh inspect homeassistant
~/agent/skills/pi-control/scripts/docker-compose.sh images
~/agent/skills/pi-control/scripts/disk.sh df
~/agent/skills/pi-control/scripts/disk.sh backups
~/agent/skills/pi-control/scripts/metrics.sh temp
~/agent/skills/pi-control/scripts/metrics.sh ram
~/agent/skills/pi-control/scripts/metrics.sh uptime
~/agent/skills/pi-control/scripts/metrics.sh load
~/agent/skills/pi-control/scripts/metrics.sh swap
~/agent/skills/pi-control/scripts/metrics.sh network
~/agent/skills/pi-control/scripts/metrics.sh all
~/agent/skills/pi-control/scripts/backup.sh run
# Telegram /status (kompakt):
~/agent/skills/pi-control/scripts/status-report.sh
# Telegram /status (vollständig):
~/agent/skills/pi-control/scripts/status-full.sh
```

## Telegram Commands

When a Telegram message starts with `/status`:
→ Run `status-report.sh`, send the output as a Telegram reply.

When a Telegram message starts with `/logs <service>`:
→ Validate `<service>` against allowed services (`docker ps --format "{{.Names}}"` whitelist).
→ Run `docker-compose.sh logs <service> 20`, send output.
→ Deny unknown service names.

When a Telegram message starts with `/backup`:
→ Ask for confirmation: "Backup starten? Antwort mit 'ja'."
→ On confirmation: run `backup.sh run`, report success/failure and backup size.
→ On any other reply or after 60s: abort with "Backup abgebrochen."

## Skill-manager Contract
- `pi.control`

## Related Docs
- `/home/steges/CLAUDE.md`
- `/home/steges/agent/TOOLS.md`
- `/home/steges/docs/operations/maintenance-and-backups.md`

## Lifecycle
- Author via: `~/scripts/skill-forge author skill pi-control --mode auto --reason "safe Pi operations"`
- Canary start: `~/scripts/skill-forge canary start pi-control 24`
- Promote: `~/scripts/skill-forge canary promote pi-control`
- Rollback: `~/scripts/skill-forge rollback pi-control`