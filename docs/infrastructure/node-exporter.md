# Node Exporter System Metrics

> Hardware and OS metrics for Prometheus
> CPU, memory, disk, network statistics

---

## Overview

**Node Exporter** exposes Linux system metrics for Prometheus scraping.

| Attribute | Value |
|-----------|-------|
| **Image** | `prom/node-exporter:v1.11.0` |
| **Container** | node-exporter |
| **Port** | `9100` (Host mode) |
| **Metrics** | `/metrics` |

---

## Configuration

### Docker Compose

```yaml
services:
  node-exporter:
    image: prom/node-exporter:v1.11.0
    container_name: node-exporter
    network_mode: host
    pid: host
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
```

---

## Metrics

### CPU

```
# CPU time per mode (user, system, idle, iowait)
node_cpu_seconds_total{cpu="0",mode="idle"}

# Load averages
node_load1
node_load5
node_load15

# Context switches
node_context_switches_total
```

### Memory

```
# Bytes
cnode_memory_MemTotal_bytes
node_memory_MemAvailable_bytes
node_memory_Buffers_bytes
node_memory_Cached_bytes
node_memory_SwapTotal_bytes
node_memory_SwapFree_bytes

# Pages
node_memory_Active_anon_bytes
node_memory_Inactive_anon_bytes
```

### Disk

```
# Space
node_filesystem_size_bytes{mountpoint="/"}
node_filesystem_avail_bytes{mountpoint="/"}
node_filesystem_used_bytes{mountpoint="/"}

# I/O
node_disk_io_time_seconds_total{device="nvme0n1"}
node_disk_read_bytes_total{device="nvme0n1"}
node_disk_written_bytes_total{device="nvme0n1"}
node_disk_reads_completed_total{device="nvme0n1"}
```

### Network

```
node_network_receive_bytes_total{device="eth0"}
node_network_transmit_bytes_total{device="eth0"}
node_network_receive_packets_total{device="eth0"}
node_network_receive_errs_total{device="eth0"}
```

### System

```
# Boot time
node_boot_time_seconds

# Processes
node_procs_running
node_procs_blocked
node_processes_max_processes

# File descriptors
node_filefd_allocated
```

### Temperature

```
node_hwmon_temp_celsius{chip="thermal_zone0",sensor="temp1"}
```

---

## PromQL Queries

```promql
# CPU usage % (all cores)
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Per-core CPU
100 - (irate(node_cpu_seconds_total{mode="idle"}[5m]) * 100)

# Memory available %
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100

# Disk usage %
100 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100)

# Network traffic rate
rate(node_network_receive_bytes_total{device="eth0"}[5m])
rate(node_network_transmit_bytes_total{device="eth0"}[5m])

# System temperature
node_hwmon_temp_celsius{chip="thermal_zone0"}
```

---

## Textfile Collector

Custom metrics via text files:

```bash
# Write to /var/lib/node_exporter/textfile/
echo "custom_metric{label=\"value\"} 42" > /var/lib/node_exporter/textfile/my_metric.prom

# Mount in compose
volumes:
  - /var/lib/node_exporter/textfile:/var/lib/node_exporter/textfile:ro
```

---

## Collector Flags

```yaml
command:
  - '--collector.disable-defaults'
  - '--collector.cpu'
  - '--collector.meminfo'
  - '--collector.filesystem'
  - '--collector.loadavg'
  - '--collector.time'
  # Disable collectors
  - '--no-collector.wifi'
  - '--no-collector.hwmon'
```

---

## Troubleshooting

### Metrics missing

```bash
# Check endpoint
curl http://192.168.2.101:9100/metrics | head

# Check container logs
docker logs node-exporter

# Verify host mounts
docker exec node-exporter ls -la /host/proc
```

### Permission errors

```bash
# Host PID namespace required
# Check docker-compose.yml has: pid: host

# AppArmor/SELinux may block access
# Check dmesg for denials
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Documentation created, Node Exporter v1.11.0 |
