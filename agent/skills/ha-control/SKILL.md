---
name: ha-control
description: Safe Home Assistant REST access. Read-only state queries across all allowed domains, tightly whitelisted Growbox control actions, Tier-1 light/switch writes, and read-only audit/diagnostics.
---

# ha-control

## Purpose
Provide bounded Home Assistant API access so OpenClaw can inspect state across the smart home and perform approved control actions — without ad-hoc REST calls.

## Safety-Tier-System

| Tier | Domains | Writes | Confirmation |
|---|---|---|---|
| **Tier 0** | sensor, binary_sensor, weather, climate, media_player, automation, script, scene, calendar, camera, device_tracker, person, input_number, input_text, input_select, sun, zone, text_sensor, button | Read-only | — |
| **Tier 1** | fan, select, number (Growbox-only), light, switch, input_boolean, scene | Erlaubt | Nein |
| **Tier 2** | lock, cover, alarm_control_panel | **BLOCKIERT** | n/a |
| **Tier 3** | config, homeassistant (Platform) | **IMMER BLOCKIERT** | n/a |

Zusätzlich: `config/blocked-entities.json` — hard-blocked Entities unabhängig von Tier.

## Trigger
Use when users ask for:
- Sensor-States, Entity-Status aus Home Assistant
- Growbox-Steuerung (Lüfter, Betriebsmodus, Master-Fan)
- Lichter, Schalter ein-/ausschalten
- HA Diagnostics: Automationen, History, Logbook, Health
- Entity-Listing nach Domain

## Commands

### Lesen (Tier 0 + Tier 1)
```bash
~/agent/skills/ha-control/scripts/get-state.sh sensor.growbox_temperatur
~/agent/skills/ha-control/scripts/get-state.sh light.living_room
~/agent/skills/ha-control/scripts/get-state.sh climate.bedroom
```

### Entity-Listing
```bash
~/agent/skills/ha-control/scripts/list-entities.sh            # alle (max 50)
~/agent/skills/ha-control/scripts/list-entities.sh light      # nur lights
~/agent/skills/ha-control/scripts/list-entities.sh sensor     # nur sensors
~/agent/skills/ha-control/scripts/list-entities.sh --json     # JSON-Output
```

### Growbox-Steuerung (Tier 1 — whitelisted)
```bash
~/agent/skills/ha-control/scripts/call-service.sh fan set_percentage fan.growbox_lufeter_0 60
~/agent/skills/ha-control/scripts/call-service.sh select select_option select.growbox_betriebsmodus Nacht
~/agent/skills/ha-control/scripts/call-service.sh number set_value number.growbox_alle_lufeter_master 75
```

### Licht/Schalter (Tier 1)
```bash
~/agent/skills/ha-control/scripts/call-service.sh light turn_on light.living_room 200   # brightness 0-255
~/agent/skills/ha-control/scripts/call-service.sh light turn_off light.living_room 0
~/agent/skills/ha-control/scripts/call-service.sh light toggle light.desk 0
~/agent/skills/ha-control/scripts/call-service.sh switch turn_on switch.printer 0
~/agent/skills/ha-control/scripts/call-service.sh input_boolean toggle input_boolean.guest_mode 0
~/agent/skills/ha-control/scripts/call-service.sh scene turn_on scene.evening 0
```

### Tier-Check
```bash
~/agent/skills/ha-control/scripts/check-tier.sh lock.haustuer       # → tier2-blocked
~/agent/skills/ha-control/scripts/check-tier.sh light.living_room   # → tier1-write
~/agent/skills/ha-control/scripts/check-tier.sh sensor.temperature  # → tier0-read
```

### Audit / Diagnostics (read-only)
```bash
~/agent/skills/ha-control/scripts/audit.sh health
~/agent/skills/ha-control/scripts/audit.sh states --domain light
~/agent/skills/ha-control/scripts/audit.sh history sensor.growbox_temperatur
~/agent/skills/ha-control/scripts/audit.sh logs --count 50
~/agent/skills/ha-control/scripts/audit.sh automations
```

### Drift-Check (Growbox-Whitelist)
```bash
~/agent/skills/ha-control/scripts/check-entities.sh
~/agent/skills/ha-control/scripts/check-entities.sh --json
```

### Phase-Thresholds
```bash
~/agent/skills/ha-control/scripts/phase-thresholds.sh          # Human-readable
~/agent/skills/ha-control/scripts/phase-thresholds.sh --json   # JSON für Vergleich
```

## Growbox Entity Whitelist

Readable + Writable (Tier 1):
- `fan.growbox_lufeter_0` .. `_3`
- `select.growbox_betriebsmodus` (Manuell / Auto (Temperatur) / Nacht)
- `number.growbox_alle_lufeter_master`

Readable only (Tier 0):
- `sensor.growbox_temperatur`, `sensor.growbox_luftfeuchtigkeit`
- `sensor.growbox_lufeter_0_rpm` .. `_3_rpm`
- `text_sensor.growbox_status`, `button.growbox_neustart`

## Boundaries
- Tier-2/3 Domains immer blockiert (lock, cover, alarm, config)
- `button.growbox_neustart` ist lesbar aber nicht aufrufbar
- Keine `POST /api/config`, keine Template-Execution
- Requires `HA_TOKEN` in der Umgebung; Token niemals ausgeben

## Telegram Commands

### /growbox
```bash
PHASE_JSON=$(~/agent/skills/ha-control/scripts/phase-thresholds.sh --json)
PHASE=$(echo "$PHASE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('phase_de','?'))")
TEMP=$(~/agent/skills/ha-control/scripts/get-state.sh sensor.growbox_temperatur | python3 -c "import json,sys; print(json.load(sys.stdin).get('state','?'))")
HUM=$(~/agent/skills/ha-control/scripts/get-state.sh sensor.growbox_luftfeuchtigkeit | python3 -c "import json,sys; print(json.load(sys.stdin).get('state','?'))")
echo "🌱 Growbox – Phase: $PHASE | Temp: ${TEMP}°C | RH: ${HUM}% | $(date +%H:%M)"
```

## Webhook-Pattern (HA → OpenClaw)

HA kann Events an OpenClaw senden. Beispiel-Automation (HA YAML):
```yaml
automation:
  - alias: "Growbox Alarm → OpenClaw"
    trigger:
      - platform: state
        entity_id: binary_sensor.growbox_alarm
        to: "on"
    action:
      - service: rest_command.openclaw_webhook
        data:
          event: "growbox_alarm"
          entity_id: "binary_sensor.growbox_alarm"
```

REST-Command dafür in HA `configuration.yaml`:
```yaml
rest_command:
  openclaw_webhook:
    url: "http://192.168.2.101:18789/webhook/growbox"
    method: POST
    content_type: "application/json"
    payload: '{"event": "{{ event }}", "entity_id": "{{ entity_id }}"}'
```

## Related Docs
- `/home/steges/growbox/GROWBOX.md`
- `/home/steges/growbox/THRESHOLDS.md`

## Lifecycle
- Author via: `~/scripts/skill-forge author skill ha-control --mode auto`
- Canary start: `~/scripts/skill-forge canary start ha-control 24`
- Promote: `~/scripts/skill-forge canary promote ha-control`
- Rollback: `~/scripts/skill-forge rollback ha-control`
