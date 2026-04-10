# Infrastructure Documentation

> Vollständige technische Dokumentation von Steges' Homelab  
> Für OpenClaw RAG Self-Awareness

---

## Übersicht

Diese Dokumentation enthält **alle technischen Details** über die Infrastruktur:
- Hardware-Spezifikationen
- Netzwerk & Firewall
- Software & Services
- Automation & Scripts
- Operational Procedures (CODS)

**Zweck:** Ermöglicht OpenClaw, sich über die eigene Infrastruktur zu informieren und fundierte Entscheidungen zu treffen.

---

## Dokumente

### Hardware & System

| Dokument | Beschreibung |
|----------|--------------|
| [hardware-nvme.md](hardware-nvme.md) | Pi-Spezifikationen, NVMe-Details, SMART-Daten, Temperatur |
| [firmware-boot.md](firmware-boot.md) | Boot-Prozess, config.txt, Device Tree, Kernel-Parameter |

### Netzwerk & Security

| Dokument | Beschreibung |
|----------|--------------|
| [network-firewall.md](network-firewall.md) | IP-Adressen, UFW-Regeln, offene Ports, Docker-Netzwerke |

### Software & Services

| Dokument | Beschreibung |
|----------|--------------|
| [installed-software.md](installed-software.md) | Alle Pakete, Versionen, Docker-Images, Node, Python |
| [docker-compose-stack.md](docker-compose-stack.md) | Alle Container, Volumes, Ports, Konfiguration |
| [systemd-services.md](systemd-services.md) | Alle Services, Timer, automatisierte Tasks |
| [scripts-reference.md](scripts-reference.md) | Alle Scripts in `/home/steges/scripts/` |

### OpenClaw & Skills

| Dokument | Beschreibung |
|----------|--------------|
| [skills-overview.md](skills-overview.md) | Alle 20+ Skills, ihre Funktion und Integration |
| [skill-dependencies.md](skill-dependencies.md) | ⭐ Skill-Abhängigkeiten (github-automation → backup-automation) |
| [github-automation-skill.md](github-automation-skill.md) | ⭐ GitHub-Automation Skill (steipete/github basiert) |

### Backup & Automation ⭐ NEU

| Dokument | Beschreibung |
|----------|--------------|
| [backup-strategy.md](backup-strategy.md) | GitHub + USB Dual-Backup Strategie |
| [backup-automation-skill.md](backup-automation-skill.md) | Backup-Automation Skill (skill-forge) |

### Operations (CODS)

| Dokument | Beschreibung |
|----------|--------------|
| [cods-playbooks.md](cods-playbooks.md) | Playbooks, Runbooks, Alert-Routing |

### Referenz

| Dokument | Beschreibung |
|----------|--------------|
| [directory-structure.md](directory-structure.md) | Komplette Verzeichnis-Struktur |

---

## Quick Reference

### Wichtigste Dateien

```bash
# Configs
~/docker-compose.yml              # Docker Stack
~/caddy/Caddyfile                  # Reverse Proxy
~/infra/openclaw-data/openclaw.json # OpenClaw Config

# Status
~/agent/skills/openclaw-ui/html/state-brief.latest.json
~/agent/skills/openclaw-ui/html/ops-brief.latest.json

# Logs
/var/log/syslog                   # System
journalctl -u homelab -f          # Docker Stack
```

### Schnell-Commands

```bash
# System-Status
sudo systemctl status homelab
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
vcgencmd measure_temp
sudo smartctl -H /dev/nvme0

# OpenClaw
docker exec openclaw openclaw doctor
docker exec openclaw openclaw agent --message "ping"

# Network
sudo ufw status numbered
ss -tlnp | head -20
ip addr show

# RAG
./agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh
```

---

## Hardware-Zusammenfassung

| Komponente | Spezifikation |
|------------|---------------|
| **Board** | Raspberry Pi 5 (8GB) |
| **CPU** | Quad-core Cortex-A76 @ 2.4GHz |
| **RAM** | 8GB LPDDR4X |
| **Storage** | 250GB NVMe SSD (INTENSO) |
| **Boot** | NVMe nativ (PCIe) |
| **OS** | Debian 12 (bookworm) 64-bit |
| **Kernel** | 6.12.75+rpt-rpi-v8 |

---

## Services-Übersicht

| Kategorie | Services |
|-----------|----------|
| **Core** | Caddy, Pi-hole, Unbound |
| **Monitoring** | Prometheus, Grafana, Loki, Alertmanager |
| **Smart Home** | Home Assistant, Mosquitto |
| **Tools** | Vaultwarden, SearXNG, NTFY, ESPHome |
| **AI** | OpenClaw |

---

## Netzwerk-Übersicht

| IP/Port | Service |
|---------|---------|
| `192.168.2.101` | Pi-Host |
| `:80, :443` | Caddy (Reverse Proxy) |
| `:53` | Pi-hole (DNS) |
| `:22` | SSH |
| `:18789` | OpenClaw Gateway |
| `:8090` | OpenClaw UI |
| `:3000` | Grafana |
| `:9090` | Prometheus |
| `:8123` | Home Assistant |

---

## Automation

| Zeit | Task | Script/Service |
|------|------|----------------|
| **02:00** | RAG Reindex | `rag-reindex-daily.timer` |
| **03:00** | Nightly Check | `nightly-self-check.timer` |
| **07:00** | Heartbeat | `openclaw-heartbeat.timer` |
| **19:00** | Heartbeat | `openclaw-heartbeat.timer` |

---

## RAG-Integration

Diese Dokumente sind Teil des `openclaw-rag` GOLD-SET:

```json
{
  "gold_set": [
    "docs/infrastructure/hardware-nvme.md",
    "docs/infrastructure/network-firewall.md",
    "docs/infrastructure/docker-compose-stack.md",
    "docs/infrastructure/systemd-services.md",
    "docs/infrastructure/installed-software.md",
    "docs/infrastructure/skills-overview.md",
    "docs/infrastructure/cods-playbooks.md",
    "docs/infrastructure/scripts-reference.md",
    "docs/infrastructure/firmware-boot.md",
    "docs/infrastructure/directory-structure.md",
    "docs/infrastructure/backup-strategy.md",
    "docs/infrastructure/backup-automation-skill.md"
  ]
}
```

**Prompt für OpenClaw:**
> "Welche Ports sind auf meinem Pi offen und warum?"
→ Suche in: `network-firewall.md`, `docker-compose-stack.md`

---

## Wartung

### Doku aktualisieren

```bash
# Nach Hardware-Änderung
cat /proc/cpuinfo >> docs/infrastructure/hardware-nvme.md

# Nach Software-Update
apt list --installed > docs/infrastructure/installed-software.md

# Nach Config-Änderung
cp ~/docker-compose.yml docs/infrastructure/docker-compose-stack.md

# Reindex RAG
~/agent/skills/openclaw-rag/scripts/reindex.sh
```

---

## Links

- [OpenClaw Doku](../openclaw/) – OpenClaw-spezifische Dokumentation
- [GitHub](https://github.com/steges/homelab) – Quellcode
- [CHANGELOG](../../CHANGELOG.md) – Änderungshistorie
