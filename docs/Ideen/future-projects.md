# Future Projects & Roadmap

> Ideen und geplante Projekte für das Homelab  
> Stand: April 2026

---

## 🚀 Aktive Projekte

| Projekt | Status | Priorität | ETA |
|---------|--------|-----------|-----|
| Backup-Automation Skill | ✅ Done | Hoch | April 2026 |
| GitHub-Automation Skill | ✅ Done | Hoch | April 2026 |
| USB + GitHub Dual Backup | ✅ Done | Hoch | April 2026 |

---

## 📋 Geplante Projekte (Q2 2026)

### Infrastructure

| Projekt | Beschreibung | Komplexität |
|---------|--------------|-------------|
| **ZFS auf USB** | ZFS statt ext4 für bessere Checksummen | Mittel |
| **Offsite Backup** | Syncthing oder rsync zu zweitem Pi | Mittel |
| **UPS Integration** | APC UPS für graceful shutdown | Niedrig |
| **Second Pi** | Pi 4 oder 5 als Hot-Standby | Hoch |

### Monitoring & Alerting

| Projekt | Beschreibung | Komplexität |
|---------|--------------|-------------|
| **Uptime Kuma Ausbau** | Mehr Checks, Status Page | Niedrig |
| **Grafana Dashboards** | Custom Panels für Homelab | Mittel |
| **Alert Manager** | PagerDuty/Opsgenie Integration | Mittel |
| **Log Aggregation** | Loki + Promtail Ausbau | Mittel |

### Networking

| Projekt | Beschreibung | Komplexität |
|---------|--------------|-------------|
| **VLANs** | IoT/Guest/Main Netzwerke trennen | Hoch |
| **WireGuard Mesh** | Site-to-Site VPN | Mittel |
| **Reverse Proxy 2.0** | Caddy → Traefik Evaluation | Niedrig |

---

## 💡 Skill-Ideen

### Neue Skills für OpenClaw

| Skill | Zweck | Priorität |
|-------|-------|-----------|
| `ups-monitor` | UPS Status, Shutdown bei Stromausfall | Mittel |
| `zfs-admin` | ZFS Pool Management, Snapshots | Hoch |
| `network-scan` | Nmap Integration, Geräte Discovery | Niedrig |
| `cert-manager` | Let's Encrypt Renewal Checks | Niedrig |
| `docker-gc` | Automated Docker Cleanup | Niedrig |
| `smart-monitor` | NVMe/SATA SMART Health | Mittel |
| `cloud-sync` | S3/Backblaze Sync für Offsite | Hoch |

### Skill-Verbesserungen

| Skill | Verbesserung |
|-------|--------------|
| `backup-automation` | ZFS Support, Cloud Tier |
| `github-automation` | PR Management, Actions Trigger |
| `health` | SMART-Daten, Temperatur-Tracking |

---

## 🔄 Experimente

### Laufende Versuche

```
[2026-04-10] Backup-Skill mit skill-forge
Status: Erfolgreich abgeschlossen
Learnings: Skill-Dependencies funktionieren gut
```

### Geplante Experimente

| Experiment | Ziel | Dauer |
|------------|------|-------|
| **ZFS on USB** | Btrfs vs ZFS für Backup | 2 Wochen |
| **Kanidm/Authelia** | SSO für alle Services | 1 Woche |
| **K3s statt Docker** | Kubernetes Evaluation | 1 Monat |
| **NixOS** | Reproducible Setup | 2 Wochen |

---

## 🛒 Hardware-Wunschliste

| Item | Zweck | Budget | Priorität |
|------|-------|--------|-----------|
| Second Pi 5 8GB | Hot-Standby/HA | €80 | Hoch |
| 2TB NVMe (2x) | ZFS Mirror | €200 | Mittel |
| APC Back-UPS 650 | Power Protection | €80 | Hoch |
| 1TB USB-C SSD | Secondary Backup | €100 | Niedrig |
| PoE Hat für Pi 5 | Cleaner Wiring | €30 | Niedrig |

---

## 📅 Roadmap Timeline

```
April 2026 (Jetzt)
├── ✅ Backup-Automation Skills
└── ✅ GitHub + USB Backup

Mai 2026
├── UPS Integration
├── ZFS Experiment
└── Uptime Kuma Ausbau

Q3 2026
├── Second Pi Setup
├── Offsite Backup
└── VLAN Segmentation

Q4 2026
├── K3s Evaluation
├── SSO Implementation
└── Cloud Sync Skill
```

---

## 📝 Notizen

### Random Ideas

- **GitOps für Homelab**: ArgoCD oder Flux für Config-Management
- **Infrastructure as Code**: Terraform/Pulumi für Cloud-Resourcen
- **Home Assistant Dashboard**: Custom Lovelace für Pi-Status
- **AI Modelle Hosten**: Ollama für lokale LLMs
- **Matrix-Server**: Eigene Chat-Instanz
- **Jellyfin**: Media Server für lokale Dateien

### Anti-Goals (Wir machen das NICHT)

- ❌ Cloud-Abhängigkeit (AWS/GCP/Azure)
- ❌ Proprietäre Software wo Open Source geht
- ❌ Over-Engineering (KISS Prinzip)
- ❌ 24/7 Energie-Fresser (Pi = 5W Limit)

---

## 🔗 Verweise

- `docs/decisions/` – Architektur-Entscheidungen
- `docs/operations/open-work-todo.md` – Aktuelle Tasks
- `docs/skills/skill-build-plan.md` – Skill-Roadmap
