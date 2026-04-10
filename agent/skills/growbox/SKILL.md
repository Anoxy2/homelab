---
name: growbox
description: Growbox-Betrieb. Täglicher Diary-Eintrag, Tagesbericht via Telegram, Sensor-Snapshots aus Home Assistant. Deterministisch, kein LLM-Aufruf.
---

# growbox

## Zweck

Verwaltet den automatisierten Growbox-Betrieb: tägliche Diary-Einträge anlegen, Tagesbericht per Telegram senden, Zeitfenster-Checks für periodische Aktionen.

## Wann nutzen

```bash
~/scripts/skills growbox diary              # Diary-Eintrag für heute anlegen (idempotent)
~/scripts/skills growbox daily-report       # Tagesbericht via Telegram senden
~/scripts/skills growbox should-report      # Gibt "1" wenn Bericht fällig, sonst "0"
~/scripts/skills growbox mark-sent          # Bericht als gesendet markieren
~/scripts/skills growbox status             # Aktueller Sensor-Snapshot (kein Telegram)
```

## Growbox-Daten

- Diary: `/home/steges/growbox/diary/DD.MM.YYYY.md`
- Referenz-Entities: `/home/steges/growbox/GROWBOX.md`
- Aktueller Grow: `/home/steges/growbox/GROW.md`
- Schwellwerte: `/home/steges/growbox/THRESHOLDS.md`
- Report-State: `skill-forge/.state/growbox-report-state.json`

## Abhängigkeiten

| Ressource | Zweck |
|-----------|-------|
| HA REST API (`HA_TOKEN`, `HA_BASE_URL`) | Sensor-Daten lesen |
| Telegram (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`) | Berichte senden |
| `action-log.jsonl` | 24h-Alarm-Kontext lesen |

## Scope-Grenzen

| Erlaubt | Verboten |
|---------|----------|
| Diary-Einträge schreiben | HA-Automationen steuern |
| Telegram-Nachrichten senden | Relais / Aktoren schalten |
| HA-States lesen (read-only) | Schreiben in andere Skill-States |

## ESP32 / ESPHome Referenz (Growbox-relevant)

### GPIO-Fallen (kritisch)
- **GPIO 6-11**: VERBOTEN — intern mit Flash verbunden, sofortiger Crash
- **GPIO 34-39**: Input-Only — kein Output, kein Pullup/Pulldown möglich
  → Growbox nutzt GPIO 34/35/36/39 korrekt als Tacho-Input
- **ADC2** (GPIO 0,2,4,12-15,25-27): Nicht nutzbar wenn WiFi aktiv → ADC1 nutzen
- **Strapping-Pins** (GPIO 0,2,12,15): beeinflussen Boot-Modus → vorsichtig verwenden

### LEDC statt analogWrite (PWM-Lüfter)
Kein natives `analogWrite()` auf ESP32 — LEDC verwenden:
```cpp
ledcSetup(channel, 25000, 8);        // ch, freq, resolution
ledcAttachPin(pin, channel);
ledcWrite(channel, value);           // 0-255
```
→ Growbox: 25 kHz PWM auf GPIO 25/26/27/32 (4 Lüfter)

### WiFi-Stabilität
- `WiFi.mode()` **vor** `WiFi.begin()` aufrufen
- Event-basiert mit `WiFi.onEvent()` statt `WiFi.status()` pollen
- Static IP statt DHCP: 2-5s schneller beim Connect
- Reconnect explizit implementieren — `setAutoReconnect(true)` reicht nicht immer

### OTA (ESPHome Flash via http://192.168.2.101:6052)
- Immer zwei OTA-Partitionen im Partition-Schema prüfen
- `ESP.getFreeSketchSpace()` vor großen Updates
- OTA blockiert während Update → nicht in time-critical Tasks

### Brown-Out / Power
- WiFi TX: bis **300mA Peaks** — USB-Port kann zu schwach sein
- Brown-Out-Reset tritt bei <2.4V auf (`esp_brownout_disable()` nur wenn Batterie-Betrieb)
- Deep Sleep: nur RTC-GPIOs als Wakeup-Source (GPIO 0,2,4,12-15,25-27,32-39)
