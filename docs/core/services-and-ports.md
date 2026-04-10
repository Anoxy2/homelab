# Services

## Pi-hole

- **Zweck:** DNS-basiertes Ad-blocking, LAN-DNS-Server, DHCP-Server
- **URL:** http://192.168.2.101:8080/admin
- **Service:** `pihole` (docker-compose.yml)
- **Image:** `pihole/pihole:latest` (arm64)
- **Netzwerk:** host
- **Daten:** `~/pihole/config/`
- **Hinweis:** DHCP-Server aktiv (Speedport DHCP deaktiviert), braucht `NET_ADMIN` Capability
- **Local DNS:** Wildcard `*.lan -> 192.168.2.101` ist aktiv (via `pihole.toml` / `dnsmasq_lines`)

## Unbound

- **Zweck:** Lokaler rekursiver DNS-Resolver als Pi-hole-Upstream
- **Service:** `unbound` (docker-compose.yml)
- **Image:** `crazymax/unbound:latest` (arm64)
- **Netzwerk:** host
- **Port:** 5335 (lokal)
- **Daten:** `~/unbound/config/`
- **Pi-hole Upstream:** `127.0.0.1#5335`

## Home Assistant

- **Zweck:** Smart Home Automation, Growbox-Datenintegration
- **URL:** http://192.168.2.101:8123
- **Service:** `homeassistant` (docker-compose.yml)
- **Image:** `ghcr.io/home-assistant/home-assistant:stable` (arm64)
- **Netzwerk:** host (für mDNS/device discovery)
- **Daten:** `~/homeassistant/config/`
- **Integrationen:** ESPHome (native API), MQTT
- **API:** REST API auf Port 8123, Long-Lived Token in `.env` als `HA_TOKEN`

## ESPHome

- **Zweck:** Firmware-Management für ESP32/ESP8266 Geräte
- **URL:** http://192.168.2.101:6052
- **Service:** `esphome` (docker-compose.yml)
- **Image:** `ghcr.io/esphome/esphome:latest` (arm64)
- **Netzwerk:** host
- **Daten:** `~/esphome/config/`
- **Geräte:**
  - `growbox_wlan.yaml` – Growbox ESP32 (WLAN-Modus, SHT41, 4× Lüfter/Relais)
  - `growbox_ap.yaml` – Growbox ESP32 (AP-Fallback, standalone)

## Mosquitto (MQTT Broker)

- **Zweck:** MQTT-Broker für ESP32-Kommunikation mit Home Assistant
- **Service:** `mosquitto` (docker-compose.yml)
- **Image:** `eclipse-mosquitto:latest` (arm64)
- **Netzwerk:** host
- **Port:** 1883 (MQTT), 9001 (WebSocket)
- **Binding:** Listener sind auf `192.168.2.101` beschraenkt (LAN-IP), nicht auf allen Interfaces
- **Daten:** `~/mosquitto/config/`, `~/mosquitto/data/`, `~/mosquitto/log/`
- **Auth:** Passwort-Datei `~/mosquitto/config/passwd` (User: `iot`)
- **WebSocket via Caddy:** `ws://mqtt.lan`
- **Logging:** `log_dest stdout` (Datei-Logging deaktiviert; Rotation ueber Docker-Logs)
- **Hinweis:** Passwort-Datei muss manuell angelegt werden:
  ```bash
  docker exec mosquitto mosquitto_passwd -c /mosquitto/config/passwd iot
  ```

## Growbox (ESP32)

- **Zweck:** Klimasteuerung Growbox – Sensoren, Lüfter, Relais
- **Hardware:** ESP32 mit SHT41 (Temp/Humidity), 4× PWM-Lüfter (25 kHz), 4× Relais (Elegoo 8-Kanal Active-LOW)
- **Firmware:** ESPHome (`growbox_wlan.yaml`)
- **Anbindung:** ESPHome native API → Home Assistant + MQTT → Mosquitto
- **Web UI lokal:** http://growbox.local (Port 80, nach Flash)
- **Betriebsmodi:** Manuell / Auto (Temperatur) / Nacht
- **Referenz:** `~/growbox/GROWBOX.md`

## Tailscale

