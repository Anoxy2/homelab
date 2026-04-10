# Test Json Output

## Zweck

test json output.

## Voraussetzungen

- Raspberry Pi 5 mit Debian 12 Bookworm
- Docker Compose v2
- Relevante Services laufen (`docker compose ps`)

## Schritte

1. Vorbereitung prüfen:
   ```bash
   cd ~/
   docker compose ps
   ```

2. Aktion durchführen:
   ```bash
   # Befehle hier einfügen
   ```

3. Ergebnis verifizieren:
   ```bash
   # Verifikations-Befehle hier
   ```

## Rollback

Falls etwas schief läuft:

```bash
# Rollback-Schritte hier
# Beispiel: docker compose restart <service>
```

## Risiken und Hinweise

- Änderungen an laufenden Services kurz unterbrechen ggf. Dienste
- `.env`-Änderungen erfordern Container-Neustart
- Pi-hole-Stopp unterbricht DNS für alle LAN-Geräte
