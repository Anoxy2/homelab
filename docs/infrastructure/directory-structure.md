# Verzeichnis-Struktur – Komplette Übersicht

> Alle Verzeichnisse, ihre Funktion und wichtige Dateien  
> Stand: April 2026

---

## Home-Verzeichnis (`/home/steges/`)

```
/home/steges/
├── agent/                    # OpenClaw Agent-Workspace
├── alertmanager/             # Prometheus Alertmanager
├── authelia/                 # Authentifizierung
├── caddy/                    # Reverse Proxy
├── docs/                     # Dokumentation
├── esphome/                  # ESP32-Firmware
├── grafana/                  # Dashboards
├── growbox/                  # Growbox-Automation
├── homeassistant/            # Smart Home
├── homepage/                 # Startseite
├── influxdb/                 # Time-Series DB
├── infra/                    # Infrastruktur-Data
├── loki/                     # Log-Aggregation
├── mosquitto/                # MQTT Broker
├── ntfy/                     # Push Notifications
├── pihole/                   # DNS-Filter
├── prometheus/               # Metrics
├── promtail/                 # Log-Collector
├── scripts/                  # Automatisierung
├── scrutiny/                 # SMART-Monitoring
├── searxng/                  # Suchmaschine
├── systemd/                  # Service-Dateien
├── tailscale/                # VPN
├── unbound/                  # DNS-Resolver
├── vaultwarden/              # Passwort-Manager
└── [dotfiles]                # Konfiguration
```

---

## Detaillierte Struktur

### agent/ – OpenClaw Workspace

```
agent/
├── MEMORY.md                 # Langzeit-Gedächtnis
├── SOUL.md                   # Agent-Persönlichkeit
├── TOOLS.md                  # Tool-Definitionen
├── AGENTS.md                 # Multi-Agent-Config
├── workspace/                # Arbeitsbereich
│   ├── skills/               # Alle Skills
│   │   ├── authoring/
│   │   ├── canary/
│   │   ├── coding/
│   │   ├── core/
│   │   ├── growbox/
│   │   ├── ha-control/
│   │   ├── health/
│   │   ├── heartbeat/
│   │   ├── learn/
│   │   ├── log-query/
│   │   ├── metrics/
│   │   ├── openclaw-rag/     # ⭐ Self-Awareness
│   │   ├── openclaw-ui/      # ⭐ Web Interface
│   │   ├── pi-control/
│   │   ├── profile/
│   │   ├── runbook-maintenance/
│   │   ├── scout/
│   │   ├── skill-forge/
│   │   ├── vetting/
│   │   ├── vuln-watch/
│   │   └── web-search/
│   └── [project files]
└── [session data]
```

**Wichtige Skills:**
- `openclaw-rag/` – RAG-System für Self-Awareness
- `openclaw-ui/` – Canvas Web-Interface
- `runbook-maintenance/` – Automated Maintenance
- `pi-control/` – Pi Management

---

### infra/ – Infrastruktur-Data

```
infra/
├── openclaw-data/            # OpenClaw Persistenz
│   ├── openclaw.json         # Haupt-Config
│   ├── memory/
│   │   └── main.sqlite       # Langzeit-Gedächtnis
│   ├── sessions/             # Session-History
│   └── skills/               # Installierte Skills
└── docker-compose.yml        # (Optional: separate Stack)
```

---

### scripts/ – Automatisierung

```
scripts/
├── backup.sh                 # Lokales Backup
├── sync-offsite.sh           # Cloud-Backup
├── claw-send.sh              # OpenClaw Message
├── openclaw-config-guard.sh  # Config-Validator
├── install-openclaw-autostart.sh
├── rag-quality-report.sh     # RAG-Health
├── health-check.sh           # System-Check
├── canvas-drift-check.sh     # UI-Check
├── auth-failure-monitor.sh   # Security
├── update-stacks.sh          # Docker-Updates
├── lint-shell.sh             # Code-Quality
├── canvas-ops-brief.sh       # Ops-Dashboard
├── canvas-playwright-smoke.sh
├── tmux-session.sh           # tmux Helper
├── log-viewer.sh             # Log-Zugriff
├── port-check.sh             # Port-Test
├── cert-check.sh             # SSL-Check
├── network-test.sh           # Netzwerk-Diagnose
└── [weitere utilities]
```

