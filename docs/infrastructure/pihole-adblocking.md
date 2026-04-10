# Pi-hole DNS & Ad-Blocking

> Network-wide ad-blocking and DNS management
> DHCP server, local DNS records, query logging

---

## Overview

**Pi-hole** is the DNS resolver and ad-blocker for the entire homelab network.

| Attribute | Value |
|-----------|-------|
| **Image** | `pihole/pihole:2026.04.0` |
| **Container** | pihole |
| **DNS Port** | `53` (Host mode) |
| **Web Port** | `8080` (Host mode, FTLCONF_webserver_port) |
| **Interface** | `end0` (Host mode, FTLCONF_dns_interface) |
| **Config** | `./pihole/config/` |

---

## Architecture

```
LAN Clients (192.168.2.x)
    ↓ DNS queries
Pi-hole (:53)
    ├──→ Blocklists (ads, trackers)
    ├──→ Local DNS records (*.lan)
    └──→ Upstream (Unbound :5335)
            ↓
        Root DNS servers
```

---

## Configuration

### Docker Compose

```yaml
services:
  pihole:
    image: pihole/pihole:2026.04.0
    container_name: pihole
    network_mode: host
    env_file: .env
    environment:
      FTLCONF_webserver_port: "8080"
      FTLCONF_dns_interface: "end0"
    cap_add:
      - NET_ADMIN
      - NET_BIND_SERVICE
      - SYS_NICE
    volumes:
      - ./pihole/config:/etc/pihole
    healthcheck:
      test: ["CMD", "dig", "+short", "pi.hole", "@127.0.0.1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    cpus: '0.50'
    mem_limit: 512m
    restart: unless-stopped
```

### Environment (.env)

```bash
# Web admin password
WEBPASSWORD=your-secure-admin-password

# Optional: Pre-configure upstream
# PIHOLE_DNS_1=192.168.2.101#5335  # Unbound
```

---

## Web Admin Interface

```
http://pihole.lan:8080/admin
```

### Dashboard Sections

| Section | Purpose |
|---------|---------|
| **Dashboard** | Query stats, blocked %, top domains |
| **Query Log** | Live DNS queries |
| **Whitelist/Blacklist** | Domain management |
| **Group Management** | Client groups |
| **Adlists** | Blocklist sources |
| **DNS Records** | Local A/AAAA/CNAME records |
| **DHCP** | DHCP server settings |
| **Settings** | Advanced configuration |

---

## Blocklists (Adlists)

### Default Lists

```
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://mirror1.malwaredomains.com/files/justdomains
http://sysctl.org/cameleon/hosts
https://zeustracker.abuse.ch/blocklist.php?download=domainblocklist
https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt
https://hosts-file.net/ad_servers.txt
```

### Custom Lists (German-focused)

```
https://raw.githubusercontent.com/RPiList/specials/master/Blocklisten/notserious
https://raw.githubusercontent.com/RPiList/specials/master/Blocklisten/DomainSquatting
https://raw.githubusercontent.com/RPiList/specials/master/Blocklisten/Streaming
```

### Update Lists

```bash
# Via web UI
# Tools → Update Gravity

# Or CLI
docker exec pihole pihole -g
```

---

## Local DNS Records

### A Records (LAN Hosts)

```
Pi-hole Admin → Local DNS → DNS Records

192.168.2.101    pihole.lan
192.168.2.101    home.lan
192.168.2.101    dashboard.lan
192.168.2.101    vault.lan
192.168.2.101    grafana.lan
192.168.2.101    portainer.lan
192.168.2.101    homeassistant.lan
192.168.2.101    hass.lan
192.168.2.101    esphome.lan
192.168.2.101    openclaw.lan
192.168.2.101    ops.lan
192.168.2.101    search.lan
192.168.2.101    auth.lan
192.168.2.101    ntfy.lan
192.168.2.101    scrutiny.lan
192.168.2.101    prometheus.lan
192.168.2.101    alertmanager.lan
192.168.2.101    loki.lan
```

