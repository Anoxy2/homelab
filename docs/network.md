# Netzwerk & Ports

## LAN

- Subnetz: `192.168.2.0/24`
- Pi IP: `192.168.2.101` (statisch)
- Gateway: `192.168.2.1` (Router)

## Port-Übersicht

| Service | Port | Protokoll | Bindung |
|---------|------|-----------|---------|
| Pi-hole Web UI | 8080 | HTTP | 192.168.2.101 |
| Pi-hole DNS | 53 | UDP+TCP | 0.0.0.0 (host) |
| Home Assistant | 8123 | HTTP | 0.0.0.0 (host) |
| Portainer | 9000 | HTTP | 0.0.0.0 |
| SSH | 22 | TCP | 0.0.0.0 |
| Samba | 445 | TCP | 192.168.2.x |

## DNS-Setup

Pi-hole ist der DNS-Server für das gesamte Heimnetz.
Router-DHCP gibt `192.168.2.101` als DNS an alle Clients.

Upstream-DNS von Pi-hole: nach Wahl (z.B. 1.1.1.1 / 9.9.9.9)

Siehe [pihole-setup.md](pihole-setup.md) für Details zum systemd-resolved Konflikt.

## mDNS

Avahi läuft auf dem Pi → erreichbar als `raspberrypi.local` im LAN.
