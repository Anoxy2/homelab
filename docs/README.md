# Steges' Homelab Documentation

> Zentrale Dokumentation für OpenClaw, Infrastruktur und Skills  
> Stand: April 2026

---

## Übersicht

Diese Dokumentation umfasst:
- **OpenClaw** – AI Gateway, Features, API, Setup
- **Infrastructure** – ⭐ Hardware, Netzwerk, Docker, systemd (für RAG)
- **Skills** – Agent-Fähigkeiten, Self-Awareness
- **CODS** – Central Operations Dispatch System

---

## Struktur

```
docs/
├── README.md                   # Diese Datei
├── core/                       # ⭐ NEU: System-Architektur (5 Dateien)
│   ├── system-overview.md
│   ├── system-architecture.md
│   ├── network-topology.md
│   ├── services-and-ports.md
│   └── security-baseline.md
├── decisions/                  # Architektur-Entscheidungen (6 Dateien)
├── Ideen/                      # ⭐ NEU: Roadmap & Projekte (4 Dateien)
│   ├── future-projects.md
│   ├── experimente.md
│   ├── skill-ideen.md
│   └── hardware-upgrades.md
├── infrastructure/           # ⭐ Infra-Doku (32 Dateien)
│   ├── README.md
│   ├── hardware-nvme.md
│   ├── network-firewall.md
│   ├── docker-compose-stack.md
│   ├── systemd-services.md
│   ├── installed-software.md
│   ├── firmware-boot.md
│   ├── skills-overview.md
│   ├── skill-dependencies.md
│   ├── github-automation-skill.md
│   ├── cods-playbooks.md
│   ├── scripts-reference.md
│   ├── backup-strategy.md
│   ├── backup-automation-skill.md
│   ├── directory-structure.md
│   ├── vaultwarden-setup.md      # Password Manager
│   ├── homepage-dashboard.md     # Service Dashboard
│   ├── tailscale-vpn.md          # VPN Setup
│   ├── caddy-reverse-proxy.md    # Reverse Proxy
│   ├── esphome-firmware.md       # ESP32 Firmware
│   ├── ntfy-notifications.md     # Push Notifications
│   ├── mqtt-mosquitto.md         # MQTT Broker
│   ├── searxng-search.md         # Web Search
│   ├── authelia-sso.md           # 2FA/SSO
│   ├── unbound-dns.md            # DNS Resolver
│   ├── prometheus-metrics.md     # ⭐ NEU: Metrics Collection
│   ├── alertmanager-routing.md   # ⭐ NEU: Alert Routing
│   ├── loki-logging.md           # ⭐ NEU: Log Aggregation
│   ├── scrutiny-nvme.md          # ⭐ NEU: Drive Health
│   ├── cadvisor-containers.md    # ⭐ NEU: Container Metrics
│   ├── influxdb-timeseries.md    # ⭐ NEU: Time-Series DB
│   └── node-exporter.md          # ⭐ NEU: System Metrics
├── monitoring/               # ⭐ Monitoring (5 Dateien)
│   ├── time-series-baseline.md
│   ├── time-series-decision.md
│   ├── vuln-log.md
│   ├── backup-monitoring.md      # ⭐ NEU
│   └── skill-health-dashboard.md # ⭐ NEU
├── openclaw/                 # OpenClaw-Doku (18 Dateien)
├── operations/               # ⭐ NEU: Betrieb (6 Dateien)
├── runbooks/                 # ⭐ NEU: Notfall-Prozeduren (9 Dateien)
├── setup/                    # ⭐ NEU: Setup-Guides (7 Dateien)
├── skills/                   # Skill-Entwicklung (5 Dateien)
└── visual-baselines/         # Canvas Assets (4 Ordner)
```

---

## Bereiche

### 🦞 OpenClaw

KI-Gateway für den Pi – lokale AI-Assistant.

| Doku | Beschreibung |
|------|--------------|
| [openclaw/README.md](openclaw/README.md) | Einstieg |
| [openclaw-setup-steges.md](openclaw/openclaw-setup-steges.md) | **👉 Dein spezifisches Setup** |
| [openclaw-models-pricing.md](openclaw/openclaw-models-pricing.md) | LLM-Provider & Kosten |

### 🏗️ Infrastructure

**Neu:** Vollständige technische Doku für RAG Self-Awareness.

