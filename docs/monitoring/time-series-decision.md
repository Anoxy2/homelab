# Entscheidung: Sensor-History fuer Canvas

## Kontext

Fuer Growbox-Charts standen zwei Optionen im Backlog:
- Option A: InfluxDB 2 + HA Integration (+ optional Grafana)
- Option B: Home Assistant History API direkt

## Entscheidung

Ab jetzt wird **Option A (InfluxDB 2 + HA Integration + Grafana)** produktiv genutzt.

## Begruendung

- bessere Langzeit-Performance fuer Zeitreihenabfragen als HA-SQLite
- saubere Trennung: Home Assistant fuer Steuerung, InfluxDB fuer Historie
- Grafana bietet deutlich bessere Trends, Vergleichszeiträume und Dashboards
- arm64-kompatibel und mit dem bestehenden Docker-Stack auf Pi 5 stabil betreibbar

## Aktueller Rollout-Stand

- `influxdb:2.7.12` als eigener Compose-Service auf `192.168.2.101:8086`
- persistente Datenpfade: `~/influxdb/data` und `~/influxdb/config`
- Reverse-Proxy-Route: `http://influx.lan`
- Backup erweitert: `influxdb-data.tar.gz` plus Restic-Source `~/influxdb/data`

## Umsetzungsstand (abgeschlossen)

- Home-Assistant InfluxDB-Integration aktiv in `homeassistant/config/configuration.yaml` (InfluxDB v2, Measurement `state`)
- Persistenznachweis erfolgt: Influx-Query liefert HA-Zeilen aus Bucket `homeassistant`
- Grafana-Data-Source `InfluxDB-HA` provisioniert (`grafana/provisioning/datasources/datasources.yml`)
- Kern-Dashboards provisioniert:
  - `grafana/dashboards/growbox-overview.json`
  - `grafana/dashboards/infrastructure-overview.json`
- Baseline gemessen und dokumentiert:
  - `docs/monitoring/time-series-baseline.md`
  - Rohdaten: `infra/openclaw-data/time-series-baseline.json`
- Retention/Downsampling festgezogen:
  - Bucket `homeassistant`: `2160h` (90 Tage)
  - Bucket `homeassistant_rollup`: `8760h` (365 Tage)
  - Task `ha_downsample_5m_hourly` aktiv

## Bewertung weiterer DB-Migrationen

Ist-Bestand (relevante Datenbanken):
- `homeassistant/config/home-assistant_v2.db` (HA Recorder / SQLite)
- `pihole/config/pihole-FTL.db` und `pihole/config/gravity.db` (Pi-hole intern)
- `mosquitto/data/mosquitto.db` (MQTT Persistenz intern)
- `infra/openclaw-data/rag/index.db` (RAG SQLite FTS/vec)
- `influxdb/data/influxd.sqlite` (InfluxDB interne Metadaten, kein Migrationsziel)
- `infra/openclaw-data/memory/main.sqlite` und `infra/openclaw-data/tasks/runs.sqlite` (OpenClaw intern)

Migrationsentscheidung:
- **Ja, fachlich gewollt:** HA Sensor-Historie/Trenddaten in InfluxDB schreiben (parallel zu HA Recorder, kein harter Recorder-Cutover im ersten Schritt).
- **Nein:** Pi-hole DBs bleiben unveraendert (anwendungsintern, migrationskritisch, kein Influx-Use-Case).
- **Nein:** Mosquitto Persistenz bleibt wie ist (Message-Persistenz statt analytische Zeitreihe).
- **Nein:** RAG `index.db` bleibt SQLite (FTS/vec-Backend und Snapshot/Restore bereits darauf ausgelegt).
- **Nein:** OpenClaw interne SQLite-Dateien bleiben lokal (State/Task-Store, kein Zeitreihen-Benefit).
- **Nein:** Prometheus bleibt fuer Host-/Infra-Metriken, nicht als Ersatz fuer den RAG- oder Skill-State-Store.

Kurzfazit:
- Es soll **nur** die Sensor-Historie aus Home Assistant in InfluxDB ausgebaut werden.
- Alle anderen vorhandenen Datenbanken bleiben auf ihrem nativen Store, weil Zweck und Datenmodell nicht zu InfluxDB passen.
