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
├── infrastructure/           # ⭐ Infra-Doku (15 Dateien)
│   ├── README.md
│   ├── hardware-nvme.md
│   ├── network-firewall.md
│   ├── docker-compose-stack.md
│   ├── systemd-services.md
│   ├── installed-software.md
│   ├── firmware-boot.md
│   ├── skills-overview.md
│   ├── skill-dependencies.md     # ⭐ NEU
│   ├── github-automation-skill.md # ⭐ NEU
│   ├── cods-playbooks.md
│   ├── scripts-reference.md
│   ├── backup-strategy.md
│   ├── backup-automation-skill.md
│   └── directory-structure.md
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
| [hardware-nvme.md](infrastructure/hardware-nvme.md) | Pi, NVMe, SMART |
| [network-firewall.md](infrastructure/network-firewall.md) | UFW, Ports, Netzwerk |
| [docker-compose-stack.md](infrastructure/docker-compose-stack.md) | Alle Container |
| [systemd-services.md](infrastructure/systemd-services.md) | Timer & Services |
| [skills-overview.md](infrastructure/skills-overview.md) | Alle 20+ Skills |
| [cods-playbooks.md](infrastructure/cods-playbooks.md) | Playbooks & Runbooks |
| [scripts-reference.md](infrastructure/scripts-reference.md) | Alle Scripts |
| [backup-strategy.md](infrastructure/backup-strategy.md) | **GitHub + USB Backup** |
| [backup-automation-skill.md](infrastructure/backup-automation-skill.md) | **Backup Skill (skill-forge)** |
| [skill-dependencies.md](infrastructure/skill-dependencies.md) | ⭐ **Skill Dependency Graph** |
| [github-automation-skill.md](infrastructure/github-automation-skill.md) | ⭐ **GitHub Skill Doku** |
| [directory-structure.md](infrastructure/directory-structure.md) | Komplette Struktur |

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
    "infrastructure/directory-structure.md"
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
