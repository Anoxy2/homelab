# OpenClaw Skills – Vollständige Übersicht

> Alle Skills, ihre Funktion, Technologie und Integrationspunkte  
> Stand: April 2026

---

## Skills-Verzeichnis

```
/home/steges/agent/skills/
├── authoring/          # Code/Dokumentation erstellen
├── backup-automation/  # ⭐ NEU: USB Backup + nutzt github-automation
├── canary/             # Canary-Deployment
├── github-automation/  # ⭐ NEU: GitHub Operations (steipete/github)
├── coding/             # Code-Analyse & Refactor
├── core/               # Grundlegende Tools
├── growbox/            # Growbox-Automation
├── ha-control/         # Home Assistant Integration
├── health/             # System-Health
├── heartbeat/          # Heartbeat-System
├── learn/              # Lernen/Training
├── log-query/          # Log-Analyse (Loki)
├── metrics/            # Metrik-Abfragen
├── openclaw-rag/       # RAG-System (selbstreferentiell!)
├── openclaw-ui/        # Web UI
├── pi-control/         # Pi-Management
├── profile/            # User-Profile
├── runbook-maintenance/# Maintenance-Runbooks
├── scout/              # Code-Exploration
├── skill-forge/        # Skill-Development
├── vetting/            # Code-Review
├── vuln-watch/         # Vulnerability Monitoring
└── web-search/         # Web-Suche
```

---

## Core-Skills

### core/

**Zweck:** Grundlegende Agent-Fähigkeiten

| Skill | Funktion |
|-------|----------|
| `system.info` | System-Informationen |
| `file.read` | Dateien lesen |
| `file.write` | Dateien schreiben |
| `shell.exec` | Shell-Befehle |

---

## Self-Awareness & RAG

### openclaw-rag/

**Zweck:** Selbstreferenzielles Wissen über die Infrastruktur

| Komponente | Beschreibung |
|------------|--------------|
| `scripts/rag-dispatch.sh` | Haupt-Dispatcher |
| `scripts/rag-canary-smoke.sh` | Qualitäts-Check |
| `scripts/reindex.sh` | Neu-Indexierung |
| `GOLD-SET.json` | Kanonische Dokumente |
| `config/chroma.yaml` | Vektor-DB Config |

**Indexierte Themen:**
- Hardware (NVMe, Pi)
- Netzwerk (UFW, Ports)
- Docker (Services, Volumes)
- systemd (Timer, Services)
- Skills (alle 20+ Skills)
- CODS (Playbooks, Runbooks)

---

### openclaw-ui/

**Zweck:** Web-Interface für Agent-Interaktion

| Komponente | Beschreibung |
|------------|--------------|
| `html/` | Statische Web-UI |
| `state-brief.latest.json` | Aktueller Status |
| `ops-brief.latest.json` | Operations-Übersicht |
| `action-log.latest.json` | Aktions-Log |

**Features:**
- Canvas-UI für Agent-Interaktion
- Status-Dashboard
- Skill-Ausführung
- Log-Viewer

---

## Infrastruktur-Skills

### pi-control/

**Zweck:** Raspberry Pi Management

| Script | Funktion |
|--------|----------|
| `scripts/status-full.sh` | Vollständiger Status |
| `scripts/status-report.sh` | Kurz-Report |
| `scripts/docker-compose.sh` | Docker-Management |
| `tests/test-allowlist.sh` | Sicherheits-Tests |

**Capabilities:**
- Temperatur-Monitoring
- Disk-Usage
- Docker-Status
- Service-Status
- NVMe-Health

---

### runbook-maintenance/

**Zweck:** Automatisierte Wartung

| Script | Funktion | Trigger |
|--------|----------|---------|
| `runbook-maintenance-dispatch.sh` | Nightly Check | 03:00 Timer |

**Checks:**
- Disk-Usage > 80%
- NVMe-SMART
- Docker-Container (exited)
- Memory-Usage > 90%
- RAG-Quality

---

## Entwicklungs-Skills

### skill-forge/

**Zweck:** Skill-Development & Management

```
skill-forge/
├── .state/
│   ├── known-skills.json       # Skill-Registry
│   ├── canary.json            # Canary-Status
│   └── skill-risk-report.json # Risk-Assessment
├── policy/
│   ├── canary-criteria.yaml   # Exit-Kriterien
│   └── source-trust-policy.yaml # Trust-Policy
├── .state/provenance/         # Skill-Herkunft
│   └── openclaw-rag/
│       └── 0.1.0.json
└── scripts/
    └── forge-dispatch.sh
```