- **Zweck:** VPN – sicherer Remote-Zugriff von überall
- **Service:** `tailscale` (docker-compose.yml)
- **Image:** `tailscale/tailscale:latest` (arm64)
- **Netzwerk:** host
- **Tailscale-IP:** 100.78.245.50
- **Hostname im Tailnet:** pilab
- **Daten:** `~/tailscale/state/`
- **Hinweis:** Auth-Key in .env, braucht `NET_ADMIN` + `NET_RAW` + `/dev/net/tun`

## Portainer

- **Zweck:** Docker Management Web UI
- **URL:** http://192.168.2.101:9000
- **Service:** `portainer` (docker-compose.yml)
- **Image:** `portainer/portainer-ce:latest` (arm64)
- **Daten:** Docker Volume `portainer_data`

## Ops-UI / Canvas

- **Zweck:** Lokales Operations- und Canvas-Frontend fuer OpenClaw
- **URL direkt:** http://192.168.2.101:8090
- **URL via Caddy:** http://canvas.lan
- **Zentrale Kurz-URLs:** http://ops.lan und http://zentrale.lan
- **Service:** `ops-ui` (docker-compose.yml)
- **Image:** `nginx:alpine` (arm64)
- **Datenquelle (canonical):** `~/agent/skills/openclaw-ui/html/index.html`
- **Deployment-Pfad:** `ops-ui` mountet `~/agent/skills/openclaw-ui/html/` read-only nach `/usr/share/nginx/html/`; `infra/openclaw-data/canvas/index.html` ist als Symlink auf die Canonical-Quelle gesetzt
- **Drift-Check:** `~/scripts/canvas-drift-check.sh` vergleicht SHA256 von Canonical-Quelle und deployed Canvas-Datei (Exit `0`=ok, `3`=drift)
- **Rollback (UI):** vorherige Version der Canonical-Datei zurueckspielen und `docker compose restart ops-ui` ausfuehren
- **MQTT Credentials:** werden in der Settings-Seite lokal im Browser (`localStorage`) gespeichert und fuer MQTT-Connect verwendet
- **Settings Input Hygiene:** HA-URL wird auf `http/https` validiert, Query-/Hash-Parameter werden entfernt; MQTT-Host akzeptiert nur gueltige Hostnamen/IP-Muster, invalide Eingaben werden beim Speichern blockiert
- **Storage Keyspace Versioning:** Canvas nutzt versionierte Browser-Keys (`oc.canvas.v2.*`) mit Legacy-Migration von `oc-canvas-cfg`/`oc-chat-history`
- **Local Credential Reset:** Settings bieten `Reset local credentials` und loeschen lokal gespeicherte HA/MQTT-Credentials gezielt
- **Growbox Live-Panel:** Dashboard zeigt Temperatur, Luftfeuchtigkeit und CO2 aus Home Assistant REST (`/api/states/...`) mit ok/warn/bad-Farbstatus auf Basis der in Settings gesetzten Thresholds
- **Growbox VPD + Alarm Badge:** Canvas berechnet VPD aus Temperatur/Luftfeuchtigkeit (`kPa`) und zeigt einen kombinierten Alarm-Badge (`OK`/`WARN`/`ALARM`) fuer Threshold-Verletzungen.
- **Growbox Mini-Sparklines (24h):** Temperatur und Luftfeuchtigkeit werden ueber HA History API als Mini-Chart im Dashboard visualisiert.
- **Pi Temperatur im Live-Signals-Panel:** liest HA-Entity `sensor.raspberry_pi_cpu_temperature` (warn ab 70°C, bad ab 80°C)
- **HA API Settings:** `HA URL` und `HA Token` werden lokal im Browser (`localStorage`) gespeichert und fuer Growbox-Live-Refresh verwendet
- **Growbox Auto-Refresh:** Standard 30s, in Settings konfigurierbar
- **Ops Links in Settings:** Schnellzugriff auf `uptime.lan` und `glances.lan`
- **Action-Log im Canvas:** MQTT-Seite zeigt die letzten 50 OpenClaw-Action-Log-Eintraege aus `/action-log.latest.json`.
- **Doc-Tabs im Canvas:** Operations, Decisions und Runbooks lesen ihren Zustand aus `/ops-brief.latest.json` und bilden offene Arbeit, Handover, Decision-Index und Runbook-Summaries ab.
- **Feed-Erzeugung:** `skill-forge heartbeat` schreibt/aktualisiert `~/agent/skills/openclaw-ui/html/action-log.latest.json` aus `~/infra/openclaw-data/action-log.jsonl` und aktualisiert `~/agent/skills/openclaw-ui/html/ops-brief.latest.json` ueber `~/scripts/canvas-ops-brief.sh`.
- **Shortcuts:** `1-5` Seitenwechsel fuer Core-Seiten, `r` Health-Refresh, `Esc` Dialog/Fokus schliessen

