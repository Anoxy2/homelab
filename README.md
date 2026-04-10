# Pilab – Raspberry Pi 5 Homelab

Persönlicher Homelab-Server auf Basis eines Raspberry Pi 5.

## Hardware

- **Board:** Raspberry Pi 5 Model B, 8 GB RAM
- **Storage:** 232 GB NVMe SSD
- **OS:** Debian 12 Bookworm (arm64)
- **IP:** 192.168.2.101 (statisch)
- **Tailscale:** 100.78.245.50 (`pilab`)
- **Kühlung:** Aktiv

## Services

| Service | Zweck | URL |
|---------|-------|-----|
| Pi-hole | DNS Ad-blocking, LAN-DNS, DHCP | http://192.168.2.101:8080/admin |
| Home Assistant | Smart Home Automation | http://192.168.2.101:8123 |
| ESPHome | ESP32/ESP8266 Firmware | http://192.168.2.101:6052 |
| Portainer | Docker Management UI | http://192.168.2.101:9000 |
| Watchtower | Automatische Image-Updates | – |
| Tailscale | VPN Remote-Zugriff | `pilab` / 100.78.245.50 |

## Skill Manager (OpenClaw)

Der Skill-Manager laeuft im OpenClaw-Workspace und steuert den Skill-Lifecycle:

**Governance & Lifecycle** (`~/scripts/skill-forge`):
- Discovery, Vetting, Quarantaene/Blacklist, Authoring
- Canary-Rollout, Provenance, Incident Management
- Policy/Audit/Budget/Health-Checks

**Domain-Ausführung** (`~/scripts/skills`):
- Alle fachlichen Aufgaben: `coding`, `heartbeat`, `metrics`, `scout`, `learn`, `health`, `profile`, `growbox`, `doc-keeper`, `runbook-maintenance`, `canary evaluate` etc.
- OpenClaw nutzt **direkt** `~/scripts/skills` für Domain-Aufgaben, **nicht** `~/scripts/skill-forge`

**Kernprinzip (Phase 0 – Governance Umbau):**
- `~/scripts/skill-forge` = Reines Governance-System (Lifecycle, Policy, Orchestration)
- `~/scripts/skills` = Domain-Ausführung (keine Management-Aufgaben)
- Keine doppelte Domain-Logik zwischen Manager und Skills
- Boundary ist hart verankert in `agent-contracts.json`

Arbeitsprinzip:
- Skills werden einmal als wiederverwendbare Pipeline gebaut (z. B. `coding`, `vetting`, `canary`)
- Aufrufe laufen ueber Wrapper (`~/scripts/skill-forge` fuer Operations, `~/scripts/skills` fuer Domain-Standalone) statt dieselbe Faehigkeit als mehrere aehnliche Skills zu duplizieren
- Read-only Nightly Self-Check verfuegbar: `~/scripts/nightly-check.sh` (Policy Lint, Health, stale canaries, pending-review backlog); systemd-Timer-Vorlagen liegen in `systemd/nightly-self-check.service` und `systemd/nightly-self-check.timer`

Default-Regel:
- Domain-Use zuerst immer ueber `~/scripts/skills`
- `~/scripts/skill-forge` nur fuer Lifecycle/Governance (install/update/rollback/policy/audit/orchestrate/provenance)

Details: [docs/skills/skill-forge-governance.md](docs/skills/skill-forge-governance.md) – Kapitel "Boundary & Governance Model"

Pfad:
- `~/agent/skills/skill-forge/`

Wrapper:
- `~/scripts/skill-forge`
- `~/scripts/skills` (direkter Domain-Skill-Zugang)

Neue Wrapper-Flows:
- `~/scripts/skill-forge vet <slug> <score> --semantic`
- `~/scripts/skill-forge canary evaluate <slug>`

Memory-Verankerung (wichtig fuer Chat-Erkennung):
- `~/agent/MEMORY.md` (Langzeitgedaechtnis)
- `~/agent/memory/YYYY-MM-DD.md` (Tageskontext)
- `~/agent/USER.md` (Profilkontext)

Hinweis:
- OpenClaw ist das System.
- `Nanobot` ist nur der Telegram-Anzeigename.

## Ordnerstruktur

```
/home/steges/
├── docker-compose.yml  Alle Services in einer Datei
├── .env                Alle Secrets (nicht committen!)
├── pihole/config/      Pi-hole DNS, Ad-blocking & DHCP
├── homeassistant/config/ Smart Home
├── esphome/config/     ESP32/ESP8266 Firmware-Management
├── tailscale/state/    VPN Remote-Zugriff
├── infra/              Portainer-Daten, OpenClaw-Daten
├── ai/                 AI-Projekte (in Planung)
├── dev/                Dev-Projekte (in Planung)
├── docs/               Dokumentation
└── scripts/            Utility-Scripts
```

## Quick Start

```bash
# 1) Ins Projektverzeichnis wechseln
cd /home/steges

# 2) Pruefen, ob Docker laeuft
sudo systemctl status docker

# 3) Services starten
docker compose up -d

# 4) Health-Check ausfuehren
./scripts/health-check.sh

# 5) OpenClaw-Status pruefen
./scripts/skill-forge status
```

## Netzwerk

- LAN: `192.168.2.0/24`
- Pi-hole ist DNS- und DHCP-Server für das gesamte Heimnetz
- Speedport DHCP ist deaktiviert
- Remote-Zugriff über Tailscale VPN (`pilab`)

## Dokumentation

Siehe [docs/](docs/) für Details zu:
- [Architektur](docs/core/system-architecture.md)
- [Netzwerk & Ports](docs/core/network-topology.md)
- [Services](docs/core/services-and-ports.md)
- [Pi-hole Setup](docs/setup/pihole-setup.md)
- [Home Assistant Setup](docs/setup/homeassistant-setup.md)
- [Wartung](docs/operations/maintenance-and-backups.md)
- [Sicherheit](docs/core/security-baseline.md)
- [Skill-Manager Betrieb](docs/skills/skill-forge-governance.md)
- [Handover](docs/operations/session-handover.md)

## Handover fuer die naechste Session

Kurzfassung:

1. Start-Check aus `docs/operations/session-handover.md` ausfuehren.
2. Reihenfolge strikt einhalten: Implementieren -> Validieren -> Dokumentieren -> erst dann Todo aktualisieren.
3. Offene Arbeit ausschliesslich in `docs/operations/open-work-todo.md` pflegen.

Details und verbindliche Regelquelle:
- `docs/operations/session-handover.md`
- `.github/instructions/todo-lifecycle.instructions.md`

## Wartung

```bash
~/scripts/update-stacks.sh   # Alle Stacks updaten
~/scripts/backup.sh          # Backup der Konfigurationen
~/scripts/health-check.sh    # Health-Check aller Services
```

## Samba

`/home/steges/` ist im Heimnetz per SMB3 freigegeben (nur User `steges`).
`.env` Dateien sind per veto geblockt und nicht remote zugreifbar.
