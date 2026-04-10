# InfluxDB Time-Series Database

> High-performance time-series storage
> Home Assistant integration, long-term metrics

---

## Overview

**InfluxDB** stores time-series data from Home Assistant and other sources. Alternative/complement to Prometheus for long-term storage.

| Attribute | Value |
|-----------|-------|
| **Image** | `influxdb:2.7.12` |
| **Container** | influxdb |
| **Port** | `192.168.2.101:8086` |
| **Storage** | Local, configurable retention |
| **Config** | Environment variables |

---

## Configuration

### Docker Compose

```yaml
services:
  influxdb:
    image: influxdb:2.7.12
    container_name: influxdb
    ports:
      - "192.168.2.101:8086:8086"
    volumes:
      - ./influxdb/data:/var/lib/influxdb2
      - ./influxdb/config:/etc/influxdb2
    environment:
      DOCKER_INFLUXDB_INIT_USERNAME: "${INFLUXDB_ADMIN_USER:-admin}"
      DOCKER_INFLUXDB_INIT_PASSWORD: "${INFLUXDB_ADMIN_PASSWORD}"
      DOCKER_INFLUXDB_INIT_ORG: "${INFLUXDB_ORG:-pilab}"
      DOCKER_INFLUXDB_INIT_BUCKET: "${INFLUXDB_BUCKET:-homeassistant}"
      DOCKER_INFLUXDB_INIT_ADMIN_TOKEN: "${INFLUXDB_ADMIN_TOKEN}"
```

### Environment (.env)

```bash
INFLUXDB_ADMIN_USER=admin
INFLUXDB_ADMIN_PASSWORD=your-secure-password
INFLUXDB_ORG=pilab
INFLUXDB_BUCKET=homeassistant
INFLUXDB_ADMIN_TOKEN=your-long-token-here
```

### Token Generation

```bash
# First start only - token is auto-generated
# To create additional tokens:
docker exec influxdb influx auth create \
  --org pilab \
  --all-access \
  --description "Grafana token"
```

---

## Data Model

### Buckets (Databases)

| Bucket | Purpose |
|--------|---------|
| `homeassistant` | Home Assistant entities |
| `_monitoring` | System metrics (optional) |

### Measurements (Tables)

Home Assistant writes measurements per entity domain:
- `°C` (temperature sensors)
- `%` (humidity, battery)
- `W` (power)
- `kWh` (energy)
- `V` (voltage)
- `state` (binary sensors, switches)

### Schema

```
homeassistant/autogen
├── time (timestamp)
├── measurement (entity_id)
├── tags:
│   ├── domain (sensor, binary_sensor, etc.)
│   ├── entity_id (full entity ID)
│   ├── friendly_name
│   └── unit_of_measurement
└── fields:
    ├── value (float/string)
    └── value_str (string backup)
```

---

## Query Language (Flux)

### Basic Queries

```flux
// Temperature last hour
from(bucket: "homeassistant")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "°C")
  |> filter(fn: (r) => r.entity_id == "growbox_temperature")
  |> aggregateWindow(every: 5m, fn: mean)

// Multiple sensors
from(bucket: "homeassistant")
  |> range(start: -24h)
  |> filter(fn: (r) => r.domain == "sensor")
  |> filter(fn: (r) => r._field == "value")
  |> group(columns: ["entity_id"])

// Aggregate statistics
from(bucket: "homeassistant")
  |> range(start: -7d)
  |> filter(fn: (r) => r.entity_id == "growbox_temperature")
  |> window(every: 1d)
  |> mean()
```

### InfluxQL (Legacy)

```sql
-- For 1.x compatibility
SELECT mean("value") FROM "homeassistant"."autogen"."°C" 
WHERE time > now() - 1h 
GROUP BY time(5m)
```

---

## Home Assistant Integration

### Configuration

```yaml
# configuration.yaml
influxdb:
  host: 192.168.2.101
  port: 8086
  token: !secret influxdb_token
  organization: pilab
  bucket: homeassistant
  ssl: false
  verify_ssl: false
  
  # What to include
  include:
    entities:
      - sensor.growbox_temperature
      - sensor.growbox_humidity
      - sensor.growbox_co2
      - binary_sensor.growbox_light
      
  # Or domains
  include:
    domains:
      - sensor
      - binary_sensor
      - switch
      
  # Exclude specific entities
  exclude:
    entities:
      - sensor.time
      - sensor.date
```

---

## Grafana Integration

### Data Source

```yaml
apiVersion: 1
datasources:
  - name: InfluxDB
    type: influxdb
    access: proxy
    url: http://192.168.2.101:8086
    jsonData:
      version: Flux
      organization: pilab
      defaultBucket: homeassistant
      tlsSkipVerify: true
    secureJsonData:
      token: ${INFLUXDB_ADMIN_TOKEN}
```

### Dashboard Queries

```flux
// Growbox dashboard
from(bucket: "homeassistant")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "°C" or r._measurement == "%")
  |> filter(fn: (r) => r.entity_id =~ /growbox/)
  |> aggregateWindow(every: v.windowPeriod, fn: mean)
```

---

## Retention Policies

```bash
# Create retention policy
docker exec influxdb influx bucket create \
  --name homeassistant_30d \
  --org pilab \
  --retention 30d

# Or via API
curl -X POST http://192.168.2.101:8086/api/v2/buckets \
  -H "Authorization: Token ${TOKEN}" \
  -d '{
    "orgID": "...",
    "name": "short_term",
    "retentionRules": [{"everySeconds": 2592000}]
  }'
```

---

## Backup

```bash
# Full backup
docker exec influxdb influx backup /backup/$(date +%Y%m%d)

# Or file-level
docker run --rm -v influxdb_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/influxdb-$(date +%Y%m%d).tar.gz -C /data .

# Continuous backup to S3 (optional)
bucket = "s3://my-bucket/influxdb"
```

---

## Troubleshooting

### "Unauthorized"

```bash
# Check token
docker exec influxdb influx auth list

# Generate new token
docker exec influxdb influx auth create --org pilab --all-access
```

### High memory usage

```yaml
# Reduce cache sizes
query-memory-bytes: 100000000  # 100MB
query-queue-size: 10
```

### Data not appearing

```bash
# Check HA connection
# Home Assistant logs
docker logs homeassistant | grep influxdb

# Check write permissions
docker exec influxdb influx write --bucket homeassistant \
  --token ${TOKEN} \
  "test value=1"
```

### Database corruption

```bash
# Check engine
docker exec influxdb influxd engine

# If corrupted, restore from backup
```

---

## API Reference

```bash
# Health
curl http://192.168.2.101:8086/health

# Query
curl -X POST http://192.168.2.101:8086/api/v2/query?org=pilab \
  -H "Authorization: Token ${TOKEN}" \
  -H "Content-Type: application/vnd.flux" \
  --data 'from(bucket:"homeassistant") |> range(start:-1h)'

# Write
curl -X POST http://192.168.2.101:8086/api/v2/write?org=pilab&bucket=homeassistant \
  -H "Authorization: Token ${TOKEN}" \
  --data-binary "measurement,tag=value field=1.0"
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Documentation created, InfluxDB 2.7.12 |
