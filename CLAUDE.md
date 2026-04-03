# Pilab – Claude Code Kontext

## Was dieser Pi ist

Raspberry Pi 5 Homelab-Server. Läuft headless, 24/7. Alle Dienste laufen in Docker.
Dieses Verzeichnis (`/home/steges/`) ist die Arbeitsumgebung und gleichzeitig per Samba freigegeben.

## Hardware

| | |
|---|---|
| Board | Raspberry Pi 5 Model B Rev 1.1 |
| RAM | 8 GB |
| Storage | 232 GB NVMe SSD (`/dev/nvme0n1`) |
| Architektur | **aarch64 / arm64** |
| IP | 192.168.2.101 (statisch) |
| Hostname | raspberrypi (LAN: `raspberrypi.local` via mDNS) |
| OS | Debian 12 Bookworm |

> **Wichtig:** Alle Docker-Images MÜSSEN arm64 unterstützen.

## Ordnerstruktur

```
/home/steges/
├── CLAUDE.md               # diese Datei
├── README.md
├── pihole/                 # Pi-hole DNS + Ad-blocking
│   ├── docker-compose.yml
│   ├── .env
│   └── config/
├── homeassistant/          # Home Assistant
│   ├── docker-compose.yml
│   ├── .env
│   └── config/
├── infra/                  # Portainer + Watchtower
│   ├── docker-compose.yml
│   └── .env
├── ai/                     # AI-Projekte (noch offen)
├── dev/                    # Dev-Projekte (noch offen)
├── docs/                   # Dokumentation
└── scripts/                # Utility-Scripts
```

## Services & Ports

| Service | URL | Stack |
|---------|-----|-------|
| Pi-hole Web UI | http://192.168.2.101:8080/admin | pihole/ |
| Pi-hole DNS | 192.168.2.101:53 | pihole/ |
| Home Assistant | http://192.168.2.101:8123 | homeassistant/ |
| Portainer | http://192.168.2.101:9000 | infra/ |
| Watchtower | kein UI | infra/ |

## Docker-Konventionen

- Immer `docker compose` (v2), nie `docker-compose` (v1)
- Pi-hole und Home Assistant nutzen `network_mode: host` (wegen DNS port 53 und mDNS)
- Secrets in `.env` Dateien – diese sind per Samba geblockt (veto files)
- Log-Rotation ist in `/etc/docker/daemon.json` konfiguriert (10 MB / 3 Files)
- Restart-Policy: `unless-stopped` für alle Dienste

## Häufige Befehle

```bash
# Stack starten
cd ~/pihole && docker compose up -d
cd ~/homeassistant && docker compose up -d
cd ~/infra && docker compose up -d

# Logs anschauen
docker compose logs -f [service]

# Alle laufenden Container
docker ps

# Images updaten
cd ~/scripts && ./update-stacks.sh

# Backup
cd ~/scripts && ./backup.sh
```

## Samba-Freigabe

`/home/steges/` ist im Heimnetz als SMB-Share freigegeben (nur User `steges`, SMB3).
Folgende Dateien sind per veto geblockt (nicht sichtbar/zugreifbar):
- `.env`, `.env.bak`, `secrets.env`

## Security

- Alle Dienste sind **nur im LAN** erreichbar (192.168.2.0/24)
- Kein Port-Forwarding nach außen
- `.env` Dateien niemals committen
- `.env.example` als Vorlage nutzen (ohne echte Werte)

## Was NICHT tun

- Kein `docker system prune -a` ohne zu prüfen was läuft
- Kein Node.js system-weit installieren (Container nutzen)
- Keine `docker-compose` v1 Syntax
- Keine Images ohne arm64-Support verwenden
- Pi-hole DNS nicht ändern während andere Services laufen (DNS-Ausfall)
- Kein Traefik – Services werden direkt per IP:Port erreicht
- Kein Ollama – Pi ist zu langsam für LLM-Inference; Claude API wird genutzt
