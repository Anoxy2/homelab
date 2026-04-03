# Home Assistant Setup

## Erststart

1. Container starten: `cd ~/homeassistant && docker compose up -d`
2. Browser: http://192.168.2.101:8123
3. Onboarding durchlaufen (User anlegen, Standort, Zeitzone)

## Netzwerk

Läuft mit `network_mode: host` damit HA:
- Geräte per mDNS/Bonjour erkennt
- Matter/Thread devices discovert
- UPnP nutzen kann

## Konfiguration

Alle HA-Daten liegen in `~/homeassistant/config/`.
Backup dieser Ordner sichert die komplette HA-Installation.

## Updates

Watchtower updated das HA-Image automatisch wöchentlich.
Vor Major-Updates HA-Daten manuell sichern (Breaking Changes möglich).
