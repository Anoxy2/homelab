# Runbook: Vaultwarden Lockout Recovery

> Recovery when locked out of Vaultwarden
> Admin token, database reset, restore from backup

---

## Scenarios

| Scenario | Symptoms |
|----------|----------|
| **Forgot admin password** | Cannot access admin panel |
| **2FA device lost** | Cannot login (if 2FA enforced) |
| **Database corrupted** | 500 errors, cannot start |
| **Wrong master password** | Cannot decrypt vault |

---

## Scenario 1: Forgot Admin Token

### Check Environment

```bash
# Get admin token from compose
grep ADMIN_TOKEN docker-compose.yml

# Or from running container
docker exec vaultwarden env | grep ADMIN_TOKEN
```

### Reset Admin Token

```bash
# Stop container
docker compose stop vaultwarden

# Edit compose, set new token
vim docker-compose.yml
# environment:
#   ADMIN_TOKEN: "$(openssl rand -base64 48)"

# Start container
docker compose up -d vaultwarden

# Access admin panel with new token
open http://vault.lan/admin
```

---

## Scenario 2: User Account Locked

### Disable 2FA via Admin

```bash
# Access admin panel
open http://vault.lan/admin

# Users → Find user → Disable 2FA
# Or: Deauthorize sessions
```

### CLI User Management

```bash
# List users
docker exec vaultwarden /vaultwarden/bin/vaultwarden admin user list

# Disable 2FA for user
docker exec vaultwarden /vaultwarden/bin/vaultwarden admin user disable-2fa <email>
```

---

## Scenario 3: Database Corruption

### Symptoms

```
500 Internal Server Error
Database is locked
SQLite error: database disk image is malformed
```

### Recovery Steps

```bash
# 1. Stop container
docker compose stop vaultwarden

# 2. Backup corrupt database
cp ./vaultwarden/data/db.sqlite3 ./vaultwarden/data/db.sqlite3.corrupt.$(date +%s)

# 3. Try SQLite repair
docker run --rm -v $(pwd)/vaultwarden/data:/data alpine \
  sqlite3 /data/db.sqlite3 ".recover" | sqlite3 /data/db_recovered.sqlite3

# 4. If successful, replace
mv ./vaultwarden/data/db_recovered.sqlite3 ./vaultwarden/data/db.sqlite3

# 5. Restart
docker compose up -d vaultwarden
```

### Restore from Backup

```bash
# If repair failed, restore from USB backup
cp /mnt/usb-backup/backups/latest/vaultwarden/db.sqlite3 ./vaultwarden/data/

# Restart
docker compose up -d vaultwarden
```

---

## Scenario 4: Master Password Lost

### ⚠️ Critical

**If master password is lost, vault CANNOT be recovered.**

Bitwarden/Vaultwarden uses **zero-knowledge encryption**.

### Options

1. **Check password manager** (ironic but possible)
2. **Check browser saved passwords**
3. **Restore old device with vault unlocked**
4. **Check backup export** (if regularly exported)

### Preventive: Export Regularly

```bash
# Via web UI
# Tools → Export Vault → JSON/CSV

# Automated export (requires unlocked session)
# Use backup-automation skill to export periodically
```

---

## Emergency Access

### Setup (Before Emergency)

```
Vault → Settings → Emergency Access
→ Add trusted contact
→ Set wait time (e.g., 7 days)
```

### Use Emergency Access

1. Trusted contact requests access
2. Wait time passes (e.g., 7 days)
3. Contact gets view access to vault
4. Can export passwords

---

## Verification After Recovery

```bash
# Test web vault
open http://vault.lan

# Test API
curl http://192.168.2.101:8888/api/accounts/prelogin

# Check logs
docker logs vaultwarden --tail 20
```

---

## Prevention

| Measure | How |
|---------|-----|
| **Regular backups** | USB backup includes vault data |
| **Export vault** | Monthly JSON export |
| **Emergency access** | Set up trusted contact |
| **Password in safe** | Physical copy in safe |
| **Multiple 2FA methods** | TOTP + Backup codes |

---

## Related

- `docs/infrastructure/vaultwarden-setup.md`
- `docs/runbooks/backup-failure-recovery.md`
