# Architektur

## Übersicht

Alle Dienste laufen in Docker-Containern. Caddy stellt lesbare `.lan`-Hostnamen als Reverse Proxy bereit.

```
Internet
    ↓ Tailscale VPN (100.78.245.50)
Raspberry Pi 5 (192.168.2.101)
    ├── Caddy          Reverse Proxy (`*.lan`)
    ├── Pi-hole        DNS + DHCP + Ad-blocking
    ├── Home Assistant Smart Home + Growbox-Daten
    ├── ESPHome        ESP32 Firmware Management
    ├── Mosquitto      MQTT Broker
    ├── Tailscale      VPN
    ├── Portainer      Docker UI
    ├── ops-ui         Canvas Web UI
    ├── Watchtower     Auto-Updates
    ├── rag-embed      lokale Embedding API (RAG)
    └── OpenClaw       KI-Agent (Claude API)
            ├── Skill-Manager   Skill Lifecycle + Writer + Canary + Governance
            │     ├── coding    Planner -> Coder -> Reviewer (writer backend)
            │     ├── vetting   Optionale semantische Vetting-Erweiterung
            │     ├── canary    Read-only Evaluate (Go/No-Go/Extend)
            │     └── core      Gemeinsame Rollen- und Output-Konventionen
            ↓ HA REST API
    ESP32 (Growbox)
        SHT41 → Temp/Humidity/VPD
        4× PWM-Lüfter + 4× Relais
```

## Docker-Netzwerke

- **host network:** Pi-hole, Home Assistant, ESPHome, Mosquitto, Tailscale, Caddy
- **bridge (default):** Portainer, Watchtower, OpenClaw, ops-ui, rag-embed

## Verzeichnisstruktur

Alle Dienste laufen aus einer einzigen `docker-compose.yml` im Home-Verzeichnis.
Unterordner enthalten nur Konfigurationsdaten.

```
~/
├── docker-compose.yml          → alle Services
├── .env                        → alle Secrets
├── .env.example                → Vorlage ohne echte Werte
│
├── pihole/config/              → Pi-hole Konfiguration
├── homeassistant/config/       → Home Assistant Konfiguration
│   └── automations.yaml        → Growbox Tag/Nacht-Automationen
├── esphome/config/             → ESP32 Firmware-Configs
│   ├── growbox_wlan.yaml       → Growbox (WLAN + HA API + MQTT)
│   ├── growbox_ap.yaml         → Growbox (AP-Fallback, standalone)
│   └── secrets.yaml            → ESPHome Secrets (WiFi, OTA, MQTT)
├── mosquitto/
│   ├── config/mosquitto.conf   → Broker-Konfiguration
│   ├── config/passwd           → MQTT Auth (User: iot)
│   ├── data/                   → Persistenz
│   └── log/                    → Logs
├── tailscale/state/            → Tailscale Auth-State
├── infra/openclaw-data/        → OpenClaw Agent-Daten
│
├── growbox/                    → Growbox-Dokumentation & Tagebuch
│   ├── GROWBOX.md              → Entities, HA-API-Referenz
│   ├── GROW.md                 → Aktueller Grow
│   ├── THRESHOLDS.md           → Zielwerte (Temp, RH, VPD)
│   └── diary/YYYY-MM-DD.md    → Tageseinträge
│
├── agent/                      → OpenClaw Agent-Workspace
│   ├── SOUL.md                 → Agent-Persönlichkeit
│   ├── IDENTITY.md             → Agent-Identität (Claw)
│   ├── USER.md                 → User-Profil (steges)
│   ├── TOOLS.md                → Infrastruktur-Referenz
│   ├── HEARTBEAT.md            → Periodische Checks
│   └── skills/skill-forge/   → Skill-Lifecycle Engine + State + Policy
│   └── memory/                 → Agent-Gedächtnis
│
├── docs/                       → Diese Dokumentation
└── scripts/                    → Utility-Skripte (`skill-forge` + `skills` Wrapper)
```

## Designentscheidungen

- **Kein Traefik:** Caddy ist der zentrale Reverse Proxy fuer `.lan`-Hostnamen
- **Reverse Proxy im LAN:** Caddy bleibt der zentrale Proxy, intern als plain HTTP im Trusted-LAN.
- **Kein Ollama:** Pi 5 zu langsam für LLM-Inference; Claude API wird extern genutzt
- **Kein code-server:** VS Code Remote SSH ist bereits eingerichtet
- **Pi-hole als LAN-DNS + DHCP:** Speedport DHCP deaktiviert, Pi-hole übernimmt vollständig
- **Tailscale statt WireGuard:** einfacheres Setup, kein manuelles Key-Management
- **MQTT + native ESPHome API:** ESP32 sendet parallel über beide Protokolle an HA
- **Canvas MQTT Auth:** Canvas nutzt die vorhandenen Haupt-Credentials aus den lokalen Settings; kein separater Mosquitto-User nur fuer Canvas.
- **Agent steuert Growbox via HA REST API:** kein direkter MQTT-Zugriff vom Agent nötig
- **Skill-Manager Hybrid-Architektur:** Agenten fuer semantische Entscheidungen, Skripte fuer deterministische State-Operationen
- **Wrapper-first Skill-Reuse:** gleiche Faehigkeit einmal bauen und ueber Wrapper/Dispatcher wiederverwenden statt mehrere aehnliche Skills parallel zu pflegen
- **RAG Backend:** SQLite (`FTS5` + `sqlite-vec`) ist gesetzt; Chroma wird nicht verwendet.
- **RAG Ingestion Runtime:** eigener Embedding-Container mit warmem Modell, weil Growbox-Diary/Logs/Doku taeglich wechseln.
- **Handshake-Protokoll:** `agent/HANDSHAKE.md` ist bewusst reines Markdown-Protokoll und kein zustandsfuehrendes State-File.
