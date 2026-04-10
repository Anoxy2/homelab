# Open Work Todo

Aktueller Stand und nächste Schritte für OpenClaw, RAG, UI und Infrastruktur.

## KI-Regel (verbindlich)

- Vor dem Entfernen erledigter Todos müssen zuerst die passenden Dokus aktualisiert werden (mindestens `docs/skills/skill-forge-governance.md` und `CHANGELOG.md`, je nach Thema zusätzlich Runbooks/Service-Doku).
- Bei Skill-Forge/Lifecycle-Änderungen immer erst validieren (`skill-forge policy lint` + relevante Syntax-/Smoke-Checks), dann Todo-Eintrag entfernen.
- Todo-Liste enthält nur offene Arbeit; erledigte Punkte werden nicht als `[x]` gesammelt, sondern aus der Liste gelöscht.

## Offene Arbeit

- P0 Reverse-Proxy Restarbeit: Bridge-Mode-Fix fuer Caddy bei weiter erreichbaren host-mode Backends.
- Infra-Folgeentscheidungen aus Hardening/Monitoring in konkrete Umsetzungs-Todos zerlegen.

## P1 Self-Healing Backlog (integriert aus agent/TO-DO.md)

- Service-Health-Watchdog fuer zentrale Container inkl. Restart-Strategie und Eskalation nach wiederholten Fehlversuchen.
- Config-Check und abgesicherter Rollback-Flow fuer kritische Konfigurationen (Pi-hole, Home Assistant, Caddy).
- Connectivity-/Tailscale-Selbsttest inkl. DNS-/Gateway-Pruefungen und klarer Reconnect-Strategie.
- Storage/Mount-Recovery fuer NVMe/Backups inkl. Alarmierung bei hoher Auslastung oder Offline-Zustand.
- Sensor-/Hardware-Check fuer Growbox/ESP32 inkl. abgestuftem Reconnect/Neustart-Ansatz.
- Self-Heal-Reporting mit strukturiertem Log und regelmaessiger Zusammenfassung (Canvas/Telegram)

## P1 Neue Services (eingerichtet, manuelle Schritte ausstehend)

- Authelia: Passwort-Hash in `authelia/config/users_database.yml` setzen + Secrets in `.env` eintragen (AUTHELIA_JWT_SECRET, AUTHELIA_SESSION_SECRET, AUTHELIA_STORAGE_ENCRYPTION_KEY), dann `docker compose up -d authelia`.
- Authelia: Forward-Auth in Caddyfile pro gewünschtem Service aktivieren (Vorlage am Ende des Caddyfile).
- Ntfy: ersten User anlegen nach Start: `docker exec -it ntfy ntfy user add steges`
- Scrutiny: nach Start unter http://scrutiny.lan prüfen ob NVMe erkannt wird.
- Glances: bei nächstem Watchtower-Update Digest in docker-compose.yml manuell aktualisieren (TODO-Kommentar im File).

## P2 Monitoring-Optimierungen

- Alertmanager-Telegram-Integration testen (TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID in .env nötig).
- Grafana: Loki-Logs-Dashboard erstellen (Datasource ist bereits provisioniert).
- Prometheus alert rules `prometheus/rules/homelab-alerts.yml` nach Bedarf anpassen (Schwellwerte).
