# Loki / Promtail Logging Stack

> Log aggregation and querying
> Grafana integration, label-based indexing

---

## Overview

**Loki** collects logs from all containers. **Promtail** forwards Docker logs to Loki.

| Attribute | Value |
|-----------|-------|
| **Loki Image** | `grafana/loki:3.5.0` |
| **Promtail Image** | `grafana/promtail:3.5.0` |
| **Loki Port** | `192.168.2.101:3100` |
| **Storage** | Local filesystem |
| **Config** | `./loki/config/`, `./promtail/config/` |

---

## Architecture

```
Docker Containers
        ↓ (logs)
    Promtail
        ↓ (push)
    Loki (:3100)
        ↑ (query)
    Grafana (:3003)
```

---

## Configuration

### Docker Compose

```yaml
services:
  loki:
    image: grafana/loki:3.5.0
    container_name: loki
    ports:
      - "192.168.2.101:3100:3100"
    volumes:
      - ./loki/config/loki.yml:/etc/loki/loki.yml:ro
      - loki_data:/loki
    command: -config.file=/etc/loki/loki.yml

  promtail:
    image: grafana/promtail:3.5.0
    container_name: promtail
    volumes:
      - ./promtail/config/promtail.yml:/etc/promtail/promtail.yml:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /tmp:/tmp
    command: -config.file=/etc/promtail/promtail.yml
    depends_on:
      - loki
```

### loki.yml

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://alertmanager:9093

# Retention
limits_config:
  retention_period: 168h  # 7 days
  reject_old_samples: true
  reject_old_samples_max_age: 168h
```

### promtail.yml

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # Docker logs
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
        filters:
          - name: label
            values: ["com.centurylinklabs.watchtower.enable"]

    relabel_configs:
      # Use container name as label
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'
      
      # Use compose project
      - source_labels: ['__meta_docker_container_label_com_docker_compose_project']
        target_label: 'project'
      
      # Use compose service name
      - source_labels: ['__meta_docker_container_label_com_docker_compose_service']
        target_label: 'service'

  # System journal (optional)
  - job_name: journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
```

---

## Labels

Every log line has labels for filtering:

| Label | Example | Source |
|-------|---------|--------|
| `container` | `pihole` | Docker container name |
| `service` | `grafana` | Compose service name |
| `project` | `homelab` | Compose project |
| `stream` | `stdout` / `stderr` | Docker stream |
| `job` | `docker` | Promtail job |

---

## LogQL Query Language

### Basic Queries

```logql
# All logs from container
{container="pihole"}

# Multiple containers
{container=~"pihole|grafana|homeassistant"}

# Errors only
{container="pihole"} |= "error"

# Regex pattern
{container="grafana"} |~ "(error|ERROR|Error)"

# Exclude pattern
{container="homeassistant"} != "DEBUG"

# JSON parsing
{container="openclaw"} | json | line_format "{{.message}}"
```

### Aggregation

```logql
# Log rate
count_over_time({container="pihole"}[1m])

# Error rate by container
sum by (container) (count_over_time({container=~".+"} |~ "error" [5m]))

# Top containers by log volume
topk(10, sum by (container) (count_over_time({container=~".+"}[1h])))
```

### Time Ranges

```logql
# Last hour
{container="pihole"}[1h]

# Range query with aggregation
rate({container="pihole"}[5m])
```

---

## Grafana Integration

### Data Source

```yaml
# In Grafana UI or provisioning
apiVersion: 1
datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    jsonData:
      maxLines: 1000
      httpHeaderName1: X-Scope-OrgID
    secureJsonData:
      httpHeaderValue1: "1"
```

### Dashboard Panels

| Visualization | Query |
|---------------|-------|
| Logs | `{container="pihole"} ` |
| Error count | `sum(count_over_time({container=~".+"} |~ "error" [5m]))` |
| Log volume | `sum by (container) (count_over_time({container=~".+"}[5m]))` |
| Timeline | `{container=~"$container"} ` |

---

## API Reference

```bash
# Push logs (for custom apps)
curl -X POST http://192.168.2.101:3100/loki/api/v1/push \
  -H 'Content-Type: application/json' \
  -d '{
    "streams": [{
      "stream": {"app": "myapp"},
      "values": [["'$(( $(date +%s) * 1000000000 ))'", "log line"]]
    }]
  }'

# Query logs
curl 'http://192.168.2.101:3100/loki/api/v1/query_range?query=%7Bcontainer%3D%22pihole%22%7D&limit=100'

# Labels
curl http://192.168.2.101:3100/loki/api/v1/label/container/values
```

---

## Retention

```yaml
# loki.yml
limits_config:
  retention_period: 168h  # 7 days

# Or via compactor
compactor:
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
```

**Storage check:**
```bash
du -sh ./loki_data/
```

---

## Troubleshooting

### No logs appearing

```bash
# Check Promtail is scraping
curl http://192.168.2.101:9080/targets

# Check Docker socket access
docker exec promtail ls -la /var/run/docker.sock

# Check Loki is receiving
curl http://192.168.2.101:3100/ready
```

### High memory usage

```yaml
# Reduce chunk size in promtail
limits_config:
  per_stream_rate_limit: 1MB
  per_stream_rate_limit_burst: 5MB
```

### Logs out of order

```yaml
# Increase acceptable lag
limits_config:
  unordered_writes: true
```

---

## Backup

```bash
# Loki data (indices and chunks)
docker run --rm -v loki_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/loki-$(date +%Y%m%d).tar.gz -C /data .

# Configs are in Git
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Documentation created, Loki/Promtail 3.5.0 |
