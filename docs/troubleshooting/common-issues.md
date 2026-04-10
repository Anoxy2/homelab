# Common Issues & Solutions

> Top 20 problems and quick fixes
> Searchable by symptom

---

## 1. DNS Not Working

**Symptom:** `ping google.com` fails with "Name or service not known"

**Quick Fix:**
```bash
# Check Pi-hole
docker ps | grep pihole
docker logs pihole --tail 20

# Test DNS directly
dig @192.168.2.101 google.com
dig @1.1.1.1 google.com

# Fix
sudo systemctl restart systemd-resolved
echo "nameserver 192.168.2.101" | sudo tee /etc/resolv.conf
```

**Root Causes:**
- Pi-hole container down
- DNS loop (Pi-hole → Unbound → Pi-hole)
- Client using wrong DNS

---

## 2. Container Won't Start

**Symptom:** `docker ps` doesn't show container, `docker logs` shows error

**Quick Fix:**
```bash
# Check logs
docker logs container_name 2>&1 | tail -30

# Check config
docker compose config | grep -A5 container_name

# Recreate
docker compose up -d --force-recreate container_name
```

**Common Errors:**
- Port already in use
- Config file missing
- Permission denied on volume

---

## 3. High CPU Usage

**Symptom:** Load >2.0, system sluggish

**Quick Fix:**
```bash
# Find culprit
docker stats --no-stream | sort -k3 -rn | head

# Check system
top -bn1 | head -20

# Kill runaway process (last resort)
docker kill container_name
```

**Common Culprits:**
- InfluxDB compaction
- Home Assistant integration loop
- Scrutiny disk scan

---

## 4. Out of Disk Space

**Symptom:** `df -h /` shows >90%

**Quick Fix:**
```bash
# Find big directories
du -sh /* 2>/dev/null | sort -hr | head -10
du -sh /var/lib/docker/* 2>/dev/null | sort -hr

# Docker cleanup
docker system prune -a --volumes -f

# Log cleanup
sudo journalctl --vacuum-time=3d
find /var/log -name "*.log" -size +100M -delete

# Specific cleanup
rm /var/log/backup-automation.log.*
docker exec pihole pihole flush
```

---

## 5. Home Assistant Automations Not Working

**Symptom:** Automations don't trigger, devices unavailable

**Quick Fix:**
```bash
# Check HA status
curl http://192.168.2.101:8123/api/config
docker logs homeassistant --tail 50

# Check MQTT
docker exec mosquitto mosquitto_sub -t '#' -C 5 -u homeassistant -P password

# Restart HA
docker compose restart homeassistant

# Check config
docker exec homeassistant hass --script check_config
```

---

## 6. Vaultwarden Login Failed

**Symptom:** "Invalid username or password"

**Quick Fix:**
```bash
# Check container
docker ps | grep vaultwarden
docker logs vaultwarden --tail 20

# Check admin panel
open http://vault.lan/admin

# Database check
docker exec vaultwarden ls -la /data/

# If corrupted: restore from backup
```

---

## 7. Can't Access LAN URLs

**Symptom:** `home.lan` doesn't resolve

**Quick Fix:**
```bash
# Check DNS
dig home.lan @192.168.2.101

# Check Caddy
docker ps | grep caddy
curl http://192.168.2.101:80/health

# Check Pi-hole Local DNS
curl http://192.168.2.101:8080/admin/dns_records.php

# Temporary fix (on client)
echo "192.168.2.101 home.lan" | sudo tee -a /etc/hosts
```

---

## 8. Backup Failed

**Symptom:** `backup-full.sh` exits with error

**Quick Fix:**
```bash
# Check logs
cat /var/log/backup-automation.log | tail -50

# Check GitHub auth
gh auth status

# Check USB mount
mount | grep usb-backup
ls -la /mnt/usb-backup/

# Run without USB
./backup-full.sh --skip-usb
```

---

## 9. Tailscale Not Connecting

**Symptom:** `tailscale status` shows "Stopped"

**Quick Fix:**
```bash
# Check container
docker ps | grep tailscale
docker logs tailscale --tail 20

# Re-authenticate
docker exec tailscale tailscale up --force-reauth

# Check TUN
ls /dev/net/tun
sudo modprobe tun
```

