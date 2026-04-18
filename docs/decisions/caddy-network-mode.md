# ADR: Caddy network_mode = host (beibehalten)

**Status:** Entschieden 2026-04-13  
**Entscheider:** steges / Claude

---

## Kontext

Caddy läuft mit `network_mode: host`. Geprüft wurde eine Migration zu Bridge-Mode.

Die folgenden Backends nutzen ebenfalls `network_mode: host` und können keinem
Docker Bridge-Netzwerk beitreten:

- pihole
- homeassistant
- esphome
- mosquitto
- tailscale

Im Bridge-Mode könnten diese Backends nur per statischer IP (`192.168.2.101:PORT`)
angesprochen werden — exakt wie jetzt schon im Caddyfile konfiguriert.
Es entsteht kein Vorteil durch die Migration.

## Entscheidung

**Host-Mode beibehalten.** Kein Migrationsbedarf.

## Risiko/Nutzen

| | Host-Mode (Status quo) | Bridge-Mode |
|---|---|---|
| Netzwerk-Isolation | keiner | für Caddy selbst |
| Backend-Erreichbarkeit | direkt via IP | via IP (identisch) |
| Container-Namensauflösung | nicht möglich | nur für Bridge-Backends |
| Migrationsaufwand | – | mittel (alle Backends müssten folgen) |

## Revisit-Trigger

Wenn alle Backends auf Bridge-Mode migriert sind UND Container-Namensauflösung
(`http://homeassistant:8123`) genutzt werden soll → dann Bridge-Mode evaluieren.
