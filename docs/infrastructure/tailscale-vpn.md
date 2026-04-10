# Tailscale VPN Setup

> Zero-config VPN für Remote-Zugriff auf das Homelab
> WireGuard-basiert, kein Port-Forwarding nötig

---

## Überblick

**Tailscale** erstellt ein privates Mesh-VPN über öffentliche Server. Keine Router-Konfiguration nötig.

| Attribut | Wert |
|----------|------|
| **Image** | `tailscale/tailscale:v1.94.2` |
| **Container** | tailscale |
| **Hostname** | pilab |
| **Netzwerk** | Host mode (required) |
| **Funktion** | Exit-Node für LAN-Zugriff |

---

## Architektur

```
[Remote Device] ←──Tailscale──→ [Tailscale Cloud] ←──Tailscale──→ [PiLab]
       ↓                                                ↓
   100.x.x.x                                       100.x.x.x
       ↓                                                ↓
   [Internet]                                    [192.168.2.0/24]
                                                      ↓
                                              [Pi-hole, HA, Grafana...]
```

---

## Konfiguration

### Docker Compose

```yaml
services:
  tailscale:
    image: tailscale/tailscale:v1.94.2
    container_name: tailscale
    hostname: pilab
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - ./tailscale/state:/var/lib/tailscale
      - /dev/net/tun:/dev/net/tun
    env_file: .env
    environment:
      TS_EXTRA_ARGS: "--advertise-exit-node"
      TS_STATE_DIR: "/var/lib/tailscale"
      TS_USERSPACE: "false"
```

### Environment (.env)

```bash
# Optional: Auth-Key für unattended setup
# TS_AUTHKEY=tskey-auth-xxx
```

**Ohne Auth-Key:** Erst-Login via `docker exec` (siehe Setup)

---

## Erst-Setup

### 1. Container starten

```bash
docker compose up -d tailscale
```

### 2. Login URL holen

```bash
docker exec tailscale tailscale up
```

### 3. Browser öffnen

URL aus Output kopieren → `https://login.tailscale.com/...`

### 4. Gerät autorisieren

- Tailscale Admin Console öffnen
- "pilab" autorisieren
- Optional: Exit-Node aktivieren

### 5. Exit-Node aktivieren (Remote-Geräte)

```bash
# Auf dem Remote-Gerät:
tailscale up --exit-node=pilab
```

Oder in Tailscale App: Settings → Use exit node → "pilab"

---

## Exit-Node Funktion

**Was macht sie:**
- Remote-Gerät tunneliert **alles** durch PiLab
- Zugriff auf **alle** LAN-Services (192.168.2.x)
- DNS durch Pi-hole (Werbung blocken remote!)

**Wann nützlich:**
- Unsichere WLANs (Hotels, Cafés)
- Zugriff auf LAN-only Services von unterwegs
- Remote-Administration

---

## Magic DNS

**Aktivieren in Admin Console:**
DNS → Nameservers → Add nameserver → `192.168.2.101` (Pi-hole)

**Ergebnis:**
```bash
# Von Remote:
ping pihole.lan      # Funktioniert!
curl http://vault.lan # Funktioniert!
```

---

## Subnet-Routing (alternativ)

Falls Exit-Node zu viel:

```bash
# Auf PiLab:
docker exec tailscale tailscale up --advertise-routes=192.168.2.0/24
```

**In Admin Console:**
- Machine "pilab" → Edit route settings → Approve 192.168.2.0/24

**Auf Remote-Gerät:**
```bash
tailscale up --accept-routes
```

Nur Subnet erreichbar, nicht kompletter Traffic.

---

## ACLs (Zugriffskontrolle)

Tailscale Admin Console → Access Controls:

```json
{
  "acls": [
    {"action": "accept", "src": ["*"], "dst": ["*:*"]}
  ],
  "ssh": [
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["tag:admin"],
      "users": ["autogroup:nonroot", "root"]
    }
  ]
}
```

---

## Troubleshooting

### Container startet nicht

```bash
# TUN device prüfen
ls -la /dev/net/tun

# Falls fehlend:
sudo modprobe tun
echo 'tun' | sudo tee /etc/modules-load.d/tailscale.conf
```

### "needs authentication"

```bash
# Status prüfen
docker exec tailscale tailscale status

# Re-authenticate
docker exec tailscale tailscale up --force-reauth
```

### Kein Internet via Exit-Node

```bash
# IP-Forwarding prüfen
sysctl net.ipv4.ip_forward

# Aktivieren falls nötig:
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### DNS funktioniert nicht remote

```bash
# Pi-hole muss für Tailscale-IPs erreichbar sein
# In Pi-hole: Settings → DNS → Interface settings →
# "Listen on all interfaces, permit all origins"
```

---

## Backup

```bash
# State sichernt sich selbst im USB-Backup
./tailscale/state/ → /mnt/usb-backup/backups/YYYYMMDD/tailscale/

# Wichtig: Nach Restore muss Re-authentication erfolgen!
```

---

## Changelog

| Datum | Änderung |
|-------|----------|
| 2026-04-10 | Dokumentation erstellt, v1.94.2 |
