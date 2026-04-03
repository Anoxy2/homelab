# Architektur

## Übersicht

Alle Dienste laufen in Docker-Containern. Kein Reverse Proxy – direkter Zugriff per IP:Port.

## Docker-Netzwerke

- **host network:** Pi-hole (braucht Port 53), Home Assistant (mDNS/device discovery)
- **bridge (default):** Portainer, Watchtower

## Stack-Aufteilung

Jeder Dienst hat seinen eigenen Ordner mit eigenem `docker-compose.yml`.
Das erlaubt unabhängiges Starten/Stoppen ohne andere Services zu beeinflussen.

## Designentscheidungen

- Kein Traefik/Reverse Proxy: Services werden direkt per IP:Port erreicht
- Kein Ollama: Pi 5 zu langsam für LLM-Inference; Claude API wird extern genutzt
- Kein code-server: VS Code Remote SSH ist bereits eingerichtet
- Pi-hole als LAN-DNS: Alle Clients im Netz nutzen 192.168.2.101 als DNS
