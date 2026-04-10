# Service Dependencies & Start Order

> Critical startup sequence and service dependencies
> What needs what, restart impact analysis

---

## Startup Sequence

```
Phase 1: Infrastructure
├── Network (host interfaces)
└── Storage (NVMe mounted)

Phase 2: Core Services (parallel)
├── Pi-hole (DNS/DHCP)
├── Mosquitto (MQTT)
└── Caddy (reverse proxy)

Phase 3: Monitoring
├── Prometheus
├── Node Exporter
├── Cadvisor
└── Scrutiny

Phase 4: Data & Apps
├── InfluxDB
├── Loki
├── Grafana
├── Home Assistant
├── Vaultwarden
└── Portainer

Phase 5: Utilities
├── Homepage
├── Uptime Kuma
├── Tailscale
└── Watchtower
```

---

## Dependency Matrix

| Service | Depends On | Required By | Restart Impact |
|---------|------------|-------------|----------------|
| **Pi-hole** | Network | Entire LAN | 🔴 **CRITICAL** - DNS down |
| **Mosquitto** | Network | HA, ESPhome, OpenClaw | 🔴 **HIGH** - IoT offline |
| **Caddy** | Network | All web UIs | 🟡 **MEDIUM** - URLs broken |
| **Tailscale** | Network | Remote access | 🟡 **MEDIUM** - VPN down |
| **Prometheus** | Cadvisor, Node Exporter | Grafana | 🟢 **LOW** - metrics gap |
| **Grafana** | Prometheus, InfluxDB, Loki | Dashboards | 🟢 **LOW** - visualization only |
| **Home Assistant** | MQTT, InfluxDB | Automations | 🟡 **MEDIUM** - automations fail |
| **Vaultwarden** | - | Password access | 🟡 **MEDIUM** - passwords unavailable |
| **InfluxDB** | - | HA, Grafana | 🟢 **LOW** - metrics only |
| **Loki** | - | Grafana | 🟢 **LOW** - logs only |

---

## Restart Impact Analysis

### 🔴 CRITICAL - Stop Everything

| Service | Why |
|---------|-----|
| Pi-hole | DNS for entire LAN. All devices lose internet. |
| Mosquitto | IoT devices can't report/control. Automations fail. |

### 🟡 HIGH - Scheduled Maintenance Window

| Service | Why |
|---------|-----|
| Home Assistant | Smart home automations stop. Climate/lighting affected. |
| Vaultwarden | Password access lost. Browser extensions fail. |
| Caddy | All LAN URLs broken. Manual IP access required. |

### 🟢 LOW - Anytime

| Service | Why |
|---------|-----|
| Grafana | Dashboards unavailable. Core services unaffected. |
| Prometheus | Metrics collection gap. No immediate impact. |
| Uptime Kuma | External monitoring gap. Notifications may miss. |
| Watchtower | Update checks stop. No operational impact. |

---

## Safe Restart Procedures

### Pi-hole (CRITICAL)

```bash
# 1. Schedule maintenance window
# 2. Notify users (if any)
# 3. Set short TTL beforehand (if changing DNS)
# 4. Restart
docker compose restart pihole
# 5. Verify DNS immediately
dig @192.168.2.101 google.com
```

### Mosquitto (HIGH)

```bash
# 1. Check HA automations
curl http://192.168.2.101:8123/api/states | grep -c "unavailable"
# 2. Restart during low-activity period (night)
docker compose restart mosquitto
# 3. Verify MQTT connection from HA
```

### Home Assistant (HIGH)

```bash
# 1. Check growbox status (critical)
# 2. Restart
docker compose restart homeassistant
# 3. Verify automations loaded
curl http://192.168.2.101:8123/api/states | grep automation
# 4. Check growbox sensors responding
```

---

## Circular Dependencies

```
Home Assistant ──→ InfluxDB (stores metrics)
       ↑                  │
       └──────────────────┘ (Grafana queries both)
```

**Resolution:** InfluxDB has no hard dependency on HA. Can restart independently.

---

## Health Check Order

After full system restart, verify in order:

```bash
#!/bin/bash
# health-check.sh

echo "=== Phase 1: Core Infrastructure ==="
docker ps | grep -E "(pihole|mosquitto|caddy)" || exit 1
dig +short @192.168.2.101 google.com || exit 1

echo "=== Phase 2: Monitoring ==="
curl -sf http://192.168.2.101:9090/-/healthy || exit 1
curl -sf http://192.168.2.101:3003/api/health || exit 1

echo "=== Phase 3: Applications ==="
curl -sf http://192.168.2.101:8123 || exit 1
curl -sf http://192.168.2.101:8888/api/accounts/prelogin || exit 1

echo "=== All services healthy ==="
```

---

## Resource Conflicts

| Conflict | Services | Resolution |
|----------|----------|------------|
| **Port 53** | Pi-hole only | Exclusive bind |
| **Port 1883** | Mosquitto only | Exclusive bind |
| **Port 80** | Caddy only | Exclusive bind |
| **/dev/nvme0** | Scrutiny + SMART tools | Concurrent read OK |
| **Docker socket** | Portainer, Watchtower, Cadvisor | No conflicts |

---

## Restart Commands by Priority

```bash
# CRITICAL - Use with caution
docker compose restart pihole    # DNS down during restart
docker compose restart mosquitto # MQTT down

# HIGH - Schedule maintenance
docker compose restart homeassistant
docker compose restart vaultwarden
docker compose restart caddy

# LOW - Anytime
docker compose restart grafana
docker compose restart prometheus
docker compose restart uptime-kuma
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Initial dependency map created |
