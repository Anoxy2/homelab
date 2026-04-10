# Pilab – Claude Code Kontext

## Was dieser Pi ist

Raspberry Pi 5 Homelab-Server. Läuft headless, 24/7. Alle Dienste laufen in Docker.
Dieses Verzeichnis (`/home/steges/`) ist die Arbeitsumgebung und gleichzeitig per Samba freigegeben.

> Beim Start immer `/home/steges/agent/HANDSHAKE.md` lesen. Dort ist die gemeinsame Sprache und das Uebergabeprotokoll zwischen Claude und OpenClaw definiert.

## Current State / Open Issues

- Arbeitsliste und Prioritaeten: `/home/steges/docs/operations/open-work-todo.md`
- Session-Handover und Start-/Abschluss-Check: `/home/steges/docs/operations/session-handover.md`
- Verbindliche Todo-Lifecycle-Regel aktiv: `/home/steges/.github/instructions/todo-lifecycle.instructions.md`
- Neue gemeinsame Protokollbasis: `/home/steges/agent/HANDSHAKE.md`
- Neuer Pi-Operations-Skill: `/home/steges/agent/skills/pi-control/SKILL.md`
- Changelog-Konvention aktiv: `/home/steges/CHANGELOG.md`
- Per-skill Kontext bleibt vorerst in den jeweiligen `SKILL.md` Dateien; separate per-skill `CLAUDE.md` Dateien werden nur eingefuehrt, wenn ein Skill dauerhaft mehr als eine lokale Kontextdatei braucht.

## Arbeitsregeln (verbindlich)

- Bei Todo-Umsetzung gilt strikt: **Implementieren -> Validieren -> Dokumentieren -> dann Todo aktualisieren**.
- Erledigte Todo-Punkte werden aus Todo-Dateien entfernt (Open-Work-Only), nicht als `[x]` historisiert.
- Bei Skill-Forge-Aenderungen mindestens ausfuehren: `~/scripts/skill-forge policy lint`, `bash -n` fuer geaenderte Scripts, und ein Laufzeit-Smoke-Check.
- Emergency-Pfade (z. B. Canary `--emergency`) muessen in `CHANGELOG.md` plus passender Fachdoku dokumentiert werden.

## Handover und Doku-Pflege (dauerhaft)

- Session-Start immer in dieser Reihenfolge: `CLAUDE.md` -> `agent/HANDSHAKE.md` -> `docs/operations/open-work-todo.md` -> `docs/operations/session-handover.md`.
- Wenn Todos abgeschlossen werden: erst Fach-Doku aktualisieren, danach Todo bereinigen (nur offene Punkte behalten).
- README-Handover, `docs/operations/session-handover.md` und `docs/operations/open-work-todo.md` muessen inhaltlich synchron bleiben.
- Bei neuen wiederkehrenden Prozessregeln immer zusaetzlich in `.github/instructions/todo-lifecycle.instructions.md` verankern.

## Wichtige Referenzen

- Growbox-Referenz: `/home/steges/growbox/GROWBOX.md`
- Agent-Identitaet: `/home/steges/agent/SOUL.md`
- Handshake-Protokoll: `/home/steges/agent/HANDSHAKE.md`
- Offene Umsetzungsliste: `/home/steges/docs/operations/open-work-todo.md`
- Repo-Navigation: `/home/steges/index.md`

## Hardware

| | |
|---|---|
| Board | Raspberry Pi 5 Model B Rev 1.1 |
| RAM | 8 GB |
| Storage | 232 GB NVMe SSD (`/dev/nvme0n1`) |
| Architektur | **aarch64 / arm64** |
| IP | 192.168.2.101 (statisch) |
| Tailscale-IP | 100.78.245.50 (Hostname: `pilab`) |
| Hostname | raspberrypi (LAN: `raspberrypi.local` via mDNS) |
| OS | Debian 12 Bookworm |

> **Wichtig:** Alle Docker-Images MÜSSEN arm64 unterstützen.

