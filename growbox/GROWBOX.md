# GROWBOX.md – Agent-Referenz

## System-Übersicht

```
ESP32 (growbox_wlan.yaml)
  DHT22 (GPIO4)    → Temperatur, Luftfeuchtigkeit
  4× PWM-Lüfter   → GPIO25/26/27/32 (25 kHz LEDC)
  4× Relais        → GPIO16/17/18/19 (Elegoo 8-Kanal, Active-LOW)
  4× Tacho         → GPIO34/35/36/39 (input-only)
      ↓ ESPHome native API + MQTT
Home Assistant (http://192.168.2.101:8123)
      ↓ REST API
Agent (dieser Container)
```

## HA Entity-IDs (nach erstem Flash prüfen in: HA → Developer Tools → States)

| Entity                              | Typ     | Beschreibung                    |
|-------------------------------------|---------|---------------------------------|
| `sensor.growbox_temperatur`         | sensor  | DHT22 Temperatur (°C)           |
| `sensor.growbox_luftfeuchtigkeit`   | sensor  | DHT22 Luftfeuchtigkeit (%)      |
| `sensor.growbox_lufeter_0_rpm`      | sensor  | Lüfter 0 Drehzahl (RPM)         |
| `sensor.growbox_lufeter_1_rpm`      | sensor  | Lüfter 1 Drehzahl (RPM)         |
| `sensor.growbox_lufeter_2_rpm`      | sensor  | Lüfter 2 Drehzahl (RPM)         |
| `sensor.growbox_lufeter_3_rpm`      | sensor  | Lüfter 3 Drehzahl (RPM)         |
| `fan.growbox_lufeter_0`             | fan     | Lüfter 0 (speed 0–100)          |
| `fan.growbox_lufeter_1`             | fan     | Lüfter 1 (speed 0–100)          |
| `fan.growbox_lufeter_2`             | fan     | Lüfter 2 (speed 0–100)          |
| `fan.growbox_lufeter_3`             | fan     | Lüfter 3 (speed 0–100)          |
| `select.growbox_betriebsmodus`      | select  | Manuell / Auto (Temperatur) / Nacht |
| `number.growbox_alle_lufeter_master`| number  | Master-Speed 0–100 (Manuell)    |
| `text_sensor.growbox_status`        | sensor  | Status-Text                     |
| `button.growbox_neustart`           | button  | ESP32 neu starten               |

## HA REST API

**Base URL:** `http://192.168.2.101:8123`
**Header:** `Authorization: Bearer {HA_TOKEN aus .env}`

### Sensor lesen
```bash
GET /api/states/{entity_id}
# Beispiel:
curl -H "Authorization: Bearer $HA_TOKEN" \
     http://192.168.2.101:8123/api/states/sensor.growbox_temperatur
```

### Lüfter steuern (fan.set_percentage)
```bash
POST /api/services/fan/set_percentage
Body: {"entity_id": "fan.growbox_lufeter_0", "percentage": 60}
```

### Betriebsmodus umschalten
```bash
POST /api/services/select/select_option
Body: {"entity_id": "select.growbox_betriebsmodus", "option": "Nacht"}
# Optionen: "Manuell" | "Auto (Temperatur)" | "Nacht"
```

### Master-Speed setzen (nur im Manuell-Modus)
```bash
POST /api/services/number/set_value
Body: {"entity_id": "number.growbox_alle_lufeter_master", "value": 75}
```

### Alle States auf einmal (Übersicht)
```bash
GET /api/states
# Dann nach "growbox" filtern
```

## Zielwerte & Alarme
→ `/home/steges/growbox/THRESHOLDS.md`

## Aktueller Grow
→ `/home/steges/growbox/GROW.md`

## Tagebuch
→ `/home/steges/growbox/diary/YYYY-MM-DD.md`

### Tagebuch-Format
```markdown
# Grow-Log YYYY-MM-DD

## Messwerte
- Temperatur: XX °C
- Luftfeuchtigkeit: XX %
- Betriebsmodus: Manuell / Auto / Nacht

## Aktionen
- [Was wurde getan]

## Beobachtungen
- [Was ist aufgefallen]
```

## Hinweise
- MQTT läuft auf Port 1883 (kein Broker im Stack → nur HA native API nutzen)
- ESP32 Web UI direkt: http://growbox.local oder IP des ESP32
- OTA-Flash über ESPHome UI: http://192.168.2.101:6052