### CNAME Records

```
# Aliases
home.lan → CNAME → dashboard.lan
mqtt.lan → CNAME → mosquitto.lan
```

---

## DHCP Server

### Enable DHCP

```
Settings → DHCP
✓ DHCP server enabled
Router (gateway) IP: 192.168.2.1
DHCP range: 192.168.2.100 - 192.168.2.199
Domain: lan
```

### Static Leases

```
Settings → DHCP → Static Leases

MAC: aa:bb:cc:dd:ee:ff → IP: 192.168.2.50 → Hostname: printer
```

### Client Groups

```
Group Management:
- Default (all clients)
- Kids (restricted)
- IoT (minimal)
```

---

## DNS Upstream

### Unbound Integration

```
Settings → DNS → Upstream DNS Servers

Custom 1: 192.168.2.101#5335  (Unbound)
Custom 2: 1.1.1.1            (Cloudflare fallback)
Custom 3: 8.8.8.8            (Google fallback)
```

### DNSSEC

```
Settings → DNS → Advanced DNS settings
✓ Use DNSSEC
```

---

## Query Log Analysis

### CLI

```bash
# Recent queries
docker exec pihole tail -f /var/log/pihole/pihole.log

# Blocked only
docker exec pihole tail -f /var/log/pihole/pihole.log | grep blocked

# Statistics
docker exec pihole pihole -c
```

### Web Filters

| Filter | Shows |
|--------|-------|
| **All** | Every query |
| **Allowed** | Forwarded queries |
| **Blocked** | Blocked domains |
| **Client** | Per-device queries |

---

## Whitelist/Blacklist

### Exact Match

```
Blacklist → Exact
Domain: tracking.example.com
```

### Regex

```
Blacklist → Regex
Pattern: (\.|^)ads\.
Comment: Block all *.ads.* domains
```

### Wildcard

```
Whitelist → Wildcard
Pattern: *.example.com
```

---

## Teleporter (Backup/Restore)

### Backup

```
Settings → Teleporter → Backup
# Downloads: pi-hole-pihole-YYYY-MM-DD-time.tar.gz
```

### Restore

```
Settings → Teleporter → Restore
# Upload backup file
```

---

## Troubleshooting

### "DNS_PROBE_FINISHED_NXDOMAIN"

```bash
# Check Pi-hole is responding
dig @192.168.2.101 google.com

# Check upstream
dig @192.168.2.101 -p 5335 google.com

# Restart FTL
docker exec pihole pihole restartdns
```

### High CPU/Memory

```bash
# Check query volume
docker exec pihole pihole -c

# Check blocklist count
docker exec pihole wc -l /etc/pihole/gravity.db

# Reduce lists or enable rate limiting
```

### Clients bypassing Pi-hole

```bash
# Check router DNS settings
# Router should only advertise Pi-hole (192.168.2.101)

# Force all DNS through Pi-hole (firewall rule)
iptables -t nat -A PREROUTING -p udp --dport 53 ! -s 192.168.2.101 -j REDIRECT --to-port 53
```

### Gravity update fails

```bash
# Manual update
docker exec pihole pihole -g

# Check list accessibility
curl -I https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts

# Disable problematic lists temporarily
```

---

## API

```bash
# Stats
curl "http://192.168.2.101:8080/admin/api.php?status"

# Auth required
curl "http://192.168.2.101:8080/admin/api.php?getAllQueries&auth=API_TOKEN"

# Top domains
curl "http://192.168.2.101:8080/admin/api.php?topItems=10&auth=TOKEN"

# Enable/disable
curl -X POST "http://192.168.2.101:8080/admin/api.php?disable=300&auth=TOKEN"
```

---

## Backup

```bash
# Config (Teleporter format)
docker exec pihole pihole -a -t

# Or file-level
./pihole/config/ → /mnt/usb-backup/backups/YYYYMMDD/pihole/
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Documentation created, Pi-hole 2026.04.0 |
