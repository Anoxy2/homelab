# Zentrale via .lan URLs

## Kurzfassung

Die Ops-UI (OpenClaw Canvas) ist über drei äquivalente Reverse-Proxy-URLs erreichbar:

- **http://ops.lan** (empfohlen)
- **http://zentrale.lan**
- **http://canvas.lan** (legacy)

Alle drei leiten zu `http://192.168.2.101:8090/` (nginx).

## Technische Basis

| Komponente | Status | Details |
|---|---|---|
| DNS (Pi-hole) | ✅ Aktiv | `ops.lan` → `192.168.2.101:53` |
| Caddy Reverse Proxy | ✅ Aktiv | Port 80, `http://host.lan` → `192.168.2.101:8090` |
| nginx (ops-ui) | ✅ Aktiv | Port 8090, serviert Canvas UI |
| DHCP | ✅ Aktiv | Verteilt Pi-hole DNS an LAN-Clients |

## Problembehebung

### URLs funktionieren nicht im Browser

**Ursache:** Ihr Gerät nutzt Pi-hole DNS nicht.

**Lösung 1: DHCP erneuern** (Empfohlen)
1. Gerät vom Netzwerk trennen
2. Gerät wieder verbinden → DHCP-Lease erneuern
3. `http://ops.lan` im Browser öffnen

**Lösung 2: Manuell DNS setzen**
- Windows/macOS: Systemeinstellungen → Netzwerk → DNS → `192.168.2.101`
- Smartphone: WLAN-Einstellungen → DNS manuell → `192.168.2.101`

**Lösung 3: Direkter IP-Zugriff (Workaround)**
```
http://192.168.2.101:8090/
```

**Lösung 4: Browser Reset**
- Browser komplett neu starten (alle Tabs schließen, App beenden)
- DNS-Cache leeren:
  - Chrome: `chrome://net-internals/#dns` → Flush socket pools
  - Firefox: `about:networking` → DNS clearCache

### localhost-Tests erfolgreich

Die Pi selbst kann alle URLs auflösen und nutzen:
```bash
nslookup ops.lan 192.168.2.101
# Name: ops.lan
# Address: 192.168.2.101

curl http://ops.lan/
# ERFOLG - Canvas lädt
```

## Konfiguration

### Caddy (`~/caddy/Caddyfile`)
```
http://canvas.lan, http://ops.lan, http://zentrale.lan {
    reverse_proxy 192.168.2.101:8090
}
```

### Pi-hole DNS
- Wildcard: `*.lan` → `192.168.2.101`
- Definiert in: Pi-hole dnsmasq konfiguration

### /etc/hosts (localhost fallback)
```
192.168.2.101 ops.lan zentrale.lan
```

## Deployment-Pfad

1. Canvas-Quelle: `~/agent/skills/openclaw-ui/html/index.html`
2. nginx-Serving: `~/agent/skills/openclaw-ui/html/` (read-only mount)
3. Caddy-Routing: Port 80 → `ops-ui` Port 8090
4. DNS: Pi-hole wildcard `*.lan`

## Validierung

```bash
# Alle Tests bestehen:
✅ DNS auflöst ops.lan und zentrale.lan
✅ Caddy routet auf Port 80
✅ nginx serviert Canvas auf Port 8090
✅ DHCP verteilt Pi-hole DNS
✅ Browser-Zugriff funktioniert nach DHCP-Neustart
```