**Workflow:**
1. Skill erstellen
2. Canary-Test
3. Risk-Assessment
4. Release auf ClawHub

---

### coding/

**Zweck:** Code-Analyse & Refactoring

| Script | Funktion |
|--------|----------|
| `scripts/code-dispatch.sh` | Code-Operationen |

**Capabilities:**
- Lint (ShellCheck, etc.)
- Refactor-Vorschläge
- Security-Scan
- Complexity-Check

---

### scout/

**Zweck:** Code-Exploration

| Datei | Zweck |
|-------|-------|
| `config/hubs.json` | Repository-Index |
| `.state/curator-suggestions.json` | Vorschläge |

**Features:**
- Code-Suche über Repos
- Dependency-Graph
- API-Explorer

---

### vetting/

**Zweck:** Code-Review

| Script | Funktion |
|--------|----------|
| `scripts/vetting-dispatch.sh` | Review-Workflow |

**Checks:**
- Style-Guide
- Security-Issues
- Performance
- Test-Coverage

---

## Automation-Skills

### growbox/

**Zweck:** Growbox-Automation

| Script | Funktion | Trigger |
|--------|----------|---------|
| `growbox-daily-report.sh` | Täglicher Report | Cron |
| `growbox-diary.sh` | Diätagebuch | Manuell |

**Integration:**
- ESP32-Sensoren
- Home Assistant
- MQTT
- NTFY (Alerts)

---

### ha-control/

**Zweck:** Home Assistant Integration

| Script | Funktion |
|--------|----------|
| `scripts/ha-dispatch.sh` | HA-Operationen |

**Capabilities:**
- Geräte steuern
- Automatisierungen
- State-Queries
- Scene-Aktivierung

---

### heartbeat/

**Zweck:** Agent-Heartbeat

| Script | Funktion | Trigger |
|--------|----------|---------|
| `heartbeat-dispatch.sh` | Heartbeat | 07:00, 19:00 |

**Zweck:**
- Keep-Alive Signal
- Status-Update
- RAG-Reindex-Trigger

---

## Security-Skills

### vuln-watch/

**Zweck:** Vulnerability Monitoring

| Script | Funktion |
|--------|----------|
| `vuln-watch-dispatch.sh` | CVE-Check |

**Quellen:**
- NVD (National Vulnerability Database)
- GitHub Security Advisories
- Docker Image CVEs

---

### auth-failure-monitor/

**Zweck:** Auth-Failure Tracking

**Features:**
- SSH-Brute-Force Detection
- Fail2ban-Integration
- Alerting via NTFY

---

## Logging & Monitoring

### log-query/

**Zweck:** Log-Analyse via Loki

| Script | Funktion |
|--------|----------|
| `query-loki.sh` | LogQL-Queries |

**Beispiele:**
```bash
# OpenClaw Errors
{container_name="openclaw"} |= "error"

# Auth Failures
{job="auth"} |= "Failed password"

# Growbox Events
{container_name="growbox"} |= "alert"
```

---

### metrics/

**Zweck:** Prometheus-Metrics

| Script | Funktion |
|--------|----------|
| `query-prometheus.sh` | PromQL-Queries |

**Queries:**
```promql
# CPU-Usage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Disk-Usage
100 - ((node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100)

# OpenClaw Requests
rate(openclaw_requests_total[5m])
```

---

## Content-Skills

### authoring/

**Zweck:** Dokumentation erstellen

**Capabilities:**
- Markdown-Generierung
- API-Docs
- READMEs
- Changelogs

---

### web-search/

**Zweck:** Web-Suche

| Script | Funktion |
|--------|----------|
| `search.sh` | SearXNG-Query |

---

### learn/

**Zweck:** Lernen/Training

| Script | Funktion |
|--------|----------|
| `learn-dispatch.sh` | Lern-Workflow |

---

## Skill-Interaktionen

### Datenfluss

```
┌─────────────────────────────────────────────────────────────┐
│                     Agent (OpenClaw)                        │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  openclaw-rag│   │  heartbeat   │   │  runbook     │
│              │   │              │   │  maintenance │
│  Self-Knowl. │   │  07:00/19:00 │   │  03:00       │
└──────────────┘   └──────────────┘   └──────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  pi-control  │   │  growbox     │   │  vuln-watch  │
│  (System)    │   │  (IoT)       │   │  (Security)  │
└──────────────┘   └──────────────┘   └──────────────┘
```

---

## Skill-Entwicklung

### Neue Skills erstellen

