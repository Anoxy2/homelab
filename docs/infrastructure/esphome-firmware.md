# ESPhome Firmware Management

> ESP32/ESP8266 Firmware-Updates und Konfiguration
> OTA-Updates, Device-Templates, Integration mit Home Assistant

---

## Überblick

**ESPhome** compiliert und flasht Firmware für ESP-Mikrocontroller – vollständig YAML-basiert, integriert mit Home Assistant.

| Attribut | Wert |
|----------|------|
| **Image** | `ghcr.io/esphome/esphome:2026.3.2` |
| **Container** | esphome |
| **Port** | `6052` (Host mode) |
| **LAN URL** | `http://esphome.lan` / `http://192.168.2.101:6052` |
| **Config** | `./esphome/config/` |
| **Devices** | Growbox-Sensoren, Steuerungen |

---

## Architektur

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  ESPhome    │────→│   ESP32     │────→│  Sensoren   │
│  Dashboard  │     │  (WiFi)     │     │  (I2C/1Wire)│
└─────────────┘     └─────────────┘     └─────────────┘
        │
        ↓
┌─────────────┐
│ Home Assistant│ ←── API-Integration
│  (API/HA)   │
└─────────────┘
```

---

## Konfiguration

### Docker Compose

```yaml
services:
  esphome:
    image: ghcr.io/esphome/esphome:2026.3.2
    container_name: esphome
    network_mode: host
    volumes:
      - ./esphome/config:/config
    # Privileged für USB-Serial-Flashing
    privileged: true
```

### Caddyfile

```caddyfile
esphome.lan {
    reverse_proxy 192.168.2.101:6052
}
```

---

## Device-Konfigurationen

### Growbox Sensor (SHT30 + SCD40)

**Datei:** `esphome/config/growbox-sensor.yaml`

```yaml
esphome:
  name: growbox-sensor
  friendly_name: Growbox Sensor

esp32:
  board: esp32dev
  framework:
    type: arduino

# WiFi
wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
  ap:
    ssid: "Growbox Fallback"
    password: !secret ap_password

captive_portal:

# Home Assistant API
api:
  encryption:
    key: !secret api_encryption_key

ota:
  - platform: esphome
    password: !secret ota_password

# Logging
logger:
  level: INFO

# I2C Bus
i2c:
  sda: GPIO21
  scl: GPIO22
  scan: true
  id: bus_a

# Sensoren
sensor:
  # SHT30 - Temperatur & Luftfeuchtigkeit
  - platform: sht3xd
    temperature:
      name: "Growbox Temperature"
      id: gb_temp
      unit_of_measurement: "°C"
      accuracy_decimals: 1
    humidity:
      name: "Growbox Humidity"
      id: gb_humidity
      unit_of_measurement: "%"
      accuracy_decimals: 1
    address: 0x44
    update_interval: 30s

  # SCD40 - CO2, Temp, Humidity
  - platform: scd4x
    co2:
      name: "Growbox CO2"
      id: gb_co2
      unit_of_measurement: "ppm"
      accuracy_decimals: 0
    temperature:
      name: "Growbox CO2 Temp"
      id: gb_co2_temp
    humidity:
      name: "Growbox CO2 Humidity"
      id: gb_co2_humidity
    address: 0x62
    update_interval: 60s

# Text Sensor für Status
text_sensor:
  - platform: template
    name: "Growbox Status"
    lambda: |-
      if (id(gb_temp).state > 30) {
        return {"HOT"};
      } else if (id(gb_humidity).state > 70) {
        return {"HUMID"};
      }
      return {"OK"};
    update_interval: 30s
```

### Growbox Control (Relais, Lüfter, PWM)

**Datei:** `esphome/config/growbox-control.yaml`

```yaml
esphome:
  name: growbox-control
  friendly_name: Growbox Control

esp32:
  board: esp32dev
  framework:
    type: arduino

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password

api:
  encryption:
    key: !secret api_encryption_key

ota:
  - platform: esphome
    password: !secret ota_password

logger:

# Ausgänge
output:
  # PWM für Lüfter
  - platform: ledc
    pin: GPIO25
    id: fan_pwm
    frequency: 25000Hz

  # Relais für Licht
  - platform: gpio
    pin: GPIO26
    id: light_relay
    inverted: false

