# Home Assistant Smart Home

> Central smart home automation platform
> Integrations, automations, dashboards, ESPHome

---

## Overview

**Home Assistant** is the central hub for all smart home devices and automations.

| Attribute | Value |
|-----------|-------|
| **Image** | `ghcr.io/home-assistant/home-assistant:2026.4.1` |
| **Container** | homeassistant |
| **Port** | `8123` (Host mode) |
| **LAN URL** | `http://homeassistant.lan:8123` |
| **Config** | `./homeassistant/config/` |
| **Database** | SQLite + InfluxDB (optional) |

---

## Architecture

```
┌─────────────────┐
│  Home Assistant │
│     :8123       │
└────────┬────────┘
         │
    ┌────┴────┬─────────┬──────────┬─────────┐
    ↓         ↓         ↓          ↓         ↓
 ESPHome   MQTT     Pi-hole    InfluxDB   Grafana
(ESP32)  (Broker)   (DNS)     (Metrics)  (Dashboard)
    ↑         ↑
Growbox   Sensors
Sensors   (Tasmota, etc.)
```

---

## Configuration

### Docker Compose

```yaml
services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:2026.4.1
    container_name: homeassistant
    network_mode: host
    env_file: .env
    volumes:
      - ./homeassistant/config:/config
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:8123"]
      interval: 60s
      timeout: 10s
      retries: 3
      start_period: 120s
    mem_limit: 800m
    cpus: '1.50'
    restart: unless-stopped
```

### Caddyfile

```caddyfile
homeassistant.lan, hass.lan {
    reverse_proxy 192.168.2.101:8123
}
```

---

## Core Configuration

### configuration.yaml

```yaml
# homeassistant/config/configuration.yaml

default_config:

homeassistant:
  name: PiLab
  latitude: !secret latitude
  longitude: !secret longitude
  elevation: !secret elevation
  unit_system: metric
  time_zone: Europe/Berlin
  external_url: "http://homeassistant.lan:8123"
  internal_url: "http://192.168.2.101:8123"

# Enable APIs
api:

# Prometheus metrics export
prometheus:
  namespace: hass

# InfluxDB integration
influxdb:
  host: 192.168.2.101
  port: 8086
  token: !secret influxdb_token
  organization: pilab
  bucket: homeassistant
  ssl: false
  verify_ssl: false
  include:
    domains:
      - sensor
      - binary_sensor
      - switch

# Recorder (SQLite)
recorder:
  db_url: sqlite:////config/home-assistant_v2.db
  purge_keep_days: 7
  commit_interval: 5

# Logbook
logbook:

# History
history:
  include:
    domains:
      - sensor
      - binary_sensor
      - switch
      - light

# MQTT
mqtt:
  broker: 192.168.2.101
  port: 1883
  username: homeassistant
  password: !secret mqtt_password
  discovery: true
  discovery_prefix: homeassistant

# ESPHome
esphome:
  dashboard_import:
    package_import_url: github://esphome/esphome

# Zones
zone:
  - name: Home
    latitude: !secret latitude
    longitude: !secret longitude
    radius: 100
    icon: mdi:home

# Includes
group: !include groups.yaml
automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml
sensor: !include sensors.yaml
binary_sensor: !include binary_sensors.yaml
switch: !include switches.yaml
```

---

## Growbox Integration

### sensors.yaml

```yaml
# Growbox SHT30 sensor (via ESPHome API or MQTT)
- platform: mqtt
  name: "Growbox Temperature"
  state_topic: "growbox/sensors/temperature"
  unit_of_measurement: "°C"
  device_class: temperature
  value_template: "{{ value | float | round(1) }}"

- platform: mqtt
  name: "Growbox Humidity"
  state_topic: "growbox/sensors/humidity"
  unit_of_measurement: "%"
  device_class: humidity
  value_template: "{{ value | float | round(1) }}"

# SCD40 CO2 sensor
- platform: mqtt
  name: "Growbox CO2"
  state_topic: "growbox/sensors/co2"
  unit_of_measurement: "ppm"
  device_class: carbon_dioxide

# VPD (Vapor Pressure Deficit) - calculated
- platform: template
  sensors:
    growbox_vpd:
      friendly_name: "Growbox VPD"
      unit_of_measurement: "kPa"
      value_template: >
        {% set t = states('sensor.growbox_temperature') | float %}
        {% set rh = states('sensor.growbox_humidity') | float %}
        {% set es = 0.6108 * e ** (17.27 * t / (t + 237.3)) %}
        {% set ea = es * rh / 100 %}
        {{ (es - ea) | round(2) }}
```

### binary_sensors.yaml

```yaml
- platform: mqtt
  name: "Growbox Light Status"
  state_topic: "growbox/status/light"
  payload_on: "ON"
  payload_off: "OFF"
  device_class: light
```

### switches.yaml

```yaml
- platform: mqtt
  name: "Growbox Light"
  command_topic: "growbox/controls/light/set"
  state_topic: "growbox/controls/light/state"
  payload_on: "ON"
  payload_off: "OFF"

- platform: mqtt
  name: "Growbox Fan"
  command_topic: "growbox/controls/fan/set"
  state_topic: "growbox/controls/fan/state"
```

---

## Automations

### automations.yaml