```bash
# Template verwenden
cd /home/steges/agent/skills
mkdir my-skill

# Struktur
cat > my-skill/SKILL.md << 'EOF'
# My Skill

## Purpose
Beschreibung hier

## Tools

### myTool

Description: Was macht dieses Tool

Parameters:
- param1: string (required)
- param2: number (optional)

Handler:
```bash
#!/bin/bash
# Implementation
```
EOF
```

### Skill-Validierung

```bash
# Lint
/home/steges/scripts/lint-shell.sh my-skill/

# Canary-Test
/home/steges/agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh my-skill

# Risk-Check
/home/steges/agent/skills/skill-forge/scripts/risk-check.sh my-skill
```

---

## Wartung

### Skill-Update

```bash
# Alle Skills listen
ls -la /home/steges/agent/skills/

# Einen Skill aktualisieren
cd /home/steges/agent/skills/my-skill
git pull  # falls git repo

# Reindex RAG
/home/steges/agent/skills/openclaw-rag/scripts/reindex.sh
```

### Skill-Deaktivierung

```bash
# Umbenennen
mv /home/steges/agent/skills/my-skill \
   /home/steges/agent/skills/.disabled/my-skill

# Oder: Config
# in openclaw.json:
{
  "skills": {
    "disabled": ["my-skill"]
  }
}
```

---

## Automation-Skills

### github-automation/ ⭐ NEU

**Basierend auf:** [steipete/github](https://clawhub.ai/steipete/github) (ClawHub)

**Zweck:** GitHub CLI (`gh`) + git Operationen für andere Skills

| Komponente | Funktion |
|------------|----------|
| `SKILL.md` | Skill-Definition |
| `scripts/git-status.sh` | JSON-Status (clean, branch, ahead) |
| `scripts/git-commit.sh` | Commit mit Message |
| `scripts/git-push.sh` | Push zu origin |
| `scripts/gh-issue-create.sh` | Issue erstellen |

**Tools:**
- `github.git.status` – Repository-Status
- `github.git.commit` – Commit erstellen
- `github.git.push` – Push ausführen
- `github.issue.create` – Issue erstellen

**Verwendung:**
```bash
# Status
/home/steges/agent/skills/github-automation/scripts/git-status.sh

# Commit
/home/steges/agent/skills/github-automation/scripts/git-commit.sh "feat: new feature"

# Push
/home/steges/agent/skills/github-automation/scripts/git-push.sh
```

**Abhängigkeit:** Wird genutzt von `backup-automation`

---

### backup-automation/ ⭐ NEU

**Basierend auf:** skill-forge Template

**Zweck:** USB-Backup + Nutzt `github-automation` Skill für GitHub

| Komponente | Funktion | GitHub-Skill |
|------------|----------|--------------|
| `SKILL.md` | Skill-Definition | - |
| `scripts/backup-full.sh` | Orchestrator | ✅ Ruft github-automation auf |
| `scripts/backup-usb.sh` | USB rsync | ❌ Custom |
| `scripts/backup-status.sh` | Status | ✅ Ruft github-automation auf |
| `scripts/backup-verify.sh` | Verifikation | ❌ Custom |
| `scripts/backup-restore.sh` | Restore | ❌ Custom |
| `scripts/install.sh` | Installation | - |
| `systemd/*` | Timer & Services | - |

**Architektur:**
```
backup-full.sh
├── GitHub (delegated to github-automation)
│   ├── git-status.sh
│   ├── git-commit.sh
│   └── git-push.sh
└── USB (custom)
    └── backup-usb.sh
```

**Timer:**
- `backup-automation.timer` – Täglich 02:00
- `backup-verify.timer` – Sonntag 04:00

**Abhängigkeiten:**
- `github-automation` Skill (für GitHub-Operationen)
- `rsync`, `mount`

**Installation:**
```bash
# 1. Zuerst github-automation installieren
ls /home/steges/agent/skills/github-automation/

# 2. Dann backup-automation
sudo /home/steges/agent/skills/backup-automation/scripts/install.sh
```

**Verwendung:**
```bash
# Voll-Backup (nutzt github-automation + USB)
/home/steges/agent/skills/backup-automation/scripts/backup-full.sh

# Status
/home/steges/agent/skills/backup-automation/scripts/backup-status.sh
```

---

## Referenzen

- `openclaw-rag/GOLD-SET.json` – Kanonische Skill-Doku
- `skill-forge/` – Entwicklungs-Workflow
- `docs/infrastructure/skills-overview.md` – Diese Datei
- `docs/infrastructure/backup-automation-skill.md` – Backup-Skill Doku
