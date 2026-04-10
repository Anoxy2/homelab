# Runbook: Home Assistant Restore

> Recovery from corruption, failed updates, or data loss
> SQLite restore, InfluxDB recovery, configuration reset

---

## Scenarios

| Scenario | Symptoms |
|----------|----------|
| **Database locked/corrupt** | 500 errors, slow startup |
| **Failed update** | Won't start, incompatible changes |
| **Broken configuration** | Won't validate, check fails |
| **Lost all data** | Fresh install state |

---

## Scenario 1: Database Corruption

### Symptoms

```
Home Assistant taking >10 min to start
Database is locked errors
Recorder errors in logs
```

### Recovery Steps

```bash
# 1. Stop HA
docker compose stop homeassistant

# 2. Backup corrupt DB
cp ./homeassistant/config/home-assistant_v2.db \
   ./homeassistant/config/home-assistant_v2.db.corrupt.$(date +%s)

# 3. Quick fix: Delete and recreate (loses history)
rm ./homeassistant/config/home-assistant_v2.db

# 4. Or repair (keeps data)
docker run --rm -v $(pwd)/homeassistant/config:/config alpine \
  sqlite3 /config/home-assistant_v2.db ".recover" | \
  sqlite3 /config/home-assistant_v2.db.recovered

# 5. Move recovered
cp ./homeassistant/config/home-assistant_v2.db.recovered \
   ./homeassistant/config/home-assistant_v2.db

# 6. Start HA
docker compose up -d homeassistant

# 7. Verify
docker logs homeassistant --tail 50
```

---

## Scenario 2: Failed Update

### Rollback to Previous Version

```bash
# 1. Stop HA
docker compose stop homeassistant

# 2. Edit docker-compose.yml
vim docker-compose.yml
# Change:
# image: ghcr.io/home-assistant/home-assistant:2026.3.3  # Old version

# 3. Recreate with old version
docker compose up -d homeassistant

# 4. Check logs
docker logs homeassistant --tail 50
```

### Find Last Working Version

```bash
# Check git history
git log --oneline docker-compose.yml | head -10

# Or check backup dates
ls -la /mnt/usb-backup/backups/*/homeassistant/
```

---

## Scenario 3: Configuration Validation Failed

### Safe Mode Startup

```bash
# 1. Stop HA
docker compose stop homeassistant

# 2. Rename config to safe mode
cd ./homeassistant/config
mv configuration.yaml configuration.yaml.broken
touch configuration.yaml

# 3. Start HA (minimal config)
docker compose up -d homeassistant

# 4. Fix broken config via editor
# Access via SSH or Portainer console

# 5. Test config
docker exec homeassistant hass --script check_config

# 6. Restore fixed config
mv configuration.yaml.broken configuration.yaml

# 7. Restart
docker compose restart homeassistant
```

### Common Config Errors

| Error | Fix |
|-------|-----|
| `Invalid config for [X]` | Check YAML syntax |
| `Platform not found` | Integration not installed |
| `Secret X not defined` | Add to secrets.yaml |
| `Circular dependency` | Check automation triggers |

---

## Scenario 4: Complete Restore from Backup

### USB Backup Restore

```bash
# 1. Stop HA
docker compose stop homeassistant

# 2. Backup current state (just in case)
cp -r ./homeassistant/config ./homeassistant/config.broken.$(date +%s)

# 3. Restore from USB
cp -r /mnt/usb-backup/backups/YYYYMMDD/homeassistant/* \
      ./homeassistant/config/

# 4. Fix permissions
sudo chown -R 1000:1000 ./homeassistant/config/

# 5. Start HA
docker compose up -d homeassistant
```

### InfluxDB Restore (if using)

```bash
# Stop InfluxDB
docker compose stop influxdb

# Restore data
cp -r /mnt/usb-backup/backups/YYYYMMDD/influxdb/* \
      ./influxdb/data/

# Start
docker compose up -d influxdb
```

---

## Verification

```bash
# Check running
docker ps | grep homeassistant

# Check logs
docker logs homeassistant --tail 50

# Check web UI
curl -s http://192.168.2.101:8123 | head

# Check API
curl -H "Authorization: Bearer TOKEN" \
  http://192.168.2.101:8123/api/states | head
```

---

## Prevention

| Measure | Implementation |
|---------|----------------|
| **Snapshots** | HA Settings → System → Backups → Daily |
| **USB backup** | Included in backup-full.sh |
| **Git tracking** | Config in GitHub repo |
| **Test updates** | Read release notes first |
| **Staged updates** | Update dev container first |

---

## Related

- `docs/infrastructure/homeassistant-smarthome.md`
- `docs/runbooks/backup-failure-recovery.md`