## Uptime Kuma

- **Zweck:** Uptime-Monitoring und Alarmierung fuer Core-Services
- **URL direkt:** http://192.168.2.101:3001
- **URL via Caddy:** http://uptime.lan
- **Service:** `uptime-kuma` (docker-compose.yml)
- **Image:** `louislam/uptime-kuma:latest` (arm64)
- **Daten:** Docker Volume `uptime-kuma_data`
- **Empfohlene Monitore:** OpenClaw (`:18789`), Home Assistant (`:8123`), Pi-hole (`:8080/admin`), Mosquitto WS (`:9001`), ops-ui (`:8090`), Portainer (`:9000`)
- **Telegram Alerting:** in Uptime Kuma unter `Settings -> Notifications -> Telegram` denselben Bot-Token wie OpenClaw verwenden und auf die Ziel-Chat-ID senden

## Glances

- **Zweck:** Live-Systemmetriken (CPU, RAM, Temperatur, Docker, Disk) im Browser
- **URL direkt:** http://192.168.2.101:61208
- **URL via Caddy:** http://glances.lan
- **Service:** `glances` (docker-compose.yml)
- **Image:** `nicolargo/glances:latest-full` (arm64)
- **Betrieb:** host-network + host-pid, Docker-Socket read-only

## Homepage Dashboard

- **Zweck:** Startseite/Dashboard mit zentralen Service-Links und Widgets
- **URL direkt:** http://192.168.2.101:3002
- **URL via Caddy:** http://home.lan und http://dashboard.lan
- **Service:** `homepage` (docker-compose.yml)
- **Image:** `ghcr.io/gethomepage/homepage:latest` (arm64)
- **Konfiguration:** `~/homepage/config/services.yaml`, `settings.yaml`, `widgets.yaml`, `bookmarks.yaml`

## InfluxDB 2

- **Zweck:** Zeitreihen-Speicher fuer Sensor-Historie und schnelle Langzeitabfragen
- **URL direkt:** http://192.168.2.101:8086
- **URL via Caddy:** http://influx.lan
- **Service:** `influxdb` (docker-compose.yml)
- **Image:** `influxdb:2.7.12` (arm64)
- **Daten:** `~/influxdb/data/`, `~/influxdb/config/`
- **Init-Variablen:** `.env` (`INFLUXDB_ADMIN_USER`, `INFLUXDB_ADMIN_PASSWORD`, `INFLUXDB_ADMIN_TOKEN`, `INFLUXDB_ORG`, `INFLUXDB_BUCKET`)

## Caddy (Reverse Proxy)

- **Zweck:** Lesbare LAN-Hostnamen (`*.lan`) statt IP:Port-URLs
- **URL:** http://192.168.2.101
- **Service:** `caddy` (docker-compose.yml)
- **Image:** `caddy:2-alpine` (arm64)
- **Netzwerk:** host (aktuell, damit host-mode Backends direkt erreichbar sind)
- **Konfiguration:** `~/caddy/Caddyfile`
- **Healthcheck:** eigener lokaler Host `caddy-health.lan` mit `200 ok`; Docker prueft damit die Proxy-Instanz selbst statt eines Backends
- **Routen (Core):** `pihole.lan`, `ha.lan`, `esphome.lan`, `portainer.lan`, `openclaw.lan`, `canvas.lan`, `ops.lan`, `zentrale.lan`, `mqtt.lan`
- **Routen (inkl. Ops):** `pihole.lan`, `ha.lan`, `esphome.lan`, `portainer.lan`, `openclaw.lan`, `canvas.lan`, `ops.lan`, `zentrale.lan`, `uptime.lan`, `glances.lan`, `home.lan`, `dashboard.lan`, `mqtt.lan`, `grafana.lan`, `prometheus.lan`, `influx.lan`

## Watchtower