## Ordnerstruktur

```
/home/steges/
├── CLAUDE.md               # diese Datei
├── README.md
├── docker-compose.yml      # ALLE Services in einer Datei
├── caddy/                  # Reverse-Proxy-Konfiguration (Caddyfile)
├── .env                    # ALLE Secrets (nicht committen!)
├── .env.example            # Template ohne echte Werte
├── pihole/config/
├── homeassistant/config/
├── esphome/config/         # growbox_wlan.yaml, growbox_ap.yaml, secrets.yaml
├── mosquitto/              # MQTT Broker
│   ├── config/             # mosquitto.conf, passwd
│   ├── data/
│   └── log/
├── tailscale/state/
├── infra/openclaw-data/
├── growbox/                # Growbox-Daten & Tagebuch
│   ├── GROWBOX.md          # Entities & HA-API-Referenz
│   ├── GROW.md             # Aktueller Grow
│   ├── THRESHOLDS.md       # Zielwerte
│   └── diary/              # YYYY-MM-DD.md
├── agent/                  # OpenClaw Workspace
│   ├── SOUL.md, IDENTITY.md, USER.md, TOOLS.md, HEARTBEAT.md
│   ├── skills/
│   └── memory/
├── docs/                   # Dokumentation
├── systemd/
└── scripts/                # Utility-Scripts
```

## Services & Ports

| Service | URL | docker-compose Service |
|---------|-----|------------------------|
| Pi-hole Web UI | http://192.168.2.101:8080/admin | pihole |
| Pi-hole DNS | 192.168.2.101:53 | pihole |
| Pi-hole DHCP | 192.168.2.101:67 | pihole |
| Home Assistant | http://192.168.2.101:8123 | homeassistant |
| ESPHome | http://192.168.2.101:6052 | esphome |
| Mosquitto MQTT | 192.168.2.101:1883 | mosquitto |
| Mosquitto WebSocket | ws://mqtt.lan | mosquitto (via caddy) |
| Portainer | http://192.168.2.101:9000 | portainer |
| Watchtower | kein UI | watchtower |
| OpenClaw | 192.168.2.101:18789 | openclaw |
| Ops-UI / Canvas | http://192.168.2.101:8090 | ops-ui |
| Caddy Reverse Proxy | http://192.168.2.101 (z. B. openclaw.lan) | caddy |
| Tailscale | 100.78.245.50 / pilab | tailscale |
| Grafana | http://192.168.2.101:3003 | grafana |
| Prometheus | http://192.168.2.101:9090 | prometheus |
| InfluxDB | http://192.168.2.101:8086 | influxdb |
| Glances | http://192.168.2.101:61208 | glances |
| Homepage | http://192.168.2.101:3002 | homepage |
| Uptime Kuma | http://192.168.2.101:3001 | uptime-kuma |
| Unbound (DNS) | 192.168.2.101:5335 (intern) | unbound |
| Docker Socket Proxy | 127.0.0.1:2375 (intern) | docker-socket-proxy |
| Node Exporter | 192.168.2.101:9100 (intern) | node-exporter |
| RAG Embed API | http://192.168.2.101:18790 | rag-embed |
| ESP32 Growbox | http://growbox.local | (Hardware) |
| cAdvisor | http://192.168.2.101:8087 | cadvisor |
| Loki | http://192.168.2.101:3100 / loki.lan | loki |
| Alertmanager | http://192.168.2.101:9093 / alertmanager.lan | alertmanager |
| Vaultwarden | http://192.168.2.101:8888 / vault.lan | vaultwarden |
| Ntfy | http://192.168.2.101:8900 / ntfy.lan | ntfy |
| Scrutiny | http://192.168.2.101:8891 / scrutiny.lan | scrutiny |
| Authelia | http://192.168.2.101:9091 / auth.lan | authelia |
| SearXNG | http://192.168.2.101:8085 / search.lan | searxng |

