# Pi-hole Setup

## systemd-resolved Konflikt

`systemd-resolved` hört standardmäßig auf `127.0.0.53:53`.
Pi-hole braucht Port 53 auf der physischen Netzwerkschnittstelle.

**Lösung:**

1. DNS-Stub deaktivieren:
   ```bash
   sudo nano /etc/systemd/resolved.conf
   # Setzen:
   DNSStubListener=no
   ```

2. Service neu starten:
   ```bash
   sudo systemctl restart systemd-resolved
   ```

3. Pi-hole nur an LAN-Interface binden (in `.env`):
   ```
   FTLCONF_LOCAL_IPV4=192.168.2.101
   ```

## Router-Konfiguration

Nach erfolgreichem Start von Pi-hole:
- Im Router-Admin DHCP DNS auf `192.168.2.101` setzen
- Alternativ: Direkt auf jedem Gerät als DNS eintragen

## DNS testen

```bash
dig @192.168.2.101 google.com
# Sollte eine Antwort von Pi-hole liefern
```

## Fallback-DNS

Falls Pi-hole ausfällt, verlieren alle LAN-Clients DNS.
Fallback in `/etc/resolv.conf` eintragen:
```
nameserver 192.168.2.101
nameserver 1.1.1.1
```
