# CODS – Central Operations Dispatch System

> Playbooks, Runbooks, und operative Prozeduren  
> Stand: April 2026

---

## Was ist CODS?

CODS ist Steges' zentrales Betriebssystem für:
- **C**entralized → Einheitliche Steuerung
- **O**perations → Tägliche Tasks
- **D**ispatch → Automatisierte Ausführung
- **S**ystem → Integrierte Infrastruktur

```
┌─────────────────────────────────────────┐
│              CODS Core                  │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │Playbooks│ │Runbooks │ │ Alerts  │   │
│  │(Plan)   │ │(Do)     │ │(React)  │   │
│  └────┬────┘ └────┬────┘ └────┬────┘   │
│       └───────────┼───────────┘        │
│                   ▼                     │
│         ┌─────────────────┐            │
│         │  Dispatch Layer │            │
│         │  (systemd/shell)│            │
│         └────────┬────────┘            │
│                  ▼                      │
│    ┌──────────┬──────────┬──────────┐│
│    │OpenClaw  │Docker    │Scripts   ││
│    │Agent     │Compose   │          ││
│    └──────────┴──────────┴──────────┘│
└─────────────────────────────────────────┘
```

---

## Playbooks (Strategie)

### Definition

Playbooks sind **höherwertige, proaktive Pläne** für:
- Neue Features einführen
- Infrastruktur-Changes
- Wartungs-Fenster planen

### Aktuelle Playbooks

| Playbook | Zweck | Status |
|----------|-------|--------|
| **Pi-4-to-Pi-5-Migration** | Hardware-Upgrade | Planned |
| **NVMe-Expansion** | 250GB → 1TB | Planned |
| **OpenClaw-v2-Migration** | Update auf neues API | In Progress |
| **Backup-Offsite** | B2-Integration | Active |
| **Network-Segmentation** | VLANs einführen | Backlog |

### Playbook-Template

```markdown
# Playbook: [Name]

## Objective
Was soll erreicht werden?

## Success Criteria
- [ ] Kriterium 1
- [ ] Kriterium 2

## Pre-Conditions
- Abhängigkeit A
- Abhängigkeit B

## Timeline
- Week 1: Planung
- Week 2: Test
- Week 3: Rollout

## Rollback Plan
Wie zurück bei Fehler?

## Post-Review
Lessons learned
```

---

## Runbooks (Taktik)

### Definition

Runbooks sind **operative, reaktive Schritt-für-Schritt-Anleitungen** für:
- Incident Response
- Wartungstasks
- Troubleshooting

### Kategorien

| Kategorie | Anzahl | Beispiele |
|-----------|--------|-----------|
| **Infrastructure** | 8 | Disk full, Service down, Reboot |
| **Security** | 5 | Auth failure, Cert expiry, CVE |
| **Application** | 6 | OpenClaw restart, RAG reindex |
| **Growbox** | 4 | Sensor offline, Alert handling |

### Runbook: Disk Full

```markdown
# Runbook: Disk Full Response

## Trigger
Alert: `disk_usage > 80%`

## Steps

### 1. Identify
```bash
# Größte Verzeichnisse
du -h / | sort -rh | head -20

# Docker-Volumes
docker system df -v
```

### 2. Clean
```bash
# Docker cleanup
docker system prune -a --volumes

# Logs rotaten
sudo logrotate -f /etc/logrotate.conf

# Journal clean
sudo journalctl --vacuum-size=100M
```

### 3. Verify
```bash
df -h /
# Should be < 80%
```

### 4. Document
- Incident in log
- Root cause analysis
- Prevention measures

## Escalation
If > 90% and cannot free space:
1. Notify via NTFY
2. Consider emergency reboot
3. Check for log flooding attack
```

### Runbook: OpenClaw Recovery

```markdown
# Runbook: OpenClaw Recovery

## Trigger
- Agent not responding
- Gateway down
- Memory corruption

## Steps

### 1. Check Status
```bash
docker ps | grep openclaw
# Should show 'Up'

# Gateway responsive?
curl -s http://192.168.2.101:18789/status
```

### 2. Restart
```bash
# Soft restart
docker restart openclaw

# Or via systemd
sudo systemctl restart openclaw-compose
```

### 3. Verify
```bash
docker logs openclaw --tail 50
docker exec openclaw openclaw doctor
```

### 4. RAG Check
```bash
/home/steges/agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh
```

## Escalation
If restart fails 3x:
1. Check NVMe health: `smartctl -H /dev/nvme0`
2. Review recent changes: `git log --since="24 hours ago"`
3. Full reboot as last resort
```

---

## Automatisierte Runbooks (Services)

### runbook-maintenance (Timer-gesteuert)

```
Trigger: 03:00 daily
Script: /home/steges/agent/skills/runbook-maintenance/scripts/runbook-maintenance-dispatch.sh
```

**Ausgeführte Checks:**
1. Disk-Usage (Warnung bei > 70%, Alert bei > 80%)
2. NVMe-SMART (Health-Status)
3. Docker-Container ("exited" Detection)
4. Memory-Usage (Alert bei > 90%)
5. RAG-Quality-Check
6. Certificate-Expiry (< 30 Tage)

### Ergebnis

```json
{
  "timestamp": "2026-04-10T03:05:00Z",
  "checks": {
    "disk": {"status": "ok", "usage": "42%"},
    "nvme": {"status": "ok", "health": "PASSED"},
    "docker": {"status": "ok", "exited": 0},
    "memory": {"status": "ok", "usage": "67%"},
    "rag": {"status": "ok", "quality": 0.95},
    "certs": {"status": "ok", "expiring_soon": []}
  },
  "overall": "healthy"
}
```