## Docker-Konventionen

- Immer `docker compose` (v2), nie `docker-compose` (v1)
- Pi-hole, Home Assistant, ESPHome, Mosquitto, Tailscale nutzen `network_mode: host`
- Pi-hole und Tailscale brauchen `cap_add: [NET_ADMIN]`
- Secrets in `.env` – per Samba geblockt; ESPHome-Secrets in `esphome/config/secrets.yaml`
- Log-Rotation ist in `/etc/docker/daemon.json` konfiguriert (10 MB / 3 Files)
- Restart-Policy: `unless-stopped` für alle Dienste
- OpenClaw Memory-Limit: 1g / Reservation: 256m
- Caddy laeuft aktuell mit `network_mode: host`, weil die Backends mehrheitlich ebenfalls host-mode nutzen
- Canvas Single-Source: `agent/skills/openclaw-ui/html/index.html` ist die einzige Quelle; `infra/openclaw-data/canvas/index.html` ist nur noch ein Symlink dorthin
- `OPENCLAW_NO_RESPAWN=1` auf dem openclaw-Container ist **absichtlich**: OpenClaw erkennt Docker nicht als Supervisor (nur systemd/launchd/Windows). Ohne diese Variable würde ein Reload-Event einen detached Child-Prozess im Container forken → zwei Gateway-Prozesse auf Port 18789. Mit der Variable übernimmt Docker's `restart: unless-stopped` die gesamte Lifecycle-Kontrolle. Nicht entfernen.

## Häufige Befehle

```bash
# Alle Services starten
cd ~ && docker compose up -d

# Einzelnen Service starten/neustarten
cd ~ && docker compose up -d pihole
cd ~ && docker compose restart homeassistant

# Logs anschauen
cd ~ && docker compose logs -f pihole
cd ~ && docker compose logs -f homeassistant

# Alle laufenden Container
docker ps

# Images updaten (alle)
cd ~/scripts && ./update-stacks.sh

# Backup
cd ~/scripts && ./backup.sh
```

## Samba-Freigabe

`/home/steges/` ist im Heimnetz als SMB-Share freigegeben (nur User `steges`, SMB3).
Folgende Dateien sind per veto geblockt (nicht sichtbar/zugreifbar):
- `.env`, `.env.bak`, `secrets.env`, `memory`, `openclaw-data`

## Security

- LAN-Services nur im LAN erreichbar (192.168.2.0/24)
- Remote-Zugriff ausschließlich über Tailscale VPN
- Kein Port-Forwarding am Router nach außen
- `.env` Dateien niemals committen
- `.env.example` als Vorlage nutzen (ohne echte Werte)
- Docker-Socket fuer OpenClaw ist aktuell bewusst akzeptiertes Risiko: notwendig fuer lokale Compose- und Status-Operationen, aber effektiv Root-aehnlicher Host-Zugriff. Absicherung erfolgt ueber LAN-only-Betrieb, Tailscale statt Public Exposure, enge Skill-Grenzen, Audit-Logs und manuelle Review kritischer Aenderungen.

## Was NICHT tun

- Kein `docker system prune -a` ohne zu prüfen was läuft
- Kein Node.js system-weit installieren (Container nutzen)
- Keine `docker-compose` v1 Syntax
- Keine Images ohne arm64-Support verwenden
- Pi-hole nicht stoppen ohne Fallback-DNS – alle LAN-Geräte verlieren DNS
- Pi-hole DHCP nicht deaktivieren ohne Speedport DHCP wieder zu aktivieren
- Kein Traefik – Caddy ist der zentrale Reverse Proxy fuer lesbare `.lan`-Namen
- Kein Ollama – Pi ist zu langsam für LLM-Inference; Claude API wird genutzt
- `esphome/config/secrets.yaml` nicht committen (enthält WiFi + MQTT-Credentials)
- Mosquitto `passwd`-Datei nicht löschen ohne neuen User anzulegen
