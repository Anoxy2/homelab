# Cadvisor Container Metrics

> Container resource usage and performance analysis
> Prometheus metrics, per-container stats

---

## Overview

**Cadvisor** (Container Advisor) exports container metrics for Prometheus.

| Attribute | Value |
|-----------|-------|
| **Image** | `gcr.io/cadvisor/cadvisor:v0.52.1` |
| **Container** | cadvisor |
| **Port** | `192.168.2.101:8087` |
| **Metrics path** | `/metrics` |

---

## Configuration

### Docker Compose

```yaml
services:
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.52.1
    container_name: cadvisor
    ports:
      - "192.168.2.101:8087:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
    devices:
      - /dev/kmsg
```

---

## Metrics

### CPU

```
container_cpu_usage_seconds_total{container_label_com_docker_compose_service="grafana"}
container_cpu_system_seconds_total
container_cpu_user_seconds_total
```

### Memory

```
container_memory_usage_bytes{name="grafana"}
container_memory_working_set_bytes
container_memory_cache
container_memory_rss
container_memory_swap
```

### Network

```
container_network_receive_bytes_total{name="pihole"}
container_network_receive_packets_total
container_network_transmit_bytes_total
container_network_transmit_packets_total
```

### Disk I/O

```
container_fs_reads_bytes_total
container_fs_writes_bytes_total
container_fs_usage_bytes
container_fs_limit_bytes
```

### Processes

```
container_tasks_state{state="running"}
container_last_seen
container_start_time_seconds
```

---

## Prometheus Scraping

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['192.168.2.101:8087']
    metric_relabel_configs:
      # Drop unnecessary labels
      - regex: 'id|name'
        action: labeldrop
```

---

## PromQL Queries

```promql
# Container CPU percentage
rate(container_cpu_usage_seconds_total{name="grafana"}[5m]) * 100

# Memory usage %
container_memory_usage_bytes{name="grafana"} / container_spec_memory_limit_bytes * 100

# Network I/O by container
rate(container_network_receive_bytes_total[5m])
rate(container_network_transmit_bytes_total[5m])

# Top memory consumers
topk(10, container_memory_usage_bytes{name!=""})

# Container restart count
container_restarts_total

# Running containers count
count(container_last_seen)
```

---

## Web UI

Cadvisor provides a basic web interface:

```
http://192.168.2.101:8087/containers/
```

Shows per-container:
- CPU/Memory graphs
- Process list
- Resource limits
- Environment variables

---

## Troubleshooting

### No container metrics

```bash
# Check cadvisor is running
docker ps | grep cadvisor

# Check metrics endpoint
curl http://192.168.2.101:8087/metrics | head

# Check Docker socket access
docker exec cadvisor ls -la /var/run/docker.sock
```

### High CPU usage

Cadvisor can be resource intensive on large systems:

```yaml
# Limit housekeeping intervals
--housekeeping_interval=30s
--global_housekeeping_interval=1m
--disable_metrics=tcp,udp,sched,process
```

### Metrics missing labels

```promql
# Query with name filter
container_memory_usage_bytes{name=~".+"}

# Or relabel in Prometheus
metric_relabel_configs:
  - source_labels: [name]
    regex: '^$'
    action: drop
```

---

## Security Notes

- **Privileged container:** Required for full metrics access
- **Host filesystem mounted:** Read-only, but broad access
- **LAN-only:** No external exposure

---

## Backup

No persistent data. Configuration in `docker-compose.yml`.

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Documentation created, cAdvisor v0.52.1 |
