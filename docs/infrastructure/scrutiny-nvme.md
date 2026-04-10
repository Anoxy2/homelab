# Scrutiny NVMe Monitoring

> S.M.A.R.T. monitoring for NVMe drives
> Web UI, alerts, long-term trend analysis

---

## Overview

**Scrutiny** monitors NVMe drive health via S.M.A.R.T. data.

| Attribute | Value |
|-----------|-------|
| **Image** | `ghcr.io/analogj/scrutiny:v0.8.1-omnibus` |
| **Container** | scrutiny |
| **Port** | `192.168.2.101:8891` |
| **Device** | `/dev/nvme0n1` |
| **Config** | `./scrutiny/config/` |

---

## Configuration

### Docker Compose

```yaml
services:
  scrutiny:
    image: ghcr.io/analogj/scrutiny:v0.8.1-omnibus
    container_name: scrutiny
    ports:
      - "192.168.2.101:8891:8080"
    volumes:
      - ./scrutiny/config:/opt/scrutiny/config
      - /run/udev:/run/udev:ro
    cap_add:
      - SYS_RAWIO
    devices:
      - /dev/nvme0n1:/dev/nvme0n1
```

### scrutiny.yaml

```yaml
# scrutiny/config/scrutiny.yaml

version: 1

web:
  listen:
    port: 8080
    host: 0.0.0.0
  database:
    location: /opt/scrutiny/config/scrutiny.db

log:
  file: /opt/scrutiny/config/scrutiny.log
  level: INFO

notify:
  urls:
    - "ntfy://192.168.2.101:8900/drive-alerts"
  # Or webhook:
  # - "generic://192.168.2.101:8900/drive-alerts"

# SMART polling
smartctl:
  binaries:
    - /usr/sbin/smartctl
  
# Scan schedule
cron:
  summary: '0 0 * * *'      # Daily at midnight
  short: '0 8,20 * * *'      # Every 12 hours
  long: '0 0 1 * *'          # Monthly

# Thresholds
metrics:
  smart:
    # Critical thresholds
    temperature_warning: 70
    temperature_critical: 80
    
    # NVMe specific
    available_spare_warning: 10
    available_spare_critical: 5
    percentage_used_warning: 90
    percentage_used_critical: 95
```

### Caddyfile

```caddyfile
scrutiny.lan {
    reverse_proxy 192.168.2.101:8891
}
```

---

## S.M.A.R.T. Metrics (NVMe)

| Attribute | Description | Critical If |
|-----------|-------------|-------------|
| `critical_warning` | Critical warnings flags | > 0 |
| `temperature` | Composite temperature | > 70°C |
| `available_spare` | Available spare | < 10% |
| `available_spare_threshold` | Spare threshold | < 100% |
| `percentage_used` | Endurance used | > 90% |
| `data_units_read` | Data read | (trend) |
| `data_units_written` | Data written | (trend) |
| `host_read_commands` | Read commands | (trend) |
| `host_write_commands` | Write commands | (trend) |
| `controller_busy_time` | Controller busy | (trend) |
| `power_cycles` | Power cycles | (trend) |
| `power_on_hours` | Power-on hours | (trend) |
| `unsafe_shutdowns` | Unsafe shutdowns | increasing |
| `media_errors` | Media errors | > 0 |
| `num_err_log_entries` | Error log entries | increasing |
| `warning_temp_time` | Time over warning temp | > 0 |
| `critical_temp_time` | Time over critical temp | > 0 |

---

## Endurance Calculation

```
TBW (Terabytes Written) = (capacity × endurance rating)

For Crucial P3 1TB:
- Endurance: ~220 TBW
- Percentage used = (actual TBW / 220) × 100

At 10% used = 22 TB written
At 50% used = 110 TB written
```

---

## API

```bash
# Device summary
curl http://192.168.2.101:8891/api/summary

# Specific device
curl http://192.168.2.101:8891/api/device/nvme0n1

# SMART data
curl http://192.168.2.101:8891/api/device/nvme0n1/smart

# Health check
curl http://192.168.2.101:8891/api/health
```

---

## Troubleshooting

### "No devices found"

```bash
# Check device path
docker exec scrutiny ls -la /dev/nvme*

# Manual test
docker exec scrutiny smartctl -a /dev/nvme0n1

# Re-scan
docker exec scrutiny scrutiny-collector-metrics run
```

### Permission denied

```bash
# Check CAP_SYS_RAWIO
docker exec scrutiny capsh --print | grep sys_rawio

# Check device ownership
ls -la /dev/nvme0n1

# Fix: Container needs privileged or cap_add
```

### High temperature alerts

```bash
# Check actual temp
smartctl -a /dev/nvme0n1 | grep Temperature

# Adjust threshold
# scrutiny.yaml:
temperature_warning: 75  # Instead of 70
```

---

## Backup

```bash
# Database and config
./scrutiny/config/ → /mnt/usb-backup/backups/YYYYMMDD/scrutiny/

# Historical data is valuable for trend analysis
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Documentation created, Scrutiny v0.8.1 |
