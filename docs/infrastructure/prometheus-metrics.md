# Prometheus Metrics Collection

> Time-series metrics collection for the monitoring stack
> Scrapes targets, stores data, provides query API

---

## Overview

**Prometheus** collects metrics from all services in the stack. Data is stored locally and queried by Grafana.

| Attribute | Value |
|-----------|-------|
| **Image** | `prom/prometheus:v3.11.0` |
| **Container** | prometheus |
| **Port** | `192.168.2.101:9090` |
| **Storage** | 30d retention, local TSDB |
| **Config** | `./prometheus/prometheus.yml` |

---

## Architecture

```
Prometheus (:9090)
    │
    ├──→ node-exporter (:9100) ──→ System metrics
    ├──→ cadvisor (:8087) ───────→ Container metrics  
    ├──→ pihole-exporter (internal)
    └──→ mqtt-exporter (internal)

    ↓
Grafana (:3003) queries via PromQL
```

---

## Configuration

### Docker Compose

```yaml
services:
  prometheus:
    image: prom/prometheus:v3.11.0
    container_name: prometheus
    ports:
      - "192.168.2.101:9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
```

### prometheus.yml

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: pilab
    replica: '1'

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - /etc/prometheus/rules/*.yml

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter (system metrics)
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['192.168.2.101:9100']

  # Cadvisor (Docker metrics)
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['192.168.2.101:8087']

  # Pi-hole
  - job_name: 'pihole'
    static_configs:
      - targets: ['pihole-exporter:9617']
    metrics_path: /metrics

  # Home Assistant (if enabled)
  - job_name: 'homeassistant'
    scrape_interval: 60s
    metrics_path: /api/prometheus
    bearer_token: '${HASS_PROMETHEUS_TOKEN}'
    static_configs:
      - targets: ['192.168.2.101:8123']

  # Custom application endpoints
  - job_name: 'openclaw'
    static_configs:
      - targets: ['192.168.2.101:18789']
    metrics_path: /metrics
```

---

## Storage

| Setting | Value | Description |
|---------|-------|-------------|
| `retention.time` | 30d | How long to keep data |
| `retention.size` | 0 (unlimited) | Max storage size |
| `path` | /prometheus | Data directory |

**Volume usage:**
```bash
docker exec prometheus du -sh /prometheus
```

---

## Key Metrics

### System (node-exporter)

| Metric | Description |
|--------|-------------|
| `node_cpu_seconds_total` | CPU usage per mode |
| `node_memory_MemAvailable_bytes` | Available memory |
| `node_filesystem_avail_bytes` | Disk space available |
| `node_network_receive_bytes_total` | Network RX |
| `node_load1` | 1m load average |

### Containers (cadvisor)

| Metric | Description |
|--------|-------------|
| `container_cpu_usage_seconds_total` | Container CPU usage |
| `container_memory_usage_bytes` | Container memory |
| `container_network_receive_bytes_total` | Container network RX |
| `container_fs_usage_bytes` | Container filesystem usage |

### Custom Application Metrics

Applications can expose `/metrics` endpoint in Prometheus format:

```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",path="/api",status="200"} 1027
http_requests_total{method="POST",path="/api",status="500"} 3

# HELP request_duration_seconds Request duration
# TYPE request_duration_seconds histogram
request_duration_seconds_bucket{le="0.1"} 900
request_duration_seconds_bucket{le="0.5"} 950
request_duration_seconds_bucket{le="+Inf"} 1000
```

---

## PromQL Reference

### Basic Queries

```promql
# CPU usage percentage
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage percentage
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))

# Disk usage percentage
100 * (1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}))

# Container memory by name
container_memory_usage_bytes{name!=""}

# Top 10 containers by CPU
topk(10, rate(container_cpu_usage_seconds_total[5m]))
```

### Aggregation

```promql
# Sum by label
sum by (name) (container_memory_usage_bytes)

# Rate of change
rate(container_cpu_usage_seconds_total[5m])

# Irate (for fast counters)
irate(node_cpu_seconds_total[5m])
```

---

## Alerting Rules

```yaml
# prometheus/rules/alerts.yml
groups:
  - name: system
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: High CPU usage on {{ $labels.instance }}
          
      - alert: LowDiskSpace
        expr: node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} < 0.1
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: Low disk space on root partition
          
      - alert: ContainerDown
        expr: up{job="cadvisor"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: Container metrics collection down
```

---

## API Access

```bash
# Query metrics
curl 'http://192.168.2.101:9090/api/v1/query?query=up'

# Query range
curl 'http://192.168.2.101:9090/api/v1/query_range?query=node_load1&start=2024-01-01T00:00:00Z&end=2024-01-02T00:00:00Z&step=1h'

# List targets
curl http://192.168.2.101:9090/api/v1/targets

# Reload config
curl -X POST http://192.168.2.101:9090/-/reload
```

---

## Troubleshooting

### Target down

```bash
# Check endpoint manually
curl http://192.168.2.101:9100/metrics

# Check prometheus targets page
open http://192.168.2.101:9090/targets

# Check logs
docker logs prometheus --tail 100
```

### High memory usage

```bash
# Check TSDB stats
curl http://192.168.2.101:9090/api/v1/status/tsdb

# Reduce retention
--storage.tsdb.retention.time=15d

# Enable compaction
--storage.tsdb.min-block-duration=2h
```

### Data gaps

```bash
# Check scrape duration
curl 'http://192.168.2.101:9090/api/v1/query?query=prometheus_target_interval_length_seconds'

# Increase scrape timeout
global:
  scrape_timeout: 30s
```

---

## Backup

Data is in Docker volume `prometheus_data`. Back up via:

```bash
# Snapshot
docker run --rm -v prometheus_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/prometheus-$(date +%Y%m%d).tar.gz -C /data .

# Or via USB backup (if volume mapped)
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Documentation created, v3.11.0 |