# Lüfter als Fan-Entity
fan:
  - platform: speed
    output: fan_pwm
    name: "Growbox Fan"
    id: gb_fan
    speed_count: 4

# Licht als Switch
switch:
  - platform: output
    name: "Growbox Light"
    output: light_relay
    id: gb_light

# Dimm-Bereitschaft (optional)
light:
  - platform: monochromatic
    output: fan_pwm
    name: "Growbox LED"
    id: gb_led
```

---

## Secrets

**Datei:** `esphome/config/secrets.yaml`

```yaml
wifi_ssid: "DeinWLAN"
wifi_password: "DeinPasswort"

ap_password: "Fallback123"

api_encryption_key: "base64encodedkey=="
ota_password: "otaSecurePassword"
```

**Key generieren:**
```bash
openssl rand -base64 32
```

---

## Workflow

### 1. Erst-Flashing (USB)

```bash
# ESPhome Container starten
docker compose up -d esphome

# Device anschließen via USB
ls /dev/ttyUSB*

# Im ESPhome Dashboard:
# → Device auswählen
# → "Install" → "Plug into the computer running ESPHome"
```

### 2. OTA-Updates

```bash
# Dashboard öffnen
open http://esphome.lan

# Device → "Install" → "Wirelessly"
# Oder via Home Assistant:
# Settings → Devices → ESPHome → Update
```

### 3. Logs ansehen

```bash
# Via Dashboard → "Logs"
# Oder MQTT-Logs in Home Assistant
```

---

## Integration mit Home Assistant

### Automatisch

ESPhome-Geräte erscheinen automatisch in HA unter:
`Settings → Devices & Services → ESPHome`

### Manuelle Entities

```yaml
# configuration.yaml (falls nötig)
sensor:
  - platform: template
    sensors:
      growbox_vpd:
        friendly_name: "Growbox VPD"
        unit_of_measurement: "kPa"
        value_template: >
          {% set t = states('sensor.growbox_temperature') | float %}
          {% set rh = states('sensor.growbox_humidity') | float %}
          {{ (610.78 * 10**((7.5 * t)/(237.3 + t)) * (1 - rh/100) / 1000) | round(2) }}
```

---

## Troubleshooting

### "No such file or directory: /dev/ttyUSB0"

```bash
# Rechte prüfen
ls -la /dev/ttyUSB*

# User zur dialout-Gruppe hinzufügen
sudo usermod -aG dialout steges

# Re-login oder:
newgrp dialout
```

### OTA schlägt fehl

```bash
# Device erreichbar?
ping growbox-sensor.local

# Logs prüfen
esphome logs esphome/config/growbox-sensor.yaml

# Factory-Reset (nur bei komplettem Brick)
# → USB-Flashing erforderlich
```

### WiFi-Verbindungsprobleme

```yaml
# Fallback-AP aktivieren
wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
  ap:
    ssid: "Growbox Fallback"
    password: !secret ap_password

# Oder statische IP
wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
  manual_ip:
    static_ip: 192.168.2.150
    gateway: 192.168.2.1
    subnet: 255.255.255.0
    dns1: 192.168.2.101  # Pi-hole
```

### API-Verbindung zu HA verloren

```bash
# HA Neustart
# ESPhome Device neustarten
# → Im Dashboard: "Restart"

# Oder API-Key neu generieren
```

---

## Backup

```bash
# Configs sind im Git-Repo
./esphome/config/ → automatisch versioniert

# USB-Backup sichert zusätzlich:
./esphome/config/ → /mnt/usb-backup/backups/YYYYMMDD/esphome/
```

---

## Templates & Snippets

### I2C-Scanner

```yaml
# Debug: Welche I2C-Adressen belegt?
i2c:
  sda: GPIO21
  scl: GPIO22
  scan: true
```

### Deep Sleep (Batterie-Sensoren)

```yaml
deep_sleep:
  run_duration: 30s
  sleep_duration: 5min
```

### Status-LED

```yaml
status_led:
  pin:
    number: GPIO2
    inverted: true
```

---

## Changelog

| Datum | Änderung |
|-------|----------|
| 2026-04-10 | Dokumentation erstellt, ESPhome 2026.3.2 |
