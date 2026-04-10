# Runbook: MQTT Broker Recovery

> Mosquitto broker restart, persistence issues, auth problems

---

## Scenarios

| Scenario | Symptoms |
|----------|----------|
| **Broker not responding** | Connection refused, timeout |
| **Auth failures** | "Connection refused: not authorised" |
| **Messages not delivered** | Subscribers not receiving |
| **Persistence corruption** | Won't start, disk errors |

---

## Quick Restart

```bash
# Restart mosquitto
docker compose restart mosquitto

# Check status
docker ps | grep mosquitto

# Check logs
docker logs mosquitto --tail 20
```

---

## Scenario 1: Broker Not Responding

### Diagnosis

```bash
# Check if port is open
nc -zv 192.168.2.101 1883

# Check process
docker top mosquitto

# Check logs for errors
docker logs mosquitto 2>&1 | grep -i error
```

### Fix

```bash
# 1. Stop
docker compose stop mosquitto

# 2. Check config syntax
docker run --rm -v $(pwd)/mosquitto/config:/mosquitto/config \
  eclipse-mosquitto:2 mosquitto -c /mosquitto/config/mosquitto.conf -t

# 3. If syntax OK, clear persistence
rm ./mosquitto/data/mosquitto.db

# 4. Start
docker compose up -d mosquitto

# 5. Verify
nc -zv 192.168.2.101 1883
```

---

## Scenario 2: Authentication Failures

### Symptoms

```
Client client-id disconnected, not authorised.
Connection refused: not authorised
```

### Fix

```bash
# 1. Check password file
cat ./mosquitto/config/passwd

# 2. Re-create users
docker exec mosquitto mosquitto_passwd -c /mosquitto/config/passwd homeassistant
# Enter password when prompted

docker exec mosquitto mosquitto_passwd /mosquitto/config/passwd openclaw
docker exec mosquitto mosquitto_passwd /mosquitto/config/passwd esphome

# 3. Restart
docker compose restart mosquitto

# 4. Test
docker exec mosquitto mosquitto_sub -t '#' -u homeassistant -P password -d
```

---

## Scenario 3: ACL Issues

### Symptoms

```
Connection allowed but cannot publish/subscribe
Denied PUBLISH from ... (topic not authorized)
```

### Fix

```bash
# 1. Check ACL file
cat ./mosquitto/config/acl

# 2. Verify format
# user USERNAME
# topic [read|write|readwrite] TOPIC

# 3. Example fixed ACL
cat > ./mosquitto/config/acl << 'EOF'
# Home Assistant - full access
user homeassistant
topic readwrite #

# OpenClaw - full access  
user openclaw
topic readwrite #

# ESPhome - limited
user esphome
topic read growbox/+
topic write growbox/+
EOF

# 4. Restart
docker compose restart mosquitto
```

---

## Scenario 4: Message Delivery Issues

### Check Retained Messages

```bash
# List retained messages
docker exec mosquitto mosquitto_sub -t '#' -u homeassistant -P password -v -R

# Clear retained message (publish empty retained)
docker exec mosquitto mosquitto_pub -t 'problem/topic' -r -n -u homeassistant -P password
```

### Check Subscribers

```bash
# Subscribe to $SYS topics
docker exec mosquitto mosquitto_sub -t '$SYS/#' -v -u homeassistant -P password
```

---

## Scenario 5: Persistence Corruption

### Symptoms

```
Error: Unable to open persistence file
Disk full errors
```

### Fix

```bash
# 1. Stop
docker compose stop mosquitto

# 2. Backup
cp ./mosquitto/data/mosquitto.db ./mosquitto/data/mosquitto.db.corrupt

# 3. Clear persistence
rm ./mosquitto/data/mosquitto.db

# 4. Start
docker compose up -d mosquitto

# Note: Retained messages lost!
```

---

## Complete Restore

```bash
# 1. Stop
docker compose stop mosquitto

# 2. Backup current
cp -r ./mosquitto ./mosquitto.broken.$(date +%s)

# 3. Restore from USB
cp -r /mnt/usb-backup/backups/YYYYMMDD/mosquitto/* ./mosquitto/

# 4. Start
docker compose up -d mosquitto

# 5. Verify
docker exec mosquitto mosquitto_sub -t '$SYS/broker/clients/connected' -v -u admin -P pass
```

---

## Verification

```bash
# Test publish/subscribe
docker exec mosquitto sh -c '
  mosquitto_pub -t test/topic -m "test" -u homeassistant -P password &
  sleep 1
  mosquitto_sub -t test/topic -C 1 -u openclaw -P password
'

# Check connected clients
docker exec mosquitto mosquitto_sub -t '$SYS/broker/clients/connected' -v -u admin -P password -C 1
```

---

## Prevention

| Measure | Implementation |
|---------|----------------|
| **Regular backup** | USB backup includes mosquitto/ |
| **Test auth** | After any password changes |
| **Monitor $SYS** | Alerts on client disconnects |
| **Limit retained** | Auto-expire old messages |

---

## Related

- `docs/infrastructure/mqtt-mosquitto.md`
- `docs/infrastructure/esphome-firmware.md`