---

### systemd/ – Services & Timer

```
systemd/
├── homelab.service           # Haupt-Docker-Stack
├── openclaw-compose.service  # OpenClaw Container
├── openclaw-heartbeat.service # Heartbeat-Dispatcher
├── chat-bridge.service       # HTTP-Bridge
├── nightly-self-check.service # Maintenance
├── rag-reindex-daily.service # RAG-Update
├── openclaw-heartbeat.timer  # 07:00/19:00
├── nightly-self-check.timer  # 03:00
└── rag-reindex-daily.timer   # 02:00
```

---

### docs/ – Dokumentation

```
docs/
├── openclaw/                 # OpenClaw-Doku
│   ├── README.md
│   ├── openclaw-overview.md
│   ├── openclaw-features.md
│   ├── openclaw-api-reference.md
│   ├── openclaw-security.md
│   ├── openclaw-operations-guide.md
│   ├── openclaw-setup-steges.md
│   ├── openclaw-models-pricing.md
│   ├── openclaw-tools-detailed.md
│   ├── openclaw-config-reference.md
│   └── [...]
└── infrastructure/           # ⭐ NEU: Infra-Doku
    ├── hardware-nvme.md
    ├── network-firewall.md
    ├── docker-compose-stack.md
    ├── systemd-services.md
    ├── installed-software.md
    ├── firmware-boot.md
    ├── skills-overview.md
    ├── cods-playbooks.md
    ├── scripts-reference.md
    └── directory-structure.md
```

---

### caddy/ – Reverse Proxy

```
caddy/
├── Caddyfile                 # Haupt-Config
└── [auto-generated certs in Docker volume]
```

**Caddyfile-Struktur:**
```caddyfile
# Global
{
    auto_https off
    email admin@example.com
}

# Services
home.steges.duckdns.org {
    reverse_proxy homeassistant:8123
}

git.steges.duckdns.org {
    reverse_proxy gitea:3000
}

# ... weitere Services
```

---

### pihole/ – DNS

```
pihole/
├── etc-pihole/
│   ├── pihole-FTL.db         # Gravity-Datenbank
│   ├── gravity.db            # Blocklisten
│   ├── custom.list           # Lokale DNS
│   └── localbranches
└── etc-dnsmasq.d/
    └── 01-pihole.conf        # DHCP/DNS-Config
```

---

### homeassistant/ – Smart Home

```
homeassistant/
├── configuration.yaml        # Haupt-Config
├── secrets.yaml              # Secrets (encrypted)
├── automations.yaml          # Automationen
├── scenes.yaml               # Szenen
├── scripts.yaml              # Scripts
├── known_devices.yaml        # Geräte
├── .storage/                 # Interne Data
│   ├── core.config_entries
│   ├── core.device_registry
│   └── core.entity_registry
└── [custom_components/]        # Custom Integrations
```

---

### prometheus/ – Metrics

```
prometheus/
├── prometheus.yml            # Haupt-Config
├── alerts/                   # Alert-Rules
│   ├── system.yml
│   ├── docker.yml
│   └── openclaw.yml
└── recording-rules.yml       # Pre-aggregierte Queries
```

---

### grafana/ – Dashboards

```
grafana/
└── provisioning/
    ├── dashboards/
    │   ├── dashboard.yml     # Provider-Config
    │   └── [json dashboards]
    └── datasources/
        └── datasources.yml   # Prometheus, Loki
```

---

### growbox/ – Growbox

```
growbox/
├── config/
│   └── sensors.yaml          # ESP32-Sensoren
├── scripts/
│   ├── growbox-daily-report.sh
│   └── growbox-diary.sh
└── data/
    └── measurements.db       # Historische Daten
```

---

### Dotfiles (versteckte Dateien)

```
.steges/
├── .bashrc                   # Shell-Config
├── .profile                  # Login-Config
├── .zshrc                    # Zsh-Config
├── .ssh/
│   ├── authorized_keys       # SSH-Keys
│   ├── id_ed25519            # Private Key
│   ├── id_ed25519.pub        # Public Key
│   └── known_hosts           # Vertraute Hosts
├── .gitconfig                # Git-Config
├── .docker/
│   └── config.json           # Docker-Auth
├── .local/
│   └── bin/                  # User-Binaries
├── .config/
│   └── [App-Configs]
└── .env                      # Umgebungsvariablen
```

