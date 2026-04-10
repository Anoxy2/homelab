# Home Assistant Setup

## Erststart

1. Container starten: `cd ~ && docker compose up -d homeassistant`
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

## OpenClaw Webhook-Token

OpenClaw-Trigger nutzen einen Bearer-Token, der in beiden Dateien synchron sein muss:

- `.env`: `OPENCLAW_WEBHOOK_TOKEN=<token>`
- `homeassistant/config/secrets.yaml`: `openclaw_webhook_bearer: "Bearer <token>"`

Hinweis:
- Der Wert in `secrets.yaml` enthaelt absichtlich den Prefix `Bearer `, weil `configuration.yaml` den Header direkt aus dem Secret bezieht.
- Bei Token-Rotation immer beide Stellen gemeinsam aktualisieren.

## Updates

Watchtower updated das HA-Image automatisch wöchentlich.
Vor Major-Updates HA-Daten manuell sichern (Breaking Changes möglich).