| Dokument | Beschreibung |
|----------|--------------|
| [infrastructure/README.md](infrastructure/README.md) | Einstieg |
| [infrastructure/hardware-nvme.md](infrastructure/hardware-nvme.md) | Pi, NVMe, SMART |
| [infrastructure/network-firewall.md](infrastructure/network-firewall.md) | UFW, Ports, Netzwerk |
| [infrastructure/docker-compose-stack.md](infrastructure/docker-compose-stack.md) | Alle Container |
| [infrastructure/systemd-services.md](infrastructure/systemd-services.md) | Timer & Services |
| [infrastructure/skills-overview.md](infrastructure/skills-overview.md) | Alle 20+ Skills |
| [infrastructure/cods-playbooks.md](infrastructure/cods-playbooks.md) | Playbooks & Runbooks |
| [infrastructure/scripts-reference.md](infrastructure/scripts-reference.md) | Alle Scripts |
| [infrastructure/backup-strategy.md](infrastructure/backup-strategy.md) | **GitHub + USB Backup** |
| [infrastructure/backup-automation-skill.md](infrastructure/backup-automation-skill.md) | **Backup Skill (skill-forge)** |
| [infrastructure/skill-dependencies.md](infrastructure/skill-dependencies.md) | **Skill Dependency Graph** |
| [infrastructure/github-automation-skill.md](infrastructure/github-automation-skill.md) | **GitHub Skill Doku** |
| [infrastructure/vaultwarden-setup.md](infrastructure/vaultwarden-setup.md) | **Password Manager** |
| [infrastructure/homepage-dashboard.md](infrastructure/homepage-dashboard.md) | **Service Dashboard** |
| [infrastructure/tailscale-vpn.md](infrastructure/tailscale-vpn.md) | **VPN & Exit-Node** |
| [infrastructure/caddy-reverse-proxy.md](infrastructure/caddy-reverse-proxy.md) | **LAN-URLs & Proxy** |
| [infrastructure/esphome-firmware.md](infrastructure/esphome-firmware.md) | ⭐ **ESP32 Firmware** |
| [infrastructure/mqtt-mosquitto.md](infrastructure/mqtt-mosquitto.md) | ⭐ **MQTT Broker** |
| [infrastructure/ntfy-notifications.md](infrastructure/ntfy-notifications.md) | ⭐ **Push Notifications** |
| [infrastructure/searxng-search.md](infrastructure/searxng-search.md) | ⭐ **Web Search** |
| [infrastructure/authelia-sso.md](infrastructure/authelia-sso.md) | ⭐ **2FA & SSO** |
| [infrastructure/unbound-dns.md](infrastructure/unbound-dns.md) | **DNS Resolver** |
| [infrastructure/prometheus-metrics.md](infrastructure/prometheus-metrics.md) | ⭐ **Metrics Collection** |
| [infrastructure/alertmanager-routing.md](infrastructure/alertmanager-routing.md) | ⭐ **Alert Routing** |
| [infrastructure/loki-logging.md](infrastructure/loki-logging.md) | ⭐ **Log Aggregation** |
| [infrastructure/influxdb-timeseries.md](infrastructure/influxdb-timeseries.md) | ⭐ **Time-Series DB** |
| [infrastructure/node-exporter.md](infrastructure/node-exporter.md) | ⭐ **System Metrics** |
| [infrastructure/cadvisor-containers.md](infrastructure/cadvisor-containers.md) | ⭐ **Container Metrics** |
| [infrastructure/scrutiny-nvme.md](infrastructure/scrutiny-nvme.md) | ⭐ **Drive Health** |
| [infrastructure/directory-structure.md](infrastructure/directory-structure.md) | Komplette Struktur |

### 💡 Ideen & Roadmap

Zukünftige Projekte, Experimente und Hardware-Upgrades.

| Dokument | Beschreibung |
|----------|--------------|
| [Ideen/future-projects.md](Ideen/future-projects.md) | ⭐ **Projekt-Roadmap 2026** |
| [Ideen/experimente.md](Ideen/experimente.md) | ⭐ **Abgeschlossene Versuche** |
| [Ideen/skill-ideen.md](Ideen/skill-ideen.md) | ⭐ **Neue Skill-Ideen** |
| [Ideen/hardware-upgrades.md](Ideen/hardware-upgrades.md) | ⭐ **Hardware-Wunschliste** |

### 🔧 Setup Guides

Schritt-für-Schritt Einrichtung.

