# Pilab Index

Maschinenlesbare Navigationsdatei fuer Agenten und schnelle Repo-Orientierung.

## Identity
- repo_root: `/home/steges`
- host_role: `raspberry-pi-5-homelab`
- primary_runtime: `docker compose`
- architecture: `arm64`

## Start Here
- `CLAUDE.md` — oberster Infrastruktur- und Sicherheitskontext fuer diese Workspace-Session
- `agent/HANDSHAKE.md` — gemeinsames Protokoll zwischen Claude und OpenClaw
- `docs/operations/open-work-todo.md` — priorisierte Arbeitsliste und einzige aktive Open-Work-Quelle
- `agent/TOOLS.md` — lokale Tool- und Infrastruktur-Notizen
- `agent/TO-DO.md` — Migrationshinweis (aktive Todo-Pflege erfolgt in `docs/operations/open-work-todo.md`)

## Key Files
- `docker-compose.yml` — alle Container-Services
- `README.md` — Kurzueberblick ueber System und Dienste
- `docs/core/system-architecture.md` — grobe Architektur und Komponenten
- `docs/core/services-and-ports.md` — Services, Ports, URLs
- `docs/core/network-topology.md` — Netz- und Port-Kontext
- `docs/operations/maintenance-and-backups.md` — Ops-, Backup- und Restore-Ablauf
- `docs/operations/session-handover.md` — Session-Uebergabe, Start-Check und Abschluss-Check
- `docs/core/security-baseline.md` — Sicherheitsentscheidungen und Risiken
- `CHANGELOG.md` — manuelle Aenderungshistorie

## Agent Context
- `agent/SOUL.md` — Agent-Identitaet
- `agent/IDENTITY.md` — Rolle und Verhalten
- `agent/USER.md` — Kontext zum Nutzer
- `agent/HEARTBEAT.md` — zyklische Checks und Eskalationslogik
- `agent/MEMORY.md` — langfristiger Agent-Kontext

## Skills
- `agent/skills/openclaw-rag/SKILL.md` — lokale Retrieval-Faehigkeit
- `agent/skills/openclaw-ui/SKILL.md` — Canvas/UI-Kontext
- `agent/skills/skill-forge/SKILL.md` — Skill-Lifecycle und Governance
- `agent/skills/runbook-maintenance/SKILL.md` — Runbook-Pflege
- `agent/skills/pi-control/SKILL.md` — sichere Pi-Operations

## Growbox
- `growbox/GROWBOX.md` — Entities und HA-API-Referenz
- `growbox/GROW.md` — aktueller Grow-Zustand
- `growbox/THRESHOLDS.md` — Zielwerte und Alarmgrenzen
- `growbox/diary/` — Tageshistorie

## Operating Rules
- Keine Secrets aus `.env`, `secrets.yaml`, `passwd` auslesen oder ausgeben.
- Keine Images ohne arm64-Support einsetzen.
- Keine destruktiven Docker- oder Systembefehle ohne explizite Freigabe.
- Fuer skill-spezifischen Kontext zuerst die jeweilige `SKILL.md` lesen; separate per-skill `CLAUDE.md` sind aktuell nicht Standard.