---

## Docker Volumes

```
/var/lib/docker/volumes/
├── caddy-data/               # Let's Encrypt Certs
├── caddy-config/             # Caddy Config
├── prometheus-data/          # 30d Metrics
├── grafana-data/             # Dashboards
├── loki-data/                # Logs (7d)
├── alertmanager-data/        # Alert-History
├── homeassistant-data/       # HA Config
├── influxdb-data/            # Time-Series
└── [weitere...]
```

---

## System-Weite Pfade

```
/etc/
├── systemd/system/           # Aktivierte Services
│   ├── homelab.service → /home/steges/systemd/
│   ├── openclaw-*.service
│   └── *.timer
├── netplan/                  # Netzwerk-Config
│   └── 50-cloud-init.yaml
├── ufw/                      # Firewall
│   ├── applications.d/
│   └── ufw.conf
├── cron.d/                   # System-Cron
├── logrotate.d/              # Log-Rotation
│   ├── openclaw
│   └── maintenance-log
├── apt/sources.list.d/       # Repositories
│   ├── docker.list
│   ├── nodesource.list
│   └── raspberrypi.list
└── ssh/
    └── sshd_config           # SSH-Config
```

---

## Mount-Points

```bash
$ findmnt -D
SOURCE        TARGET              FSTYPE  OPTIONS
/dev/nvme0n1p1 /                   ext4    rw,relatime
/dev/mmcblk0p1 /boot/firmware      vfat    rw,relatime
/dev/nvme0n1p2 /mnt/data           ext4    rw,noatime
/dev/sda1      /mnt/backup         ext4    rw,noauto,user
```

| Mount | Device | Zweck |
|-------|--------|-------|
| `/` | /dev/nvme0n1p1 | Root-System |
| `/boot/firmware` | /dev/mmcblk0p1 | Boot-Code |
| `/mnt/data` | /dev/nvme0n1p2 | Daten-Partition |
| `/mnt/backup` | /dev/sda1 | Externe USB (on-demand) |

---

## Log-Verzeichnisse

```
/var/log/
├── syslog                    # System-Log
├── auth.log                  # Auth-Events
├── kern.log                  # Kernel
├── daemon.log                # Daemon-Logs
├── docker.log                # Docker
├── ufw.log                   # Firewall
├── openclaw/                 # OpenClaw Logs
│   └── gateway.log
├── maintenance/                # CODS Logs
│   └── nightly-check.log
└── journal/                  # systemd Journal
    └── [binary logs]
```

---

## Datenbank-Dateien

| Datenbank | Pfad | Engine |
|-----------|------|--------|
| OpenClaw Memory | `infra/openclaw-data/memory/main.sqlite` | SQLite |
| Pi-hole | `pihole/etc-pihole/gravity.db` | SQLite/FTL |
| Home Assistant | `homeassistant/home-assistant_v2.db` | SQLite |
| Vaultwarden | `vaultwarden/db.sqlite3` | SQLite |
| Grafana | `grafana-data/grafana.db` | SQLite |
| InfluxDB | `influxdb/` | TSM |

---

## Wichtige Dateien (Cheatsheet)

### Sofort-Zugriff

```bash
# System-Config
cat /boot/firmware/config.txt           # Pi-Config
cat /etc/netplan/50-cloud-init.yaml   # Netzwerk
cat /etc/ufw/ufw.conf                 # Firewall

# Haupt-Config
cat ~/docker-compose.yml              # Docker
cat ~/caddy/Caddyfile                  # Reverse Proxy
cat ~/infra/openclaw-data/openclaw.json # OpenClaw

# Status
cat ~/agent/skills/openclaw-ui/html/state-brief.latest.json
cat ~/agent/skills/openclaw-ui/html/ops-brief.latest.json

# Logs
tail -f /var/log/syslog
journalctl -f -u homelab
```

---

## Referenzen

- `docs/infrastructure/directory-structure.md` – Diese Datei
- `CHANGELOG.md` – Änderungshistorie
- `README.md` – Projekt-Übersicht