| Dokument | Beschreibung |
|----------|--------------|
| [setup/github-automation-setup.md](setup/github-automation-setup.md) | ⭐ **GitHub CLI Setup** |
| [setup/usb-backup-setup.md](setup/usb-backup-setup.md) | ⭐ **USB-Stick Setup** |
| [setup/docker-compose-setup.md](setup/docker-compose-setup.md) | ⭐ **Docker Stack Setup** |
| [setup/nvme-boot-setup.md](setup/nvme-boot-setup.md) | ⭐ **Pi 5 NVMe Boot** |
| [setup/pihole-setup.md](setup/pihole-setup.md) | Pi-hole Setup |
| [setup/homeassistant-setup.md](setup/homeassistant-setup.md) | Home Assistant Setup |

### 🚨 Runbooks

Notfall-Prozeduren & Troubleshooting.

| Dokument | Beschreibung |
|----------|--------------|
| [runbooks/backup-failure-recovery.md](runbooks/backup-failure-recovery.md) | ⭐ **Backup Recovery** |
| [runbooks/usb-restore-procedure.md](runbooks/usb-restore-procedure.md) | ⭐ **USB Restore** |
| [runbooks/github-auth-refresh.md](runbooks/github-auth-refresh.md) | ⭐ **GitHub Token Refresh** |
| [runbooks/skill-dependency-check.md](runbooks/skill-dependency-check.md) | ⭐ **Skill Health Check** |
| [runbooks/pihole-dns-ausfall.md](runbooks/pihole-dns-ausfall.md) | DNS Ausfall |
| [runbooks/openclaw-nicht-erreichbar.md](runbooks/openclaw-nicht-erreichbar.md) | OpenClaw Down |

### 📊 Monitoring

Metriken, Alerts, Dashboards.

| Dokument | Beschreibung |
|----------|--------------|
| [monitoring/backup-monitoring.md](monitoring/backup-monitoring.md) | ⭐ **Backup Monitoring** |
| [monitoring/skill-health-dashboard.md](monitoring/skill-health-dashboard.md) | ⭐ **Skill Health** |
| [monitoring/time-series-baseline.md](monitoring/time-series-baseline.md) | Prometheus/Loki Setup |
| [monitoring/vuln-log.md](monitoring/vuln-log.md) | Vulnerability Tracking |

---

## Quick Access

```bash
# System-Status
cat ~/agent/skills/openclaw-ui/html/state-brief.latest.json

# NVMe-Health
sudo smartctl -H /dev/nvme0

# Docker-Status
docker ps --format "table {{.Names}}\t{{.Status}}"

# Firewall
sudo ufw status numbered

# Timer-Status
systemctl list-timers

# RAG-Check
~/agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh
```

---

## RAG-Gold-Set

Diese Dateien werden vom `openclaw-rag` Skill indexiert:

```json
{
  "gold_set": [
    "infrastructure/hardware-nvme.md",
    "infrastructure/network-firewall.md",
    "infrastructure/docker-compose-stack.md",
    "infrastructure/systemd-services.md",
    "infrastructure/installed-software.md",
    "infrastructure/skills-overview.md",
    "infrastructure/cods-playbooks.md",
    "infrastructure/scripts-reference.md",
    "infrastructure/firmware-boot.md",
    "infrastructure/directory-structure.md",
    "infrastructure/vaultwarden-setup.md",
    "infrastructure/homepage-dashboard.md",
    "infrastructure/tailscale-vpn.md",
    "infrastructure/caddy-reverse-proxy.md",
    "infrastructure/esphome-firmware.md",
    "infrastructure/mqtt-mosquitto.md",
    "infrastructure/ntfy-notifications.md",
    "infrastructure/searxng-search.md",
    "infrastructure/authelia-sso.md",
    "infrastructure/unbound-dns.md",
    "infrastructure/prometheus-metrics.md",
    "infrastructure/alertmanager-routing.md",
    "infrastructure/loki-logging.md",
    "infrastructure/influxdb-timeseries.md",
    "infrastructure/node-exporter.md",
    "infrastructure/cadvisor-containers.md",
    "infrastructure/scrutiny-nvme.md"
  ]
}
```

---

## Wartung

```bash
# Nach Hardware-Änderung
# → hardware-nvme.md aktualisieren

# Nach Software-Update
# → installed-software.md aktualisieren

# Nach Config-Änderung
# → systemd-services.md oder docker-compose-stack.md

# RAG neu indexieren
~/agent/skills/openclaw-rag/scripts/reindex.sh
```

---

## Links

- [GitHub](https://github.com/steges/homelab) – Quellcode
- [CHANGELOG](../CHANGELOG.md) – Historie
- [CLAUDE.md](../CLAUDE.md) – Claude-Spezifik
