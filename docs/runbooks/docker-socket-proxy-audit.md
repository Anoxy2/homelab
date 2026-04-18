# Runbook: Docker Socket Proxy — Monatlicher Security-Audit

**Frequenz:** Monatlich  
**Verantwortlich:** steges  
**Ziel:** Sicherstellen, dass kein Container unkontrollierten Zugriff auf den Docker-Socket hat.

---

## Checkliste

### 1. Env-Vars des Proxy prüfen

Alle sicherheitskritischen Operationen müssen deaktiviert sein (`0`):

```bash
docker exec docker-socket-proxy env | grep -E "EXEC|POST|DELETE|AUTH|BUILD|COMMIT|CONFIGS|CONTAINERS|DISTRIBUTION|IMAGES|INFO|NETWORKS|NODES|PLUGINS|SECRETS|SERVICES|SESSION|SWARM|SYSTEM|TASKS|VOLUMES"
```

**Erwartung:** `EXEC=0`, `POST=0`, `DELETE=0` (oder nicht gesetzt). Erlaubt: `INFO=1`, `CONTAINERS=1`, `NETWORKS=1` für OpenClaw und Monitoring.

---

### 2. Welche Container nutzen Port 2375?

```bash
docker inspect $(docker ps -q) | python3 -c "
import json, sys
data = json.load(sys.stdin)
for c in data:
    bindings = c.get('HostConfig', {}).get('PortBindings') or {}
    for port, hosts in bindings.items():
        if '2375' in port and hosts:
            for h in hosts:
                print(c['Name'], '->', port, h.get('HostPort','?'))
" 2>/dev/null || echo "keine Treffer"
```

**Erwartung:** Nur Container, die explizit den Proxy benötigen.

---

### 3. Welche Container mounten `/var/run/docker.sock` direkt?

```bash
docker inspect $(docker ps -q) | python3 -c "
import json, sys
data = json.load(sys.stdin)
for c in data:
    for m in c.get('Mounts', []):
        if '/var/run/docker.sock' in m.get('Source', ''):
            print(c['Name'], m.get('Source'), '->', m.get('Destination'))
" 2>/dev/null || echo "keine Treffer"
```

**Erlaubt:** `/openclaw`, `/promtail`  
**Alarm bei:** Alle anderen Container.

---

### 4. Loki-Logs der letzten 30 Tage prüfen

```bash
~/scripts/skills log-query query --service docker-socket-proxy --since 720h 2>/dev/null | head -50
```

Auf verdächtige Anfragen achten: unbekannte Endpoints, ungewöhnliche IPs, POST-Requests auf gesperrte Pfade.

---

### 5. Aktuelle Proxy-Konfiguration im Container

```bash
docker exec docker-socket-proxy env | sort
```

Vollständige Env-Variablen dokumentieren, mit vorherigem Monat vergleichen.

---

### 6. Befund dokumentieren

- **Keine Auffälligkeiten:** Eintrag in `CHANGELOG.md` mit Datum und "ok".
- **Änderungen nötig:** Änderung in `CHANGELOG.md` beschreiben, `docker-compose.yml` anpassen, Container neu starten.

```bash
# Beispiel-Eintrag CHANGELOG.md:
# 2026-05-01 — Docker Socket Proxy Audit: ok. Keine Anomalien. EXEC=0, POST=0.
```

---

## Referenzen

- Haupt-Konfiguration: `/home/steges/docker-compose.yml` (Service: `docker-socket-proxy`)
- Security-Kontext: `/home/steges/CLAUDE.md` → Abschnitt "Security"
- Infrastruktur-Doku: `/home/steges/docs/infrastructure/docker-socket-proxy.md`
