# Authelia SSO / Forward Auth

> Zwei-Faktor-Authentifizierung für Web-Services
> LDAP-fähig, TOTP, Backup-Codes

---

## Überblick

**Authelia** ist der Authentifizierungs-Layer vor sensiblen Services – 2FA, Session-Management, Single Sign-On.

| Attribut | Wert |
|----------|------|
| **Image** | `authelia/authelia:4.37.5` (letzte HTTP-Version) |
| **Container** | authelia |
| **Port** | `192.168.2.101:9091` |
| **LAN URL** | `http://auth.lan` |
| **Config** | `./authelia/config/` |

**Wichtig:** Version 4.37.5 ist gepinnt – 4.38+ erzwingt HTTPS.

---

## Architektur

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   User      │────→│    Caddy    │────→│   Authelia  │
│  (Browser)  │     │             │     │   :9091     │
└─────────────┘     └─────────────┘     └─────────────┘
        │                                        │
        │              ┌─────────────────────────┘
        │              ↓
        │     ┌─────────────┐
        └────→│   Grafana   │ ←── Geschützter Service
              │  (nur mit   │
              │   Auth)     │
              └─────────────┘
```

---

## Konfiguration

### Docker Compose

```yaml
services:
  authelia:
    image: authelia/authelia:4.37.5
    container_name: authelia
    ports:
      - "192.168.2.101:9091:9091"
    volumes:
      - ./authelia/config:/config
    environment:
      TZ: Europe/Berlin
    env_file: .env
```

### configuration.yml

```yaml
# authelia/config/configuration.yml

server:
  host: 0.0.0.0
  port: 9091

log:
  level: info

theme: dark

jwt_secret: "change-this-to-a-long-random-string"
default_2fa_method: totp

authentication_backend:
  file:
    path: /config/users_database.yml
    password:
      algorithm: argon2id
      iterations: 1
      key_length: 32
      salt_length: 16
      parallelism: 8
      memory: 64

access_control:
  default_policy: one_factor
  rules:
    # Grafana: 2FA erforderlich
    - domain: grafana.lan
      policy: two_factor
    
    # Portainer: 2FA erforderlich
    - domain: portainer.lan
      policy: two_factor
    
    # Vaultwarden: 2FA erforderlich
    - domain: vault.lan
      policy: two_factor
    
    # Rest: Optional (nur Passwort)
    - domain: "*.lan"
      policy: one_factor

session:
  name: authelia_session
  secret: "another-long-random-string"
  expiration: 1h
  inactivity: 5m
  remember_me_duration: 1M

regulation:
  max_retries: 3
  find_time: 2m
  ban_time: 5m

storage:
  local:
    path: /config/db.sqlite3

notifier:
  filesystem:
    filename: /config/notification.txt
  # Oder SMTP für echte Emails:
  # smtp:
  #   host: smtp.gmail.com
  #   port: 587
  #   username: ${SMTP_USER}
  #   password: ${SMTP_PASS}
  #   sender: authelia@yourdomain.com

identity_providers:
  oidc:
    enabled: false  # Nur wenn OIDC benötigt wird
```

### users_database.yml

```yaml
# authelia/config/users_database.yml
users:
  steges:
    disabled: false
    displayname: "Steges Admin"
    password: "$argon2id$v=19$m=65536,t=3,p=4$..."  # Siehe unten
    email: tobiasstegemann1@googlemail.com
    groups:
      - admins
      - users
```

**Passwort hashen:**

```bash
docker run authelia/authelia:4.37.5 \
  authelia crypto hash generate argon2 \
  --password 'dein-passwort-hier'
```

---

## Caddy-Integration

### Forward-Auth

```caddyfile
# Geschützte Services
grafana.lan {
    forward_auth 192.168.2.101:9091 {
        uri /api/verify?rdm=https://auth.lan
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
    reverse_proxy 192.168.2.101:3003
}

portainer.lan {
    forward_auth 192.168.2.101:9091 {
        uri /api/verify?rdm=https://auth.lan
        copy_headers Remote-User Remote-Groups
    }
    reverse_proxy 192.168.2.101:9000
}

# Authelia selbst
auth.lan {
    reverse_proxy 192.168.2.101:9091
}
```

---

## Erst-Setup

### 1. User anlegen

```bash
# Passwort hashen
docker run --rm authelia/authelia:4.37.5 \
  authelia crypto hash generate argon2 \
  --password 'dein-sicheres-passwort'

# In users_database.yml einfügen
```

### 2. TOTP einrichten

1. `http://auth.lan` öffnen
2. Mit User/Passwort einloggen
3. QR-Code mit Authy/Google Authenticator scannen
4. Backup-Codes speichern!

### 3. Test

```bash
# Grafana ohne Login → Authelia-Redirect
# Nach Auth → Grafana mit Header-Info
```

---

## 2FA-Methoden

| Methode | Status | Setup |
|---------|--------|-------|
| **TOTP** | ✅ Empfohlen | App scannen |
| **WebAuthn** | ✅ Hardware-Key | YubiKey etc. |
| **Duo** | ❌ Nicht konfiguriert | Externer Service |
| **Backup Codes** | ✅ Automatisch | 5 Codes bei TOTP-Setup |

---

## Troubleshooting

### "Access Denied"

```bash
# Logs prüfen
docker logs authelia --tail 50

# Session-Check
curl http://auth.lan/api/state

# CORS-Header prüfen
```

### "Invalid credentials"

```bash
# User existiert?
cat ./authelia/config/users_database.yml

# Passwort-Hash korrekt?
# Re-hash mit aktuellem Authelia
```

### "Session expired"

```yaml
# Session-Länge anpassen
session:
  expiration: 8h  # Statt 1h
  inactivity: 30m  # Statt 5m
```

### CORS-Fehler

```yaml
# configuration.yml
server:
  headers:
    csp_template: "default-src 'self'; ..."
```

---

## Backup

```bash
# Wichtige Dateien
./authelia/config/configuration.yml
./authelia/config/users_database.yml
./authelia/config/db.sqlite3

# USB-Backup
./authelia/ → /mnt/usb-backup/backups/YYYYMMDD/authelia/
```

**Wichtig:** Backup-Codes separat sichern (z.B. Passwort-Manager)!

---

## Security Notes

- **LAN-only:** Authelia ist nicht öffentlich erreichbar
- **Kein HTTPS:** Absichtlich für LAN (Version gepinnt)
- **Tailscale:** Für Remote-Zugriff Tailscale verwenden
- **Session-Klau:** Bei physischem Zugriff zum Pi möglich

---

## Changelog

| Datum | Änderung |
|-------|----------|
| 2026-04-10 | Dokumentation erstellt, Authelia 4.37.5 |
