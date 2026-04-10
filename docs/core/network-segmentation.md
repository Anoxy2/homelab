# Network Segmentation Strategy

> VLAN isolation, security zones, access control
> Future-proofing for IoT security

---

## Current State

```
Flat Network: 192.168.2.0/24
├── PiLab (Pi + containers)
├── Trusted devices (laptops, phones)
├── IoT devices (ESP32, sensors)
└── Guest devices (if any)
```

**Status:** Single flat network. All devices can communicate freely.

---

## Proposed Segmentation

```
┌─────────────────────────────────────────────────────────┐
│                      TRUSTED (VLAN 10)                  │
│  Admin laptops, phones, workstations                    │
│  192.168.10.0/24                                        │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                       DMZ (VLAN 20)                     │
│  PiLab (Pi-hole, HA, Vaultwarden, Grafana)             │
│  192.168.20.0/24                                        │
│  ← Internet gateway for other VLANs                     │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                       IOT (VLAN 30)                     │
│  ESP32 sensors, smart plugs, cameras                    │
│  192.168.30.0/24                                        │
│  → Internet blocked, HA access only                     │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                      GUEST (VLAN 40)                    │
│  Visitor devices, untrusted                             │
│  192.168.40.0/24                                        │
│  → Internet only, no LAN access                        │
└─────────────────────────────────────────────────────────┘
```

---

## VLAN Configuration

### Switch Configuration (Managed Switch Required)

```cisco
! VLAN 10 - Trusted
vlan 10
 name TRUSTED

! VLAN 20 - DMZ/Server
vlan 20
 name DMZ

! VLAN 30 - IoT
vlan 30
 name IOT

! VLAN 40 - Guest  
vlan 40
 name GUEST

! Port assignments
interface GigabitEthernet0/1
 switchport mode access
 switchport access vlan 10
 description Admin laptop

interface GigabitEthernet0/2
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30,40
 description Pi (tagged)

interface GigabitEthernet0/3
 switchport mode access
 switchport access vlan 30
 description ESP32 sensor
```

### Pi Network Configuration

```bash
# /etc/network/interfaces or netplan
# Single interface, multiple VLANs

auto eth0.10
iface eth0.10 inet static
    address 192.168.10.101/24

auto eth0.20
iface eth0.20 inet static
    address 192.168.20.101/24
    # Default gateway here
    gateway 192.168.20.1
    dns-nameservers 192.168.20.101

auto eth0.30
iface eth0.30 inet static
    address 192.168.30.101/24
    # No gateway - isolated
```

---

## Firewall Rules

### Pi-hole (on DMZ) as Router

```bash
# /etc/pihole/pihole-FTL.conf (custom firewall)
# Or use ufw between VLANs

# Allow: Trusted → DMZ (full)
ufw allow from 192.168.10.0/24 to 192.168.20.0/24

# Allow: IoT → DMZ (limited ports only)
ufw allow from 192.168.30.0/24 to 192.168.20.101 port 1883  # MQTT
ufw allow from 192.168.30.0/24 to 192.168.20.101 port 8123  # HA
ufw allow from 192.168.30.0/24 to 192.168.20.101 port 6052  # ESPHome

# Deny: IoT → Internet (if strict)
# Or allow limited: NTP, firmware updates

# Allow: Guest → Internet only
ufw allow from 192.168.40.0/24 to any port 53   # DNS
ufw allow from 192.168.40.0/24 to any port 80  # HTTP
ufw allow from 192.168.40.0/24 to any port 443 # HTTPS
ufw deny from 192.168.40.0/24 to 192.168.0.0/16  # Block LAN
```

---

## Docker Network Impact

### Current

```yaml
# All containers use host networking
network_mode: host
# Or default bridge
```

### With VLANs

```yaml
# Create Docker networks per VLAN
networks:
  dmz:
    driver: macvlan
    driver_opts:
      parent: eth0.20
    ipam:
      config:
        - subnet: 192.168.20.0/24
  
  iot:
    driver: macvlan
    driver_opts:
      parent: eth0.30
    ipam:
      config:
        - subnet: 192.168.30.0/24

services:
  mosquitto:
    networks:
      - dmz
      - iot  # Dual-homed: DMZ + IoT
    
  homeassistant:
    networks:
      - dmz
      - iot
```

---

## Implementation Phases

### Phase 1: Preparation (No downtime)

```bash
# Document current IPs
arp -a > /tmp/current-ips.txt

# Identify IoT devices
nmap -sn 192.168.2.0/24 | grep -i esp
cat /tmp/current-ips.txt | grep -E '(esp|iot|sensor)'
```

### Phase 2: Pi Configuration (Maintenance window)

```bash
# 1. Backup network config
sudo cp /etc/network/interfaces /etc/network/interfaces.backup

# 2. Configure VLANs
sudo nano /etc/network/interfaces
# Add VLAN interfaces

# 3. Test without applying
sudo ifup --dry-run eth0.20

# 4. Apply (risk: may lose network)
sudo ifup eth0.20
# Connect via console if needed
```

### Phase 3: Device Migration (Gradual)

| Device | Current IP | New IP | VLAN |
|--------|-----------|--------|------|
| Admin laptop | 192.168.2.50 | 192.168.10.50 | 10 |
| Pi (main) | 192.168.2.101 | 192.168.20.101 | 20 |
| ESP32 temp | 192.168.2.150 | 192.168.30.150 | 30 |
| Guest phone | DHCP | 192.168.40.x | 40 |

---

## Risks & Mitigation

| Risk | Mitigation |
|------|------------|
| **Lost access to Pi** | Console cable ready, IPMI/KVM if available |
| **IoT devices hardcoded IP** | Scan first, reconfigure via ESPHome OTA |
| **Services broken** | Test each service after migration |
| **DHCP issues** | Keep old DHCP range for rollback |

---

## Simple Alternative (No VLANs)

If VLANs too complex:

```bash
# Use Docker networks for isolation
# Keep flat L2, isolate L3 via firewall

# Block IoT from internet
iptables -A FORWARD -s 192.168.2.150 -d ! 192.168.2.0/24 -j DROP

# Allow only to HA
iptables -A FORWARD -s 192.168.2.150 -d 192.168.2.101 -p tcp --dport 1883 -j ACCEPT
iptables -A FORWARD -s 192.168.2.150 -j DROP
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Network segmentation plan created |
