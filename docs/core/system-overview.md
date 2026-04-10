# System-Übersicht — Pilab

_Einseiten-Karte aller Komponenten und wie sie zusammenspielen. Zuletzt aktualisiert: 2026-04-09._

---

## Das große Bild

```
Internet
    │
    │ (kein Port-Forwarding)
    │
Speedport Router (192.168.2.1)
    │
    ├── Raspberry Pi 5 (192.168.2.101) ←─── Tailscale VPN (100.78.245.50)
    │       │
    │       ├── Pi-hole (DNS/DHCP) ──────── alle LAN-Geräte
    │       ├── Home Assistant ──────────── ESP32 Growbox (growbox.local)
    │       ├── ESPHome ─────────────────── ESP32 Flash/Config
    │       ├── Mosquitto MQTT ──────────── ESP32 Growbox Events
    │       ├── OpenClaw Gateway ────────── Claude API ↔ steges Telegram
    │       ├── Caddy Reverse Proxy ─────── *.lan → Docker-Services
    │       ├── Monitoring Stack ────────── Grafana / Prometheus / InfluxDB
    │       └── RAG Embed Service ───────── all-MiniLM-L6-v2 Embeddings
    │
    └── LAN-Geräte (PC, Handy, ...)
```

## Kommunikationsfluss: steges ↔ OpenClaw

```
steges
  │
  ├── Telegram ──→ OpenClaw Gateway (Port 18789) ──→ Claude API
  │                        │
  │                        └── Skill-System (~/scripts/skills/*)
  │
  ├── Claude Code (SSH) ──→ direkte Datei/Terminal-Arbeit
  │
  └── Canvas UI (Port 8090) ──→ ops-ui Container ──→ OpenClaw
```

## Growbox-Datenfluss

```
ESP32 (growbox.local)
    │
    ├── ESPHome Native API ──→ Home Assistant (Port 8123)
    │                                │
    │                                ├── REST API (HA_TOKEN)
    │                                │        │
    │                                │        └── OpenClaw ha-control Skill
    │                                │                     │
    │                                │                     └── RAG + Heartbeat
    │                                │
    │                                └── Growbox Diary (täglich)
    │
    └── MQTT ──→ Mosquitto (Port 1883) ──→ HA (alternativ/Event-basiert)
```

## Wer darf was: Skill-Grenzen

| Aktion | Tool | Erlaubt ohne Bestätigung |
|--------|------|--------------------------|
| Pi-Status lesen | pi-control | ✓ |
| HA-Entities lesen | ha-control | ✓ (alle Domains) |
| Growbox-Lüfter steuern | ha-control (Tier-1) | ✓ (whitelisted) |
| Docker-Container stoppen | — | ✗ (Eskalation) |
| Secrets lesen/schreiben | — | ✗ (nie) |
| Externe Nachrichten senden | — | ✗ (Rückfrage) |
| Skill installieren | skill-forge | ✓ (nach Vetting) |
| Skill promoten | skill-forge | ✗ (Canary-Gate nötig) |

## Wichtige Dateipfade

| Inhalt | Pfad |
|--------|------|
| Alle Services & Ports | `docs/core/services-and-ports.md` |
| Docker-Compose | `~/docker-compose.yml` |
| Secrets | `~/.env` (nie committen!) |
| Growbox Entities | `growbox/GROWBOX.md` |
| Growbox Thresholds | `growbox/THRESHOLDS.md` |
| Skill-Inventory | `agent/SKILL-INVENTORY.md` |
| Mein Selbstbild | `agent/SELF-MODEL.md` |
| HANDSHAKE-Protokoll | `agent/HANDSHAKE.md` |
| RAG-Quellen | `agent/skills/openclaw-rag/RAG-SOURCES.md` |
| Offene Todos | `docs/operations/open-work-todo.md` |

## Wie neue Dienste hinzukommen

1. Docker-Image auf ARM64-Kompatibilität prüfen
2. `docker-compose.yml` erweitern
3. `docs/core/services-and-ports.md` aktualisieren
4. Caddy-Route in `caddy/Caddyfile` hinzufügen (wenn `.lan`-URL gewünscht)
5. RAG reindexieren: `~/agent/skills/openclaw-rag/scripts/reindex.sh`

## Monitoring

- **Grafana:** http://192.168.2.101:3003 — Dashboards für System/Docker/Growbox
- **Prometheus:** http://192.168.2.101:9090 — Metriken-Scraping
- **Uptime Kuma:** http://192.168.2.101:3001 — Service-Uptime
- **Glances:** http://192.168.2.101:61208 — System-Ressourcen live
- **Portainer:** http://192.168.2.101:9000 — Docker-UI
