# Netzwerk & Firewall-Konfiguration

> Alle Netzwerk-Settings, Ports, Firewall-Regeln für Steges' Homelab  
> Stand: April 2026

---

## Netzwerk-Übersicht

### IP-Adressierung

| Interface | IP-Adresse | Netzwerk | Beschreibung |
|-----------|------------|----------|--------------|
| **eth0** | 192.168.2.101/24 | 192.168.2.0/24 | Haupt-LAN |
| **wlan0** | (optional) | - | WiFi (nicht aktiv) |
| **tailscale0** | 100.x.x.x | 100.64.0.0/10 | Tailscale VPN |
| **docker0** | 172.17.0.1/16 | 172.17.0.0/16 | Docker Bridge |
| **br-*** | 172.18-31.x.x | 172.18-31.0.0/16 | Docker Compose Networks |
| **lo** | 127.0.0.1 | - | Loopback |

### Gateway & DNS

| Parameter | Wert |
|-----------|------|
| **Default Gateway** | 192.168.2.1 |
| **DNS Server** | 192.168.2.1 (Router) / 127.0.0.1 (Pi-hole) |
| **Domain** | lan.local |
| **Hostname** | steges-pi |

### Netplan-Konfiguration

```yaml
# /etc/netplan/50-cloud-init.yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      dhcp6: false
      nameservers:
        addresses: [127.0.0.1, 192.168.2.1]
```

---

## UFW (Uncomplicated Firewall)

### Status

```bash
$ sudo ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip
```

### Aktive Regeln

| Nr | To | Action | From | Beschreibung |
|----|-----|--------|------|--------------|
| 1 | 22/tcp | ALLOW IN | Anywhere | SSH |
| 2 | 80/tcp | ALLOW IN | Anywhere | HTTP (Caddy) |
| 3 | 443/tcp | ALLOW IN | Anywhere | HTTPS (Caddy) |
| 4 | 53 | ALLOW IN | Anywhere | DNS (Pi-hole) |
| 5 | 18789/tcp | ALLOW IN | 192.168.2.0/24 | OpenClaw Gateway |
| 6 | 8090/tcp | ALLOW IN | 192.168.2.0/24 | OpenClaw UI |
| 7 | 3000/tcp | ALLOW IN | 192.168.2.0/24 | Grafana |
| 8 | 9090/tcp | ALLOW IN | 192.168.2.0/24 | Prometheus |
| 9 | 8123/tcp | ALLOW IN | 192.168.2.0/24 | Home Assistant |
| 10 | 1883/tcp | ALLOW IN | 192.168.2.0/24 | MQTT (Mosquitto) |

### UFW Konfiguration

```bash
# /etc/ufw/ufw.conf
ENABLED=yes
LOGLEVEL=low
MANAGE_BUILTINS=no
IPV6=yes
```

### Application Profiles

```bash
$ ls /etc/ufw/applications.d/
caddy    docker    openssh    pihole    prometheus
```

### Häufige Befehle

```bash
# Status
sudo ufw status numbered

# Regel hinzufügen
sudo ufw allow from 192.168.2.0/24 to any port 18789 proto tcp comment 'OpenClaw Gateway'

# Regel löschen
sudo ufw delete 5

# Temporär deaktivieren (mit Timer)
sudo ufw disable && sleep 300 && sudo ufw enable

# Log-Level ändern
sudo ufw logging medium
```

---

## Offene Ports (System-wide)

### SSH / Management

| Port | Service | Protokoll | Beschreibung |
|------|---------|-----------|--------------|
| 22 | sshd | TCP | SSH Zugriff |

### Web-Services (Caddy)

| Port | Service | Protokoll | Beschreibung |
|------|---------|-----------|--------------|
| 80 | caddy | TCP | HTTP (redirect zu HTTPS) |
| 443 | caddy | TCP | HTTPS |

### Docker-Exposed Ports

