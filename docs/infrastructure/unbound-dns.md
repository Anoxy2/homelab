# Unbound DNS Resolver

> Rekursiver DNS-Resolver für Pi-hole
> Root-Hints, DNSSEC, keine Forward-Abhängigkeit

---

## Überblick

**Unbound** ist der rekursive DNS-Resolver im Stack – komplett selbstständig, keine externen DNS-Forwarder nötig.

| Attribut | Wert |
|----------|------|
| **Image** | `crazymax/unbound:1.24.2` |
| **Container** | unbound |
| **Port** | `5335` (Host mode) |
| **Upstream für** | Pi-hole (als Custom DNS) |
| **Config** | `./unbound/config/` |

---

## Architektur

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Client    │────→│   Pi-hole   │────→│   Unbound   │
│  (Browser)  │     │   :53       │     │   :5335     │
└─────────────┘     └─────────────┘     └─────────────┘
                                                │
                    ┌───────────────────────────┼───────────┐
                    ↓                           ↓           ↓
            ┌─────────────┐             ┌──────────┐ ┌──────────┐
            │  Root-Server│             │.com TLD  │ │.de  TLD  │
            │  (a-m.root) │             └──────────┘ └──────────┘
            └─────────────┘
                    │
                    ↓
            ┌─────────────┐
            │example.com  │
            │Authoritative│
            └─────────────┘
```

---

## Konfiguration

### Docker Compose

```yaml
services:
  unbound:
    image: crazymax/unbound:1.24.2
    container_name: unbound
    network_mode: host
    volumes:
      - ./unbound/config:/config:ro
```

### unbound.conf

```
# unbound/config/unbound.conf

server:
    # Netzwerk
    interface: 127.0.0.1
    interface: 192.168.2.101
    port: 5335
    
    # Zugriff
    access-control: 192.168.2.0/24 allow
    access-control: 127.0.0.0/8 allow
    access-control: 0.0.0.0/0 refuse
    
    # Rekursion
    do-ip4: yes
    do-ip6: no
    prefer-ip6: no
    
    # Performance
    num-threads: 4
    msg-cache-slabs: 8
    rrset-cache-slabs: 8
    infra-cache-slabs: 8
    key-cache-slabs: 8
    
    # Cache-Größen
    rrset-cache-size: 128m
    msg-cache-size: 64m
    so-rcvbuf: 1m
    so-sndbuf: 1m
    
    # Sicherheit
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-referral-path: yes
    
    # DNSSEC
    auto-trust-anchor-file: /var/lib/unbound/root.key
    val-clean-additional: yes
    
    # Privacy
    qname-minimisation: yes
    qname-minimisation-strict: yes
    aggressive-nsec: yes
    
    # Logging
    verbosity: 1
    log-queries: no
    log-replies: no
    log-servfail: yes
    
    # TTL Limits
    cache-min-ttl: 300
    cache-max-ttl: 86400
    
    # EDNS
    edns-buffer-size: 1232
    max-udp-size: 3072

# Root-Hints (initial, wird aktualisiert)
# root-hints: /etc/unbound/root.hints

# Remote Control (optional)
remote-control:
    control-enable: yes
    control-interface: 127.0.0.1
    control-port: 8953
    server-key-file: /etc/unbound/unbound_server.key
    server-cert-file: /etc/unbound/unbound_server.pem
    control-key-file: /etc/unbound/unbound_control.key
    control-cert-file: /etc/unbound/unbound_control.pem
```

---

## Pi-hole Integration

### Unbound als Upstream

```
Pi-hole Admin → Settings → DNS → Custom DNS
Upstream: 192.168.2.101#5335
```

**Oder in `/etc/pihole/setupVars.conf`:**
```
PIHOLE_DNS_1=192.168.2.101#5335
```

### Fallback (optional)

Falls Unbound ausfällt:
```
Pi-hole → Cloudflare (1.1.1.1) als Backup
```

---

## Verwendung

### DNS-Test

```bash
# Direkt gegen Unbound
dig @192.168.2.101 -p 5335 google.com

# Mit DNSSEC
dig @192.168.2.101 -p 5335 dnssec-failed.org

# Rekursive Abfrage-Details
dig @192.168.2.101 -p 5335 +trace google.com
```

### Performance-Test

```bash
# Cache-Effizienz
dig @192.168.2.101 -p 5335 google.com +stats
# → Query time: 0 msec (cached)

# Benchmark
dnsperf -s 192.168.2.101 -p 5335 -d queryfile.txt
```

---

## Troubleshooting

### "connection timed out"

```bash
# Container läuft?
docker ps | grep unbound

# Port offen?
nc -zv 192.168.2.101 5335

# Config-Test
docker exec unbound unbound-checkconf
```

### DNSSEC-Failures

```bash
# Trust-Anchor prüfen
docker exec unbound cat /var/lib/unbound/root.key

# DNSSEC-Test
drill -D -p 5335 @192.168.2.101 dnssec-failed.org

# Wenn zu viele Fehler:
# In unbound.conf: disable DNSSEC für Problem-Domains
server:
    domain-insecure: "problem-domain.com"
```

### Hohe Latenz

```bash
# Root-Server Latenz testen
dig @a.root-servers.net

# Cache-Status
docker exec unbound unbound-control stats_noreset | grep cache

# Cache leeren (bei Problemen)
docker exec unbound unbound-control flush
```

### "SERVFAIL"

```bash
# Logs
docker logs unbound --tail 50

# Verbose logging temporär aktivieren
server:
    verbosity: 3
    log-queries: yes
```

---

## Backup

```bash
# Config + Trust Anchor
./unbound/config/ → /mnt/usb-backup/backups/YYYYMMDD/unbound/

# Root.key ist wichtig für DNSSEC
```

---

## Vergleich: Unbound vs Forwarding

| Aspekt | Unbound | Cloudflare/Quad9 |
|--------|---------|------------------|
| **Privatsphäre** | ✅ 100% lokal | ❌ Externe Server |
| **DNSSEC** | ✅ Validierung lokal | ✅ Forwarder validiert |
| **Geschwindigkeit** | ⚠️ Erste Anfrage langsamer | ✅ Schneller (cached) |
| **Wartung** | ⚠️ Root-Hints aktualisieren | ✅ Keine Wartung |
| **Kontrolle** | ✅ Vollständig | ❌ Keine |

---

## Deaktivieren (Fallback)

Falls Unbound Probleme macht:

```bash
# Stoppen
docker compose stop unbound

# Pi-hole auf externe DNS umstellen
# Settings → DNS → Cloudflare (1.1.1.1)
```

---

## Changelog

| Datum | Änderung |
|-------|----------|
| 2026-04-10 | Dokumentation erstellt, Unbound 1.24.2 |
