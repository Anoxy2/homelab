# Secret Rotation Schedule

> When and how to rotate passwords, tokens, and keys
> Automation and manual procedures

---

## Rotation Schedule

| Secret | Type | Rotation | Last Rotated | Next Due |
|--------|------|----------|--------------|----------|
| **Vaultwarden Admin** | Password | Annual | 2026-04-10 | 2027-04-10 |
| **Vaultwarden Master** | Password | User discretion | - | As needed |
| **Pi-hole Admin** | Password | Annual | 2026-04-10 | 2027-04-10 |
| **Home Assistant** | Token | On breach | 2026-04-10 | On suspicion |
| **GitHub Token** | PAT | Annual | 2026-04-10 | 2027-04-10 |
| **MQTT Passwords** | Password | Annual | 2026-04-10 | 2027-04-10 |
| **InfluxDB Token** | Token | Annual | 2026-04-10 | 2027-04-10 |
| **Tailscale Key** | Auth key | On device add | - | As needed |
| **ntfy (none)** | - | - | - | - |

---

## Rotation Procedures

### Vaultwarden Admin Token

```bash
# 1. Generate new token
NEW_TOKEN=$(openssl rand -base64 48)
echo "New token: $NEW_TOKEN"

# 2. Update docker-compose.yml
vim docker-compose.yml
# ADMIN_TOKEN: "$NEW_TOKEN"

# 3. Recreate container
docker compose up -d vaultwarden

# 4. Test admin panel
open http://vault.lan/admin

# 5. Update password manager
# Save $NEW_TOKEN in Vaultwarden (ironic but correct)
```

### Pi-hole Password

```bash
# 1. Via web UI
open http://pihole.lan:8080/admin
Settings → Web Interface → Web Interface Password

# 2. Or CLI
docker exec pihole pihole -a -p
# Enter new password

# 3. Update all references
# - .env file
# - Password manager
# - Browser saved passwords
```

### Home Assistant Long-Lived Token

```bash
# 1. Revoke old token
# Profile → Long-Lived Access Tokens → Delete

# 2. Create new token
# Profile → Long-Lived Access Tokens → Create
# Name: "OpenClaw 2026"
# Copy token immediately!

# 3. Update configurations
vim ./homeassistant/config/configuration.yaml
# api:
#   token: !secret ha_api_token

vim .env
# HA_API_TOKEN=your-new-token

# 4. Restart HA
docker compose restart homeassistant
```

### GitHub Personal Access Token

```bash
# 1. Create new token
open https://github.com/settings/tokens
Generate new token (classic)
Scopes: repo, workflow

# 2. Update local config
git config --global credential.helper store
# Push will prompt for new token

# 3. Update OpenClaw/backup scripts
vim .env
# GH_TOKEN=ghp_xxxx

# 4. Revoke old token (after confirming new one works)
```

### MQTT Passwords

```bash
# 1. Update passwd file
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/passwd homeassistant newpassword
docker exec mosquitto mosquitto_passwd -b /mosquitto/config/passwd openclaw newpassword

# 2. Restart mosquitto
docker compose restart mosquitto

# 3. Update all client configs
vim ./homeassistant/config/configuration.yaml
# mqtt:
#   password: !secret mqtt_password

vim .env
# MQTT_PASSWORD=newpassword

# 4. Restart clients
docker compose restart homeassistant
```

### InfluxDB Token

```bash
# 1. Generate new token
docker exec influxdb influx auth create \
  --org pilab \
  --all-access \
  --description "Rotation $(date +%Y-%m)"

# 2. Get token ID
docker exec influxdb influx auth list

# 3. Update configs
vim .env
# INFLUXDB_TOKEN=xxx

# 4. Restart services
docker compose restart homeassistant influxdb

# 5. Revoke old token (after 24h)
docker exec influxdb influx auth delete --id OLD_ID
```

---

## Automation

### Annual Rotation Reminder

```yaml
# Home Assistant automation
- alias: "Annual Secret Rotation Reminder"
  trigger:
    platform: time
    at: "09:00:00"
  condition:
    condition: template
    value_template: "{{ now().month == 4 and now().day == 1 }}"
  action:
    - service: notify.ntfy
      data:
        message: "🔐 Time for annual secret rotation! Check docs/operations/secret-rotation.md"
```

---

## Compromise Response

### If Secret Leaked

1. **Immediate:** Rotate affected secret
2. **Within 1h:** Check logs for unauthorized access
3. **Within 24h:** Rotate related secrets (defense in depth)
4. **Within 1w:** Review all access logs

### Log Checks

```bash
# Vaultwarden
docker logs vaultwarden | grep -i "login\|auth"

# Pi-hole
docker exec pihole cat /var/log/pihole/pihole.log | tail -1000

# SSH
sudo grep "sshd" /var/log/auth.log | grep -v "127.0.0.1"
```

---

## Secret Storage

### Hierarchy

```
Tier 1: Vaultwarden (master password + 2FA)
├── All other passwords
├── API tokens  
├── SSH keys
└── Recovery codes

Tier 2: USB Backup (encrypted)
├── GitHub token (for automation)
├── WiFi passwords
└── Hardware serials

Tier 3: Physical
├── Pi-hole password (router sticker)
└── Router admin password
```

### What NOT to Store

| Never Store In | Reason |
|----------------|--------|
| Plain text files | Visible to any process |
| Unencrypted cloud | Third-party access |
| Git (unencrypted) | History leaks |
| Browser (only) | Sync risks |

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Initial rotation schedule |
