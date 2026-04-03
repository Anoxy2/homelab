# Pilab – Raspberry Pi 5 Homelab

Persönlicher Homelab-Server auf Basis eines Raspberry Pi 5.

## Hardware

- **Board:** Raspberry Pi 5 Model B, 8 GB RAM
- **Storage:** 232 GB NVMe SSD
- **OS:** Debian 12 Bookworm (arm64)
- **IP:** 192.168.2.101 (statisch)
- **Kühlung:** Aktiv

## Services

| Service | Zweck | URL |
|---------|-------|-----|
| Pi-hole | DNS Ad-blocking, LAN-DNS | http://192.168.2.101:8080/admin |
| Home Assistant | Smart Home Automation | http://192.168.2.101:8123 |
| Portainer | Docker Management UI | http://192.168.2.101:9000 |
| Watchtower | Automatische Image-Updates | – |

## Ordnerstruktur

```
/home/steges/
├── pihole/           Pi-hole DNS & Ad-blocking
├── homeassistant/    Smart Home
├── infra/            Portainer + Watchtower
├── ai/               AI-Projekte (in Planung)
├── dev/              Dev-Projekte (in Planung)
├── docs/             Dokumentation
└── scripts/          Utility-Scripts
```

## Quick Start

```bash
# Voraussetzung: Docker daemon läuft
sudo systemctl status docker

# Pi-hole starten
cd ~/pihole && docker compose up -d

# Home Assistant starten
cd ~/homeassistant && docker compose up -d

# Infra (Portainer + Watchtower) starten
cd ~/infra && docker compose up -d
```

## Netzwerk

- LAN: `192.168.2.0/24`
- Pi-hole ist der DNS-Server für das gesamte Heimnetz
- Alle Services sind nur im LAN erreichbar, kein externer Zugriff

## Dokumentation

Siehe [docs/](docs/) für Details zu:
- [Architektur](docs/architecture.md)
- [Netzwerk & Ports](docs/network.md)
- [Services](docs/services.md)
- [Pi-hole Setup](docs/pihole-setup.md)
- [Home Assistant Setup](docs/homeassistant-setup.md)
- [Wartung](docs/maintenance.md)
- [Sicherheit](docs/security.md)

## Wartung

```bash
# Alle Stacks updaten
~/scripts/update-stacks.sh

# Backup der Konfigurationen
~/scripts/backup.sh

# Health-Check
~/scripts/health-check.sh
```

## Samba

`/home/steges/` ist im Heimnetz per SMB3 freigegeben (nur User `steges`).
`.env` Dateien sind per veto geblockt und nicht remote zugreifbar.