---

## Alert-Routing

### Severity-Levels

| Level | Trigger | Response | Channels |
|-------|---------|----------|----------|
| **CRITICAL** | Service down, Data loss | Immediate | NTFY + Telegram |
| **HIGH** | Disk > 90%, Security breach | < 5 min | NTFY |
| **MEDIUM** | Disk > 80%, High load | < 30 min | Log + Digest |
| **LOW** | Warnings, Info | Daily digest | Log only |

### Routing-Regeln

```yaml
# /home/steges/alertmanager/config.yml
routes:
  - match:
      severity: critical
    receiver: 'critical-channel'
    continue: true
    
  - match:
      severity: high
    receiver: 'ntfy-push'
    
  - match:
      alertname: 'DiskFull'
    receiver: 'runbook-auto'
    group_wait: 0s
    group_interval: 5m
```

### Receiver

| Receiver | Methode | Ziel |
|----------|---------|------|
| `critical-channel` | NTFY + Telegram | Push |
| `ntfy-push` | NTFY | Push |
| `runbook-auto` | Webhook | Auto-fix attempt |
| `email` | SMTP | Gmail |

---

## CODS-Integration mit OpenClaw

### Self-Awareness

```
OpenClaw Agent ──► RAG (docs/infrastructure/) ──► Antworten
                        ▲
                        │
              CODS Playbooks/Runbooks ──► Aktualisiert
```

### Use-Cases

| Frage | CODS-Antwort via RAG |
|-------|----------------------|
| "Warum ist Port 18789 offen?" | Netzwerk-Doku, UFW-Regeln |
| "Welche Docker-Container laufen?" | Docker-Compose-Doku |
| "Was ist wenn die NVMe voll ist?" | Runbook: Disk Full |
| "Wann läuft der nächste Heartbeat?" | systemd Timer-Doku |
| "Welche Skills gibt es?" | Skills-Übersicht |

---

## CODS-Struktur

```
CODS/
├── playbooks/
│   ├── hardware/
│   │   └── pi-4-to-5-migration.md
│   ├── storage/
│   │   └── nvme-expansion.md
│   └── software/
│       └── openclaw-v2-migration.md
│
├── runbooks/
│   ├── infrastructure/
│   │   ├── disk-full.md
│   │   ├── service-down.md
│   │   ├── network-outage.md
│   │   └── reboot-required.md
│   ├── security/
│   │   ├── auth-failure-spike.md
│   │   ├── cert-expiry.md
│   │   ├── cve-response.md
│   │   └── firewall-block.md
│   ├── application/
│   │   ├── openclaw-recovery.md
│   │   ├── rag-reindex.md
│   │   ├── docker-cleanup.md
│   │   └── backup-restore.md
│   └── growbox/
│       ├── sensor-offline.md
│       ├── alert-threshold.md
│       └── climate-control.md
│
├── dispatchers/
│   ├── systemd/
│   │   ├── runbook-maintenance.service
│   │   ├── runbook-maintenance.timer
│   │   └── alert-dispatcher.service
│   └── scripts/
│       ├── dispatch-alert.sh
│       ├── dispatch-runbook.sh
│       └── dispatch-playbook.sh
│
└── registry/
    ├── known-playbooks.json
    ├── known-runbooks.json
    └── execution-log.json
```

---

## CODS-API (für Skills)

### Playbook abfragen

```bash
# Liste
curl /api/cods/playbooks

# Einzelnes
curl /api/cods/playbooks/pi-4-to-5-migration
```

### Runbook ausführen

```bash
# Manual trigger
curl -X POST /api/cods/runbooks/disk-full/execute

# Mit Parametern
curl -X POST /api/cods/runbooks/service-down/execute \
  -d '{"service": "openclaw"}'
```

### Status

```bash
curl /api/cods/status
```

---

## Wartung

### Playbook-Review (Quartalsweise)

- [ ] Veraltete Playbooks archivieren
- [ ] Neue Projekte aufnehmen
- [ ] Success-Criteria aktualisieren

### Runbook-Testing (Monatlich)

```bash
# Test-Disk-Full (simuliert)
fallocate -l 200G /tmp/test-big-file
/home/steges/agent/skills/runbook-maintenance/scripts/runbook-maintenance-dispatch.sh
rm /tmp/test-big-file
```

### Dokumentation

- Jede Änderung in CHANGELOG.md
- Post-Mortems nach Incidents
- Lessons learned in Playbooks

---

## Integration mit bestehenden Tools

| Tool | Integration |
|------|-------------|
| **systemd** | Timer + Service-Dispatcher |
| **Prometheus** | Metrics für Alerting |
| **Alertmanager** | Routing + Deduplizierung |
| **OpenClaw** | RAG-Self-Awareness |
| **NTFY** | Push-Notifications |
| **Telegram** | Critical-Alerts |

---

## Vision: Vollständige Automation

```
Zukunft:
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Detect    │───→│   Decide    │───→│    Act      │
│  (Prometheus│    │  (OpenClaw  │    │  (Runbook   │
│   Alerts)   │    │   + RAG)    │    │   Exec)     │
└─────────────┘    └─────────────┘    └─────────────┘
                          │
                    ┌─────┴─────┐
                    ▼           ▼
              ┌─────────┐  ┌─────────┐
              │  Auto   │  │ Manual  │
              │  (90%)  │  │ (10%)   │
              └─────────┘  └─────────┘
```

---

## Referenzen

- `agent/skills/runbook-maintenance/` – Automated Runbooks
- `systemd/*` – Dispatch-Layer
- `docs/infrastructure/` – Wissensbasis für RAG
- `CHANGELOG.md` – Historie
