# Runbook: ESP32 offline

## Symptome
- ESP32/Growbox in Home Assistant als offline.
- `http://growbox.local` nicht erreichbar.

## Check
1. Ist `http://growbox.local` im LAN erreichbar?
2. Ist ESPHome unter `http://192.168.2.101:6052` erreichbar?

## OTA-Recovery
1. ESPHome UI oeffnen.
2. Betroffenes Geraet waehlen.
3. OTA-Install/Update versuchen.

## Fallback
- Falls OTA scheitert: auf AP-Fallback wechseln (`growbox_ap.yaml`) und lokal neu provisionieren.

## Letzter Schritt
- Physischer Reset am ESP32 nur als letzte Option.

## Abschluss
- Home Assistant Entities pruefen.
- Kurznotiz im Growbox-Diary/Handover eintragen.
