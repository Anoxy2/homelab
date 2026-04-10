# Netzwerk & Ports

## LAN

- Subnetz: `192.168.2.0/24`
- Pi IP: `192.168.2.101` (statisch)
- Gateway: `192.168.2.1` (Router/Speedport)
- DNS: `192.168.2.101` (Pi-hole)
- DHCP: Pi-hole (Speedport DHCP deaktiviert), Range 192.168.2.100–199

## Topologie (aktuell)

```text
Internet
  |
Speedport Router (192.168.2.1)
  |
LAN 192.168.2.0/24
  |-- Raspberry Pi 5 (192.168.2.101)
  |    |-- Pi-hole DNS/DHCP
  |    |-- Home Assistant
  |    |-- ESPHome
  |    |-- Mosquitto (MQTT + WS)
  |    |-- OpenClaw + ops-ui + Caddy
  |
  |-- ESP32 Growbox (growbox.local)
  |-- weitere LAN-Clients
```

## Tailscale (VPN)

- Tailscale-IP: `100.78.245.50`
- Hostname: `pilab`
- Zugriff auf alle LAN-Services auch remote über Tailscale-IP möglich

## Port-Übersicht

| Service | Port | Protokoll | Bindung |
|---------|------|-----------|---------|
| Pi-hole Web UI | 8080 | HTTP | 0.0.0.0 (host) |
| Pi-hole DNS | 53 | UDP+TCP | 0.0.0.0 (host) |
| Pi-hole DHCP | 67/68 | UDP | 0.0.0.0 (host) |
| Home Assistant | 8123 | HTTP | 0.0.0.0 (host) |
| ESPHome | 6052 | HTTP | 0.0.0.0 (host) |
| Mosquitto MQTT | 1883 | TCP | 192.168.2.101 |
| Portainer | 9000 | HTTP | 0.0.0.0 |
| OpenClaw Gateway | 18789 | HTTP | 192.168.2.101 |
| Tailscale | 51820 | UDP | 0.0.0.0 |
| SSH | 22 | TCP | 0.0.0.0 |
| Samba | 445 | TCP | 192.168.2.x |
| ESP32 Web UI | 80 | HTTP | ESP32-IP (LAN) |

## Binding-Check (Live)

Zuletzt per `ss -tulpen` validiert:
- Mehrere Services binden auf `0.0.0.0` (z. B. 8080, 8123, 9000, 6052, 53).
- OpenClaw (`18789`) und rag-embed (`18790`) sind explizit auf `192.168.2.101` gebunden.
- Caddy lauscht auf Port `80` fuer Hostname-Routing im LAN.
- SSH (`22`) bleibt auf allen Interfaces erreichbar (LAN + Tailscale).
- MQTT wurde gehaertet: Mosquitto Listener sind auf `192.168.2.101` gebunden (kein `0.0.0.0` fuer 1883/9001 mehr).

## Growbox-Datenfluss

```
ESP32 (growbox_wlan)
  ├── ESPHome native API → Home Assistant (Port 6053, automatisch)
  └── MQTT → Mosquitto (192.168.2.101:1883) → Home Assistant

Home Assistant REST API (Port 8123)
  └── OpenClaw Agent → Abfragen & Steuerung via HA_TOKEN
```

## DNS-Setup

Pi-hole ist der DNS- und DHCP-Server für das gesamte Heimnetz.
Der Speedport-Router hat DHCP deaktiviert – Pi-hole übernimmt die Vergabe aller IPs.

Upstream-DNS von Pi-hole: nach Wahl in Pi-hole Admin → Settings → DNS

Siehe [pihole-setup.md](pihole-setup.md) für Details.

## mDNS

Avahi läuft auf dem Pi → erreichbar als `raspberrypi.local` im LAN.
ESP32 nach Flash erreichbar als `growbox.local`.
