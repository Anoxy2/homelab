---
title: "TOOLS.md Template"
summary: "Workspace template for TOOLS.md"
read_when:
  - Bootstrapping a workspace manually
---

# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Pilab Infrastructure

### Pi Hardware
- Board: Raspberry Pi 5 Model B (aarch64/arm64), 8 GB RAM
- Storage: 232 GB NVMe SSD (`/dev/nvme0n1`)
- OS: Debian 12 Bookworm
- LAN IP: 192.168.2.101 (statisch)
- Tailscale IP: 100.78.245.50 (Hostname: pilab)
- mDNS: raspberrypi.local

### SSH
- pilab → 192.168.2.101, user: steges

### Docker
Alle Services laufen in einem zentralen Compose-File: `/home/steges/docker-compose.yml`
Immer `docker compose` (v2), nie `docker-compose`.

Services und ihre Daten:
- pihole        → DNS, Ad-blocking, DHCP – Config: `./pihole/config`
- homeassistant → Smart Home Automation  – Config: `./homeassistant/config`
- esphome       → ESP32/ESP8266 Firmware – Config: `./esphome/config`
- tailscale     → VPN                    – State:  `./tailscale/state`
- mosquitto     → MQTT Broker            – Config: `./mosquitto/config/`
- portainer     → Docker Management UI
- watchtower    → Automatische Image-Updates (Sonntag 03:00)
- openclaw      → Dieser Agent           – Data:   `./infra/openclaw-data`
- ops-ui        → Canvas UI (statisch)   – HTML:   `./agent/skills/openclaw-ui/html`
- caddy         → Reverse Proxy fuer `.lan`-Hostnamen – Config: `./caddy/Caddyfile`

Befehle (immer aus `/home/steges/` ausführen):
```bash
docker compose up -d
docker compose logs -f [service]
docker compose pull && docker compose up -d
```

Skripte in `/home/steges/scripts/`:
- `update-stacks.sh` – alle Images updaten
- `backup.sh`        – Config-Backup nach ~/backups/YYYY-MM-DD/
- `health-check.sh`  – Service-Erreichbarkeit prüfen

### Service URLs
| Service        | URL                              |
|----------------|----------------------------------|
| Pi-hole Web UI | http://192.168.2.101:8080/admin  |
| Home Assistant | http://192.168.2.101:8123        |
| ESPHome        | http://192.168.2.101:6052        |
| Portainer      | http://192.168.2.101:9000        |
| OpenClaw GW    | http://192.168.2.101:18789       |
| Ops-UI / Canvas| http://192.168.2.101:8090        |
| Caddy Proxy    | http://192.168.2.101             |
| openclaw.lan   | http://openclaw.lan              |
| pihole.lan     | http://pihole.lan/admin          |
| ha.lan         | http://ha.lan                    |
| esphome.lan    | http://esphome.lan               |
| portainer.lan  | http://portainer.lan             |
| canvas.lan     | http://canvas.lan                |
| mqtt.lan (WS)  | ws://mqtt.lan                    |
| MQTT           | 192.168.2.101:1883               |
| Tailscale      | 100.78.245.50 / pilab            |

### RAG
- Zweck: lokale, quellengestuetzte Wissensabfragen ueber Docs, Growbox-Kontext und Agent-Runbooks
- Architektur: `/home/steges/agent/skills/openclaw-rag/ARCHITECTURE.md`
- Quellenregeln: `/home/steges/agent/skills/openclaw-rag/RAG-SOURCES.md`
- Testfragen: `/home/steges/agent/skills/openclaw-rag/TEST-QUESTIONS.md`
- Index: `/home/steges/infra/openclaw-data/rag/index.db`

RAG-Befehle:
```bash
# Top-5 Treffer als JSON
python3 ~/agent/skills/openclaw-rag/scripts/retrieve.py "Welche Services laufen auf dem Pi?"

# Voller Neuaufbau des Index
python3 ~/agent/skills/openclaw-rag/scripts/ingest.py --json

# Inkrementeller Reindex geaenderter Quellen
~/agent/skills/openclaw-rag/scripts/reindex.sh

# Index grob pruefen
sqlite3 ~/infra/openclaw-data/rag/index.db 'select count(*) as chunks, count(distinct source) as quellen from chunks;'
```

Rueckgabeformat von `retrieve.py`:
- `query`, `keywords`, `count`
- `results[]` mit `source`, `section`, `chunk_index`, `score`, `text`

Wann nutzen:
- bei "was wissen wir ueber X"
- bei Runbooks, Service-Referenzen, Ports, Growbox-Thresholds
- wenn lokale Doku schneller und belastbarer ist als freie Antwort

### Pi-Control
- Skill: `/home/steges/agent/skills/pi-control/SKILL.md`
- Contract: `pi.control`
- Zweck: sichere, deterministische Pi-Checks und Low-Risk-Operations statt ad-hoc Shell-Zugriff

Freigegebene Aktionen:
- Docker: `ps`, `restart <service>`, `logs <service> [tail]`
- Disk: `df`, `du -sh /home/steges/backups/`
- System-Metriken: CPU-Temp, RAM, Uptime
- Backup: `/home/steges/scripts/backup.sh`

Nicht erlaubt:
- `reboot`
- `shutdown`
- `docker system prune -a`
- `rm -rf`

### Growbox
→ Vollständige Referenz: `/home/steges/growbox/GROWBOX.md`
- ESP32 (growbox_wlan.yaml): SHT41 Sensor + 4× PWM-Lüfter + 4× Relais
- HA steuern: REST API http://192.168.2.101:8123/api/ mit Bearer $HA_TOKEN
- Tagebuch: `/home/steges/growbox/diary/YYYY-MM-DD.md`
- Zielwerte: `/home/steges/growbox/THRESHOLDS.md`

### Netzwerk-Regeln
- LAN: 192.168.2.0/24 – Services nur LAN-intern erreichbar
- Remote: ausschließlich via Tailscale VPN
- Kein Port-Forwarding am Router
- Pi-hole ist DNS + DHCP für alle LAN-Geräte → **NIE stoppen ohne Fallback-DNS!**

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.