```yaml
# Growbox Climate Control
- alias: "Growbox: Fan On High Temp"
  trigger:
    - platform: numeric_state
      entity_id: sensor.growbox_temperature
      above: 28
  action:
    - service: switch.turn_on
      target:
        entity_id: switch.growbox_fan
    - service: notify.ntfy
      data:
        message: "🌡️ Growbox hot: {{ trigger.to_state.state }}°C"

- alias: "Growbox: Light Schedule"
  trigger:
    - platform: time
      at: "06:00:00"
    - platform: time
      at: "22:00:00"
  action:
    - choose:
        - conditions: "{{ trigger.now.hour == 6 }}"
          sequence:
            - service: switch.turn_on
              target:
                entity_id: switch.growbox_light
        - conditions: "{{ trigger.now.hour == 22 }}"
          sequence:
            - service: switch.turn_off
              target:
                entity_id: switch.growbox_light

# Low Humidity Alert
- alias: "Growbox: Low Humidity Alert"
  trigger:
    - platform: numeric_state
      entity_id: sensor.growbox_humidity
      below: 40
      for: "00:05:00"
  action:
    - service: notify.ntfy
      data:
        message: "💧 Growbox humidity low: {{ trigger.to_state.state }}%"
```

---

## Dashboards

### Overview Dashboard

```yaml
title: PiLab Overview
views:
  - title: Home
    cards:
      # Growbox
      - type: entities
        title: Growbox
        entities:
          - sensor.growbox_temperature
          - sensor.growbox_humidity
          - sensor.growbox_co2
          - sensor.growbox_vpd
          - switch.growbox_light
          - switch.growbox_fan
        
      # System
      - type: glance
        title: System
        entities:
          - sensor.processor_temperature
          - sensor.disk_use_percent
          - sensor.memory_use_percent
          
      # Quick Actions
      - type: button
        name: Restart Pi-hole
        tap_action:
          action: call-service
          service: switch.turn_off
          target:
            entity_id: switch.pihole
```

### Growbox Dashboard

```yaml
views:
  - title: Growbox
    cards:
      - type: history-graph
        entities:
          - sensor.growbox_temperature
          - sensor.growbox_humidity
        hours_to_show: 24
        
      - type: gauge
        entity: sensor.growbox_temperature
        min: 15
        max: 35
        segments:
          - from: 15
            color: "#3498db"
          - from: 20
            color: "#2ecc71"
          - from: 28
            color: "#f39c12"
          - from: 32
            color: "#e74c3c"
            
      - type: entity-button
        entity: switch.growbox_light
        hold_action:
          action: more-info
```

---

## Integrations

### ESPHome

```
Settings → Devices & Services → ESPHome
→ Add Integration → ESPHome
→ Host: 192.168.2.101 (or device IP)
```

### MQTT

```yaml
# Already configured in configuration.yaml
# Auto-discovery enabled for:
# - sensor.*
# - binary_sensor.*
# - switch.*
```

### Pi-hole

```yaml
# configuration.yaml
sensor:
  - platform: pi_hole
    host: 192.168.2.101
    port: 8080
    location: admin
    ssl: false
    monitored_conditions:
      - ads_blocked_today
      - ads_percentage_today
      - dns_queries_today
```

### Tailscale

```yaml
# device_tracker via ping or tailscale status
binary_sensor:
  - platform: ping
    host: 100.x.x.x  # Tailscale IP
    name: "Phone Online"
```

---

## Notifications

### ntfy

```yaml
# configuration.yaml
notify:
  - platform: rest
    name: ntfy
    resource: http://192.168.2.101:8900/homeassistant
    method: POST

# Usage in automations
- service: notify.ntfy
  data:
    message: "Alert message here"
    title: "Home Assistant"
    priority: high
```

---

## Backup

### Snapshot

```
Settings → System → Backups → Create Backup
→ Download .tar file
```

### Automated

```yaml
# automation
- alias: "Daily Backup"
  trigger:
    platform: time
    at: "03:00:00"
  action:
    - service: hassio.snapshot_full
      data:
        name: "Daily {{ now().strftime('%Y-%m-%d') }}"
```

### USB Backup

```bash
./homeassistant/config/ → /mnt/usb-backup/backups/YYYYMMDD/homeassistant/
```

---

## Troubleshooting

### "Unable to connect"

```bash
# Check container
docker ps | grep homeassistant

# Check logs
docker logs homeassistant --tail 100

# Config validation
docker exec homeassistant hass --script check_config
```

### High CPU/Memory

```bash
# Check integrations
docker exec homeassistant ha info

# Disable problematic integrations
# configuration.yaml:
# logger:
#   default: warning
#   logs:
#     homeassistant.components.slow: debug
```

### Database corruption

```bash
# Stop HA
docker compose stop homeassistant

# Backup corrupt DB
cp ./homeassistant/config/home-assistant_v2.db ./homeassistant/config/home-assistant_v2.db.corrupt

# Delete and restart (new DB created)
rm ./homeassistant/config/home-assistant_v2.db

# Restore from backup
```

### ESPHome devices offline

```bash
# Check ESPHome dashboard
curl http://192.168.2.101:6052

# Ping device
ping growbox-sensor.local

# Re-flash if needed via USB
```

---

## API

```bash
# States
curl -H "Authorization: Bearer TOKEN" \
  http://192.168.2.101:8123/api/states

# Call service
curl -X POST \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"entity_id": "switch.growbox_light"}' \
  http://192.168.2.101:8123/api/services/switch/turn_on

# History
curl -H "Authorization: Bearer TOKEN" \
  "http://192.168.2.101:8123/api/history/period/2026-04-10?filter_entity_id=sensor.growbox_temperature"
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Documentation created, HA 2026.4.1 |
