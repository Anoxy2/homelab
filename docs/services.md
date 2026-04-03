# Services

## Pi-hole

- **Zweck:** DNS-basiertes Ad-blocking und LAN-DNS-Server
- **URL:** http://192.168.2.101:8080/admin
- **Stack:** ~/pihole/
- **Image:** `pihole/pihole:latest` (arm64)
- **Netzwerk:** host
- **Daten:** ~/pihole/config/

## Home Assistant

- **Zweck:** Smart Home Automation
- **URL:** http://192.168.2.101:8123
- **Stack:** ~/homeassistant/
- **Image:** `ghcr.io/home-assistant/home-assistant:stable` (arm64)
- **Netzwerk:** host (für mDNS/device discovery)
- **Daten:** ~/homeassistant/config/

## Portainer

- **Zweck:** Docker Management Web UI
- **URL:** http://192.168.2.101:9000
- **Stack:** ~/infra/
- **Image:** `portainer/portainer-ce:latest` (arm64)
- **Daten:** Docker Volume `portainer_data`

## Watchtower

- **Zweck:** Automatische Docker Image Updates
- **Stack:** ~/infra/
- **Image:** `containrrr/watchtower:latest` (arm64)
- **Schedule:** wöchentlich (Sonntag Nacht)