| Container | Host-Port | Container-Port | Beschreibung |
|-----------|-----------|----------------|--------------|
| **caddy** | 80 | 80 | Reverse Proxy |
| **caddy** | 443 | 443 | HTTPS |
| **pihole** | 53 | 53/udp | DNS |
| **pihole** | 53 | 53/tcp | DNS |
| **pihole** | 8081 | 80 | Pi-hole Web |
| **grafana** | 3000 | 3000 | Dashboards |
| **prometheus** | 9090 | 9090 | Metrics |
| **homeassistant** | 8123 | 8123 | Smart Home |
| **mosquitto** | 1883 | 1883 | MQTT |
| **vaultwarden** | 8082 | 80 | Password Manager |
| **openclaw** | 18789 | 18789 | AI Gateway |
| **openclaw** | 8090 | 8090 | Web UI |
| **ntfy** | 8083 | 80 | Push Notifications |
| **searxng** | 8084 | 8080 | Search Engine |

### Interne Ports (Docker-only)

| Port | Container | Beschreibung |
|------|-----------|--------------|
| 3100 | loki | Log aggregation |
| 9093 | alertmanager | Alert routing |
| 9100 | node-exporter | System metrics |

---

## Docker-Netzwerke

```bash
$ docker network ls
NETWORK ID     NAME              DRIVER    SCOPE
abc123def456   bridge            bridge    local
xyz789uvw012   caddy-net           bridge    local
...
```

### Caddy-Netzwerk

```yaml
# docker-compose.yml excerpt
networks:
  caddy-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

---

## Port-Forwarding (Router)

Extern → Intern (192.168.2.101):

| Extern | Intern | Protokoll | Beschreibung |
|--------|--------|-----------|--------------|
| 443 | 443 | TCP | HTTPS (Caddy) |
| 80 | 80 | TCP | HTTP (Caddy) |
| 8123 | 8123 | TCP | Home Assistant (optional) |

---

## Monitoring

### Aktive Verbindungen

```bash
$ ss -tn | wc -l
91

$ ss -tlnp | head -20
State    Recv-Q   Send-Q     Local Address:Port     Peer Address:Port  Process
LISTEN   0        4096       0.0.0.0:22             0.0.0.0:*          users:(("sshd",pid=616,fd=3))
LISTEN   0        4096       0.0.0.0:53             0.0.0.0:*          users:(("pihole-FTL",pid=371493,fd=23))
...
```

### Bandbreiten-Monitoring

```bash
# Realtime
iftop -i eth0

# Statistik
vnstat -i eth0
```

---

## Sicherheit

### Best Practices (angewendet)

- ✅ SSH nur auf Port 22, Key-Auth
- ✅ UFW aktiviert, default deny incoming
- ✅ Docker-Ports nur auf localhost/192.168.2.0/24 gebunden
- ✅ Pi-hole als DNS-Filter
- ✅ Keine direkten Admin-Ports (22, 18789) nach extern exposed
- ✅ Caddy als Reverse Proxy mit automatischem HTTPS

### Zu überprüfende Regeln

```bash
# UFW vollständig
sudo ufw status verbose

# IPTables direkt
sudo iptables -L -n -v | head -50

# NAT-Regeln
sudo iptables -t nat -L -n -v
```

---

## Troubleshooting

### Verbindung testen

```bash
# Port erreichbar?
nc -zv 192.168.2.101 18789

# Von extern
curl -I https://steges.duckdns.org

# DNS-Test
dig @192.168.2.101 google.com
```

### Log-Analyse

```bash
# UFW-Logs
sudo tail -f /var/log/ufw.log

# Auth-Failures
sudo grep "Failed password" /var/log/auth.log

# Docker-Logs
docker logs caddy | tail -50
```

---

## Referenzen

- `docker-compose.yml` – Port-Mappings
- `systemd/` – Service-Configs
- `scripts/health-check.sh` – Port-Checks
