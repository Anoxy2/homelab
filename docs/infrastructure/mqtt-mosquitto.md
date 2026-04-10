# MQTT / Mosquitto Broker

> Zentraler Message-Broker für Home Automation
> ESP32-Sensoren, Home Assistant, OpenClaw

---

## Überblick

**Mosquitto** ist der MQTT-Broker für alle IoT-Kommunikation im Homelab.

| Attribut | Wert |
|----------|------|
| **Image** | `eclipse-mosquitto:2` |
| **Container** | mosquitto |
| **Port** | `1883` (Host mode) |
| **Config** | `./mosquitto/config/` |
| **Daten** | `./mosquitto/data/` |

---

## Architektur

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   ESP32     │────→│             │────→│  Home       │
│  (Sensor)   │────→│  Mosquitto  │────→│  Assistant  │
└─────────────┘     │   Broker    │     └─────────────┘
┌─────────────┐     │   :1883     │     ┌─────────────┐
│  OpenClaw   │────→│             │────→│  OpenClaw   │
│  (Publisher)│     └─────────────┘     │  (Subscriber)│
└─────────────┘                         └─────────────┘

Topics:
- growbox/sensors/temperature
- growbox/sensors/humidity
- home/status
- openclaw/events
```

---

## Konfiguration

### Docker Compose

```yaml
services:
  mosquitto:
    image: eclipse-mosquitto:2
    container_name: mosquitto
    network_mode: host
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - ./mosquitto/data:/mosquitto/data
      - ./mosquitto/log:/mosquitto/log
```

### mosquitto.conf

```
# mosquitto/config/mosquitto.conf

# Netzwerk
listener 1883
allow_anonymous false

# Persistenz
persistence true
persistence_location /mosquitto/data/
autosave_interval 300

# Logging
log_dest file /mosquitto/log/mosquitto.log
log_dest stdout
log_type error
log_type warning
log_type information
connection_messages true

# Authentifizierung
password_file /mosquitto/config/passwd
acl_file /mosquitto/config/acl

# Limits
max_connections 100
max_queued_messages 1000
max_inflight_messages 20

# Websocket (optional)
# listener 9001
# protocol websockets
```

### Authentifizierung

**passwd-Datei erstellen:**

```bash
# Container-Exec
docker exec mosquitto mosquitto_passwd -c /mosquitto/config/passwd homeassistant
# Passwort eingeben

docker exec mosquitto mosquitto_passwd /mosquitto/config/passwd openclaw
docker exec mosquitto mosquitto_passwd /mosquitto/config/passwd esphome
```

**acl-Datei (Zugriffssteuerung):**

```
# mosquitto/config/acl

# Home Assistant: Lesen & Schreiben
user homeassistant
topic readwrite #

# OpenClaw: Lesen & Schreiben
user openclaw
topic readwrite #

# ESPhome: Nur publish
user esphome
topic read growbox/+
topic write growbox/+
```

---

## Topic-Struktur

```
growbox/
├── sensors/
│   ├── temperature
│   ├── humidity
│   ├── co2
│   └── vpd
├── controls/
│   ├── fan
│   ├── light
│   └── exhaust
└── status
    └── online

home/
├── status
├── devices/
│   └── livingroom/
└── automation/
    └── triggers

openclaw/
├── events
├── status
└── commands
```

---

## Verwendung

### CLI-Test

```bash
# Subscriber (lesen)
mosquitto_sub -h 192.168.2.101 -t "growbox/sensors/temperature" -u homeassistant -P passwort

# Publisher (senden)
mosquitto_pub -h 192.168.2.101 -t "growbox/sensors/temperature" -m "24.5" -u esphome -P passwort

# Retained message
mosquitto_pub -h 192.168.2.101 -t "home/status" -m "online" -r -u openclaw -P passwort
```

### Home Assistant Integration

```yaml
# configuration.yaml
mqtt:
  broker: 192.168.2.101
  port: 1883
  username: homeassistant
  password: !secret mqtt_password

# Sensoren aus MQTT
sensor:
  - platform: mqtt
    name: "Growbox Temperature"
    state_topic: "growbox/sensors/temperature"
    unit_of_measurement: "°C"
    device_class: temperature

  - platform: mqtt
    name: "Growbox Humidity"
    state_topic: "growbox/sensors/humidity"
    unit_of_measurement: "%"
    device_class: humidity
```

### OpenClaw Integration

```bash
# Status publishen
mosquitto_pub -h 192.168.2.101 -t "openclaw/status" -m "online" -r

# Events senden
mosquitto_pub -h 192.168.2.101 -t "openclaw/events" -m '{"type":"backup","status":"success"}'
```

### ESPhome Integration

```yaml
# In device-config.yaml
mqtt:
  broker: 192.168.2.101
  username: esphome
  password: !secret mqtt_password
  topic_prefix: growbox

# Auto-discovery für HA
api:
  # Oder native API bevorzugen
```

---

## Monitoring

### Aktive Verbindungen

```bash
# Mosquitto-Stats
docker exec mosquitto mosquitto_sub -t '$SYS/#' -v

# Oder netstat
sudo netstat -tlnp | grep 1883
```

### Logs

```bash
# Echtzeit
docker logs mosquitto -f

# Filter
docker logs mosquitto 2>&1 | grep "New connection"
```

---

## Troubleshooting

### "Connection refused"

```bash
# Container läuft?
docker ps | grep mosquitto

# Port erreichbar?
nc -zv 192.168.2.101 1883

# Config-Test
docker exec mosquitto mosquitto -c /mosquitto/config/mosquitto.conf -t
```

### "Authentication failed"

```bash
# Passwort-Datei prüfen
cat ./mosquitto/config/passwd

# ACL prüfen
cat ./mosquitto/config/acl

# Rechte
docker exec mosquitto ls -la /mosquitto/config/
```

### Hohe CPU/RAM

```bash
# Verbindungen prüfen
docker exec mosquitto mosquitto_sub -t '$SYS/broker/clients/connected' -v

# Queue-Limit prüfen
docker exec mosquitto mosquitto_sub -t '$SYS/broker/messages/stored' -v
```

### Messages kommen nicht an

```bash
# Subscription-Test mit Debug
docker exec mosquitto mosquitto_sub -t '#' -v -d 2>&1 | head -20
```

---

## Backup

```bash
# Config + Daten
./mosquitto/ → /mnt/usb-backup/backups/YYYYMMDD/mosquitto/

# Passwörter separat sichern (nicht im Git!)
cp ./mosquitto/config/passwd /secure/location/
```

---

## Security Hardening

```
# Nur TLS (Port 8883)
listener 8883
cafile /mosquitto/config/ca.crt
certfile /mosquitto/config/server.crt
keyfile /mosquitto/config/server.key

# Oder mTLS (Client-Zertifikate)
require_certificate true
use_identity_as_username true
```

**Hinweis:** Im LAN ist unverschlüsseltes MQTT akzeptabel, für Tailscale-Remote-Zugriff empfohlen.

---

## Changelog

| Datum | Änderung |
|-------|----------|
| 2026-04-10 | Dokumentation erstellt, Mosquitto 2.x |
