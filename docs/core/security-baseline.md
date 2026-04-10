# Sicherheit

## Grundregeln

- Alle Services sind **nur im LAN** erreichbar (192.168.2.0/24)
- Kein Port-Forwarding auf dem Router
- `.env` Dateien niemals committen oder über Samba teilen

## Firewall (UFW)

- UFW ist aktiv mit Default-Policy `deny incoming`.
- Für lesbare LAN-URLs über Caddy ist `80/tcp` explizit nur für `192.168.2.0/24` freigegeben.
- DNS/DHCP-Freigaben für Pi-hole bleiben wie bisher aktiv.

## Secret-Management

- Secrets in `.env` Dateien pro Stack
- `.env.example` als Vorlage ohne echte Werte
- Samba blockiert `.env`, `.env.bak`, `secrets.env`, `memory`, `openclaw-data` per veto files

## SSH

- Key-only Auth empfohlen (`PasswordAuthentication no` in `/etc/ssh/sshd_config`)
- Nur User `steges` hat Zugriff

## Docker

- Container laufen nicht als root (wo möglich PUID/PGID setzen)
- Log-Rotation verhindert Volllaufen der NVMe
- Watchtower updated Images wöchentlich (nicht sofort, um Breaking Changes zu vermeiden)

### Docker Socket: Socket Proxy

OpenClaw und Homepage nutzen `tecnativa/docker-socket-proxy` als least-privilege Middleware statt direktem `/var/run/docker.sock` Mount.

Konfiguration (docker-socket-proxy Container):
- Erlaubt: CONTAINERS, IMAGES, NETWORKS, VOLUMES, INFO, VERSION, PING, EVENTS, POST
- Gesperrt: AUTH, BUILD, COMMIT, CONFIGS, EXEC, NODES, PLUGINS, SECRETS, SERVICES, SWARM, SYSTEM, TASKS
- Endpoint: `tcp://docker-socket-proxy:2375` (nur intern, kein Host-Zugriff von außen)

### Docker Socket: Portainer

Portainer mountet `/var/run/docker.sock` direkt – als Container-Management-UI benötigt Portainer vollen API-Zugriff (exec, logs, image pull, deploy).

Aktuelle Entscheidung:
- Risiko ist bewusst akzeptiert, weil Portainer ohne vollen Socket-Zugriff nicht funktionsfaehig waere.
- Portainer ist ausschliesslich im LAN erreichbar (Port 9000, nicht per Caddy exposed).
- Alternativer Ansatz (socket-proxy mit EXEC: 1, LOGS: 1 Erweiterung) waere moeglich, reduziert aber nur marginalen Risiken.

Kompensierende Kontrollen:
- Kein Port-Forwarding, kein oeffentlicher Zugriff auf den Stack
- Remote-Zugriff nur ueber Tailscale
- Portainer-UI nur fuer vertrauenswuerdige Nutzer zugaenglich (LAN-only)

Neubewertung noetig wenn:
- Portainer aus dem LAN heraus oeffentlich zugaenglich wird
- weitere Automatisierungen mit Schreibrechten auf Docker dazukommen

## Updates

```bash
sudo apt update && sudo apt upgrade
```

Unattended-upgrades ist aktiv für Sicherheits-Patches.

## Skill-Manager Security Controls

- Policy-Gate vor Änderungen: `~/scripts/skill-forge policy lint`
- Incident-Freeze blockiert Promotions: `~/scripts/skill-forge incident freeze on`
- EXTREME-Funde gehen in Quarantaene (`pending-blacklist`) und werden zeitverzögert promotet
- Audit-Log zeichnet Entscheidungen und Promotions nach (`.state/audit-log.jsonl`)
- Canary-State reduziert Risiko bei neuen/aktualisierten Skills

Empfohlener Security-Ablauf:

```bash
~/scripts/skill-forge status
~/scripts/skill-forge audit --rejected
~/scripts/skill-forge blacklist list
```

Wenn plötzlicher REJECT-Spike auftritt:

```bash
~/scripts/skill-forge incident freeze on
~/scripts/skill-forge audit --rejected
```

## Optionales Auth-Failure Monitoring (Docker-Logs)

Als leichter Fail2ban-Ersatz für den aktuellen Stack läuft ein optionaler Log-Monitor:

```bash
~/scripts/auth-failure-monitor.sh --hours 24
~/scripts/auth-failure-monitor.sh --hours 24 --json
```

Fokus auf wiederholte Auth-/Token-Fehler in Logs von:
- `openclaw`, `mosquitto`, `homeassistant`, `grafana`, `pihole`, `caddy`

Exit-Code:
- `0` = unter Schwellwert
- `1` = Schwellwert erreicht/überschritten (`--threshold`, Standard `5`)
