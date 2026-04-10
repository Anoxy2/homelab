# Capacity Planning

> Resource limits, scaling indicators, when to upgrade

---

## Current Resources

| Resource | Capacity | Used | Available |
|----------|----------|------|-----------|
| **CPU** | 4 cores @ 2.4GHz | ~30% avg | 70% |
| **RAM** | 8GB LPDDR4X | ~4GB | 4GB |
| **NVMe** | 1TB Crucial P3 | ~200GB | 800GB |
| **Network** | 1Gbps LAN | ~100Mbps | 900Mbps |

---

## Container Resource Limits

### Defined Limits

| Service | CPU Limit | Memory Limit |
|---------|-----------|--------------|
| Pi-hole | 0.50 | 512MB |
| Home Assistant | 1.50 | 800MB |
| InfluxDB | 1.00 | 512MB |
| Prometheus | 1.00 | 1GB |
| Grafana | 0.50 | 256MB |

### Unlimited (Default)

- Portainer
- Vaultwarden
- Tailscale
- Mosquitto
- Caddy

---

## Resource Monitoring

### Current Usage Check

```bash
# Container stats
docker stats --no-stream

# System resources
docker exec glances curl -s http://localhost:61208/api/4/all | jq '.cpu,.mem'

# Disk usage
df -h /
du -sh ./homeassistant/config ./influxdb/data ./prometheus_data
```

### Prometheus Queries

```promql
# High memory consumers
topk(10, container_memory_usage_bytes{name!=""})

# CPU throttling
rate(container_cpu_cfs_throttled_seconds_total[5m])

# Disk growth rate
rate(node_filesystem_avail_bytes{mountpoint="/"}[1d])
```

---

## Scaling Indicators

### ⚠️ Warning Thresholds

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| **CPU avg** | >50% | >80% | Add limits, optimize |
| **Memory** | >6GB | >7GB | Increase swap, prune |
| **Disk** | >70% | >85% | Clean logs, expand |
| **Load** | >2.0 | >3.5 | Check io wait |

### 📈 Growth Trends

| Service | Growth Rate | Projection |
|---------|-------------|------------|
| InfluxDB | ~2GB/month | Full in 3 years |
| Prometheus | ~500MB/month | Full in 5 years |
| Loki | ~1GB/month | Full in 4 years |
| Home Assistant | ~100MB/month | Long-term stable |

---

## Optimization Strategies

### 1. Reduce Retention

```yaml
# Prometheus
--storage.tsdb.retention.time=15d  # Was 30d

# InfluxDB
limits_config:
  retention_period: 168h  # 7 days

# Loki
limits_config:
  retention_period: 168h  # 7 days
```

### 2. Prune Old Data

```bash
# Home Assistant
# configuration.yaml
recorder:
  purge_keep_days: 3  # Was 7

# Docker
docker system prune -a --volumes

# Logs
find /var/log -name "*.log" -mtime +7 -delete
```

### 3. Move to External Storage

| Data | Current | Can Move To |
|------|---------|-------------|
| Media | NVMe | External USB |
| Backups | NVMe | USB Backup Stick |
| Old metrics | NVMe | Archive to NAS |

---

## Upgrade Decision Matrix

| Trigger | Current | Next Step | Cost |
|---------|---------|-----------|------|
| RAM >7GB used | 8GB | 16GB LPDDR5 | € |
| Disk >80% | 1TB NVMe | 2TB NVMe | €€ |
| CPU >80% | Pi 5 | Pi 6 (future) | €€ |
| Network saturated | 1Gbps | 2.5Gbps USB | € |

---

## Bottleneck Analysis

### Current Bottlenecks

| Bottleneck | Cause | Impact |
|------------|-------|--------|
| **I/O wait** | NVMe during heavy writes | Grafana slow queries |
| **Memory pressure** | InfluxDB + Prometheus | Occasional OOM kills |
| **SD card (if used)** | Slow I/O | Boot delays |

### Mitigations

```bash
# Reduce I/O priority for heavy writers
docker exec influxdb ionice -c 3 -p 1

# Add swap (if not present)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Tune NVMe
echo 'mq-deadline' | sudo tee /sys/block/nvme0n1/queue/scheduler
```

---

## Future Capacity

### Projected 1-Year Usage

| Resource | Current | Projected | Headroom |
|----------|---------|-----------|----------|
| NVMe | 200GB | 450GB | 550GB |
| Memory | 4GB | 5GB | 3GB |
| CPU | 30% | 40% | 60% |

**Verdict:** No upgrade needed within 1 year.

### Projected 2-Year Usage

| Resource | Projected | Risk |
|----------|-----------|------|
| NVMe | 700GB | 🟡 Medium |
| Memory | 6GB | 🟢 Low |
| CPU | 50% | 🟢 Low |

**Verdict:** Plan NVMe upgrade or data archival.

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Initial capacity assessment |