---

## 10. Grafana No Data

**Symptom:** Dashboards show "No data"

**Quick Fix:**
```bash
# Check Prometheus
curl http://192.168.2.101:9090/api/v1/targets | jq '.data.activeTargets'

# Check InfluxDB
docker logs influxdb --tail 20

# Check data source in Grafana
# Configuration → Data Sources → Test

# Restart stack
docker compose restart prometheus influxdb grafana
```

---

## 11. MQTT Messages Not Received

**Symptom:** Home Assistant not seeing sensor updates

**Quick Fix:**
```bash
# Test MQTT
docker exec mosquitto mosquitto_pub -t test/topic -m "test" -u esphome -P password
docker exec mosquitto mosquitto_sub -t test/topic -C 1 -u homeassistant -P password

# Check auth
docker exec mosquitto cat /mosquitto/config/passwd

# Restart
docker compose restart mosquitto
```

---

## 12. ESPHome Device Offline

**Symptom:** "Offline" in ESPhome dashboard

**Quick Fix:**
```bash
# Check WiFi
ping growbox-sensor.local

# Check ESPhome
docker ps | grep esphome
curl http://192.168.2.101:6052

# Re-flash if needed (USB)
docker exec esphome esphome run /config/growbox-sensor.yaml
```

---

## 13. Prometheus High Memory

**Symptom:** Container OOM killed

**Quick Fix:**
```bash
# Reduce retention
docker exec prometheus kill -HUP 1  # Reload config

# Edit prometheus.yml
# --storage.tsdb.retention.time=7d

# Or manual cleanup
docker exec prometheus rm -rf /prometheus/*
docker compose restart prometheus
```

---

## 14. Git Push Failed

**Symptom:** "Authentication failed" or "Permission denied"

**Quick Fix:**
```bash
# Check auth
gh auth status
cat ~/.git-credentials

# Re-authenticate
gh auth login
# Or: gh auth refresh

# Check remote
git remote -v

# Check permissions
gh repo view Anoxy2/homelab
```

---

## 15. Docker Commands Hang

**Symptom:** `docker ps` takes forever

**Quick Fix:**
```bash
# Check daemon
sudo systemctl status docker

# Check resources
free -h
df -h

# Restart Docker (careful!)
sudo systemctl restart docker

# If stuck containers:
docker system prune -f
```

---

## 16. Network Slow

**Symptom:** High latency, packet loss

**Quick Fix:**
```bash
# Test
ping -c 10 192.168.2.1
iperf3 -c 192.168.2.1

# Check errors
ifconfig eth0 | grep -i error
dmesg | grep -i eth

# Restart interface
sudo ip link set eth0 down && sudo ip link set eth0 up
```

---

## 17. Logs Missing

**Symptom:** Loki shows no new logs

**Quick Fix:**
```bash
# Check Promtail
docker ps | grep promtail
docker logs promtail --tail 20

# Check socket
docker exec promtail ls -la /var/run/docker.sock

# Restart
docker compose restart promtail
```

---

## 18. Certificate Warnings

**Symptom:** Browser warns about invalid cert

**Quick Fix:**
```bash
# Expected: We're using HTTP in LAN
# For HTTPS, use Tailscale

# Ignore warning (LAN is trusted)
# Or: Add exception in browser
```

---

## 19. Watchtower Not Updating

**Symptom:** Old container images still running

**Quick Fix:**
```bash
# Check schedule
docker logs watchtower --tail 20

# Force update
docker exec watchtower watchtower --run-once

# Check labels
docker inspect grafana | grep watchtower
```

---

## 20. Can't SSH to Pi

**Symptom:** "Connection refused" or timeout

**Quick Fix:**
```bash
# From Pi console:
sudo systemctl status ssh
sudo systemctl restart ssh

# Check firewall
sudo ufw status | grep 22

# Check IP
ip addr show eth0
```

---

## Emergency Recovery

### Nuclear Option: Full Restart

```bash
# Only if everything broken
sudo reboot

# Or Docker restart
sudo systemctl restart docker
docker compose up -d
```

### Data Recovery

```bash
# From USB backup
cd /mnt/usb-backup/backups/latest/
rsync -av ./homeassistant/ ~/homelab/homeassistant/
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Initial issue list created |
