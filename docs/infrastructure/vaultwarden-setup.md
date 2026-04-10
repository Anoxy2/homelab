# Vaultwarden Setup

> Self-hosted Bitwarden-Alternative für Password Management
> Lightgewicht, LAN-only, SQLite-Backend

---

## Überblick

**Vaultwarden** ist die rust-basierte, ressourcenschonende Alternative zum offiziellen Bitwarden Server. Ideal für Homelab-Setup.

| Attribut | Wert |
|----------|------|
| **Image** | `vaultwarden/server:1.34.1-alpine` |
| **Container** | vaultwarden |
| **Port** | `192.168.2.101:8888` |
| **LAN URL** | `http://vault.lan` |
| **Datenbank** | SQLite (`/data/db.sqlite3`) |
| **RAM** | 256MB (limit) |
| **CPU** | 0.25 (limit) |

---

## Konfiguration

### Docker Compose

```yaml
services:
  vaultwarden:
    image: vaultwarden/server:1.34.1-alpine
    container_name: vaultwarden
    ports:
      - "192.168.2.101:8888:80"
    volumes:
      - ./vaultwarden/data:/data
    environment:
      WEBSOCKET_ENABLED: "true"
      SIGNUPS_ALLOWED: "false"
      DOMAIN: "http://vault.lan"
      LOG_LEVEL: "warn"
```

### Caddyfile Eintrag

```caddyfile
vault.lan {
    reverse_proxy 192.168.2.101:8888
}
```

### Environment Variables

| Variable | Wert | Zweck |
|----------|------|-------|
| `WEBSOCKET_ENABLED` | `true` | Echtzeit-Sync |
| `SIGNUPS_ALLOWED` | `false` | Registrierung deaktiviert (manuell erlauben für Setup) |
| `DOMAIN` | `http://vault.lan` | Base-URL für Links |
| `LOG_LEVEL` | `warn` | Weniger Log-Spam |
| `ADMIN_TOKEN` | *(optional)* | Admin-Panel Zugriff |

---

## Erst-Setup

### 1. Registrierung erlauben (temporär)

```bash
# Edit docker-compose.yml
SIGNUPS_ALLOWED: "true"

# Restart
docker compose up -d vaultwarden
```

### 2. Account erstellen

Browser öffnen → `http://vault.lan` → "Create account"

### 3. Registrierung wieder sperren

```bash
SIGNUPS_ALLOWED: "false"
docker compose up -d vaultwarden
```

### 4. Backup aktivieren

Vaultwarden ist Teil des USB-Backups:
```
./vaultwarden/ → /mnt/usb-backup/backups/YYYYMMDD/vaultwarden/
```

---

## Client-Setup

### Browser Extension

1. Extension installieren (Chrome/Firefox/Edge)
2. "Self-hosted" wählen
3. Server-URL: `http://vault.lan`
4. Login mit erstelltem Account

### Mobile App

1. Bitwarden App installieren
2. Einstellungen → "Self-hosted"
3. Server URL: `http://vault.lan` (im LAN) oder Tailscale-IP

---

## Admin-Panel (optional)

```yaml
environment:
  ADMIN_TOKEN: "$(openssl rand -base64 48)"
```

Zugriff: `http://vault.lan/admin`

**Features:**
- User-Verwaltung
- Login-Versuche anzeigen
- 2FA-Reset

---

## Backup & Restore

### Automatisch (USB-Backup)

```bash
# Täglich im USB-Backup enthalten
/mnt/usb-backup/backups/YYYYMMDD/vaultwarden/
```

### Manuell

```bash
# Export via Web-UI
# Tools → Export Vault → .json oder .csv

# SQLite direkt sichern
cp ./vaultwarden/data/db.sqlite3 /backup/vaultwarden-$(date +%Y%m%d).db
```

### Restore

```bash
# 1. Container stoppen
docker compose stop vaultwarden

# 2. Backup kopieren
cp /mnt/usb-backup/backups/YYYYMMDD/vaultwarden/db.sqlite3 ./vaultwarden/data/

# 3. Starten
docker compose up -d vaultwarden
```

---

## Troubleshooting

### "Cannot save password"

```bash
# Berechtigungen prüfen
ls -la ./vaultwarden/data/

# Fix
sudo chown -R 1000:1000 ./vaultwarden/data/
```

### Sync-Fehler

```bash
# Websocket prüfen
curl http://192.168.2.101:8888/api/accounts/prelogin

# Logs
docker logs vaultwarden --tail 50
```

### SQLite locked

```bash
# Vacuum (defragmentieren)
docker exec vaultwarden sh -c "sqlite3 /data/db.sqlite3 'VACUUM;'"
```

---

## Security Hardening

```yaml
# Empfohlene Ergänzungen:
environment:
  SIGNUPS_ALLOWED: "false"
  SIGNUPS_VERIFY: "true"           # Email-Verifikation
  SIGNUPS_VERIFY_RESEND_TIME: "3600"
  SMTP_HOST: "smtp.gmail.com"     # Für 2FA/Notifications
  SMTP_FROM: "vault@yourdomain.com"
  SMTP_PORT: "587"
  SMTP_SECURITY: "starttls"
  SMTP_USERNAME: "${SMTP_USER}"
  SMTP_PASSWORD: "${SMTP_PASS}"
```

---

## Referenzen

- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- [Bitwarden Security](https://bitwarden.com/help/security/)
- `docs/infrastructure/backup-strategy.md` – Backup-Details

---

## Changelog

| Datum | Änderung |
|-------|----------|
| 2026-04-10 | Initial setup, Version 1.34.1-alpine |