- **Zweck:** Automatische Docker Image Updates
- **Service:** `watchtower` (docker-compose.yml)
- **Image:** `containrrr/watchtower:latest` (arm64)
- **Schedule:** Sonntag 03:00
- **Modus:** Label-Opt-in (`WATCHTOWER_LABEL_ENABLE=true`)
- **Auto-Update aktiv fuer:** `esphome`, `portainer`, `mosquitto`, `watchtower`, `ops-ui`
- **Auto-Update aktiv fuer:** `esphome`, `portainer`, `mosquitto`, `watchtower`, `ops-ui`, `uptime-kuma`, `glances`, `homepage`
- **Auto-Update explizit deaktiviert fuer:** `homeassistant`, `pihole`, `openclaw`

## OpenClaw (Claude Agent)

- **Zweck:** KI-Assistent mit Zugriff auf Pi, Docker, Home Assistant, Growbox
- **URL:** http://192.168.2.101:18789 (Gateway)
- **Service:** `openclaw` (docker-compose.yml)
- **Image:** `ghcr.io/openclaw/openclaw:latest` (arm64)
- **Zugriff:** Telegram Bot + HTTP Gateway
- **Daten:** `~/infra/openclaw-data/`
- **Action-Log (append-only):** `~/infra/openclaw-data/action-log.jsonl` mit Feldern `{ts, skill, action, result, triggered_by}`
- **Workspace:** `~/agent/` (SOUL.md, USER.md, TOOLS.md, HEARTBEAT.md)
- **Growbox-Steuerung:** via HA REST API (`HA_TOKEN` in `.env`)
- **Secrets:** `ANTHROPIC_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `OPENCLAW_GATEWAY_TOKEN`, `HA_TOKEN` in `.env`
- **`OPENCLAW_NO_RESPAWN=1`:** Absichtlich gesetzt. OpenClaw hat eine eigene Supervisor-Erkennung (systemd/launchd/Windows) — Docker wird nicht erkannt. Ohne diese Variable forkt OpenClaw bei Reload-Events einen detached Child-Prozess → Port-Konflikt auf 18789. Die Variable deaktiviert das, Docker's `restart: unless-stopped` übernimmt. Nicht entfernen.

## RAG Ops Jobs (systemd)

- **Zweck:** Qualitaets- und Datenaktualitaets-Jobs fuer den OpenClaw-RAG-Stack ausserhalb von Docker orchestrieren
- **Units im Repo:** `systemd/rag-quality-report.service`, `systemd/rag-quality-report.timer`, `systemd/rag-reindex-daily.service`, `systemd/rag-reindex-daily.timer`
- **Weekly Quality Report:** Samstag 10:00 (persistenter Timer mit Jitter)
- **Daily Reindex:** taeglich 04:30 (Europe/Berlin) mit `RandomizedDelaySec=10min`
- **Ausfuehrung:** Service laeuft als User `steges` und ruft `~/agent/skills/openclaw-rag/scripts/reindex.sh` auf
- **Sicherheitsnetz:** Reindex beinhaltet Snapshot-Strategie, Integritaetscheck und verpflichtenden Post-Reindex-Canary-Gate

## Compose Runtime-Leitplanken

- **CPU-Caps:** Alle Compose-Services haben explizite `cpus`-Grenzen, um CPU-Starvation auf dem Pi zu vermeiden.
- **Logrotation:** Standardmaessig `json-file` mit `10m` und `3` Dateien; service-spezifische engere Limits bleiben erlaubt.
- **Ziel:** Lastspitzen einzelner Container sollen nicht DNS, Proxy, Monitoring oder OpenClaw mitreissen.

## Skill-Manager (im OpenClaw Workspace)

- **Zweck:** Zero-Trust Skill-Lifecycle und Artifact-Writer fuer den Agent-Workspace
- **Typ:** Workspace-Komponente (kein separater Docker-Service)
- **Root:** `~/agent/skills/skill-forge/`
- **Wrapper:** `~/scripts/skill-forge`
- **State:** `~/agent/skills/skill-forge/.state/`

Kernfunktionen:
- Scout / Vetting / Quarantaene-Blacklist
- Authoring neuer Skills (template/from-tested/scratch/auto)
- Canary-Promotion und Rollback-State
- Writer-Module (`docs`, `code`, `config`, `test`)
- Governance (`policy lint`, `incident freeze`, `audit`, `budget`, `health`)

Wichtige Befehle:
```bash
~/scripts/skill-forge status
~/scripts/skill-forge heartbeat
~/scripts/skill-forge policy lint
~/scripts/skill-forge audit --rejected
~/scripts/skill-forge budget
```
