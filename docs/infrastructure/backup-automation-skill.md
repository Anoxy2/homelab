# Backup-Automation Skill

> Automatisiertes Backup mit **github-automation** Skill + USB-Scripts  
> Nutzt separaten GitHub Skill für alle Git-Operationen

---

## Überblick

| Eigenschaft | Wert |
|-------------|------|
| **Name** | `backup-automation` |
| **Basierend auf** | skill-forge Template |
| **Zweck** | USB-Backup + Nutzung von github-automation Skill |
| **Version** | 1.0.0 |
| **Ort** | `agent/skills/backup-automation/` |

---

## Zwei Separate Skills

### 1. github-automation (Dependency)

**Ort:** `agent/skills/github-automation/`

**Zweck:** Reine GitHub-Operationen (basierend auf steipete/github von ClawHub)

**Skripte:**
| Skript | Funktion |
|--------|----------|
| `git-status.sh` | Git-Status als JSON |
| `git-commit.sh` | Commit mit Message |
| `git-push.sh` | Push zu origin |
| `gh-issue-create.sh` | Issue erstellen |

### 2. backup-automation (USB + Orchestration)

**Ort:** `agent/skills/backup-automation/`

**Zweck:** USB-Backup + Nutzung von github-automation für GitHub

**Skripte:**
| Skript | Funktion | GitHub-Skill |
|--------|----------|--------------|
| `backup-full.sh` | Orchestrator | Ruft github-automation auf |
| `backup-usb.sh` | USB rsync | Custom |
| `backup-status.sh` | Status | Ruft github-automation auf |
| `backup-verify.sh` | Verifikation | Custom |
| `backup-restore.sh` | Restore | Custom |

---

## Architektur

```
┌─────────────────────────────────────────────────────────────┐
│                    backup-automation                        │
├─────────────────────────────────────────────────────────────┤
│  GitHub (delegated)        │  USB (custom)                  │
│  ├── github-automation/   │  ├── backup-usb.sh             │
│  │   ├── git-status.sh   │  ├── mount check               │
│  │   ├── git-commit.sh   │  ├── rsync (DBs, Secrets)      │
│  │   └── git-push.sh     │  └── cleanup 14d               │
│  └── called by:           │                                │
│      backup-full.sh       │                                │
│      backup-status.sh     │                                │
└─────────────────────────────────────────────────────────────┘
```

---

## Komponenten

### SKILL.md

**Metadaten:**
```yaml
name: backup-automation
description: Automated backup management for GitHub + USB dual strategy
version: 1.0.0
author: steges (via skill-forge)
dependencies: [git, gh, rsync, mount]
```

**Tools:**
- `backup.github.status` - Git-Status checken
- `backup.github.commit` - Commit + Push
- `backup.usb.status` - USB-Mount-Status
- `backup.usb.run` - USB-Backup ausführen
- `backup.full` - Komplett-Backup
- `backup.verify` - Integritätsprüfung

### Skripte

| Skript | Zweck | Größe |
|--------|-------|-------|
| `backup-full.sh` | Haupt-Orchestrator | ~200 Zeilen |
| `backup-github.sh` | Git-Operationen | ~150 Zeilen |
| `backup-usb.sh` | USB-Rsync | ~200 Zeilen |
| `backup-status.sh` | Status-Check | ~120 Zeilen |
| `backup-verify.sh` | Verifikation | ~150 Zeilen |
| `backup-restore.sh` | Wiederherstellung | ~180 Zeilen |

### systemd Integration

| Service/Timer | Zweck | Trigger |
|---------------|-------|---------|
| `backup-automation.service` | Ausführung | On-demand |
| `backup-automation.timer` | Tägliches Backup | 02:00 |
| `backup-github-check.timer` | GitHub-Check | Alle 6h |
| `backup-verify.timer` | Verifikation | Sonntag 04:00 |

---

## Datenfluss

### Täglicher Ablauf (02:00)

```
1. systemd Timer → backup-automation.service
2. backup-full.sh startet
3. ├── backup-github.sh
   │   ├── git status
   │   ├── git add -A
   │   ├── git commit
   │   └── git push
   │
   └── backup-usb.sh
       ├── mount check
       ├── rsync openclaw-memory/
       ├── rsync pihole/
       ├── rsync homeassistant/
       ├── rsync secrets/
       ├── create checksums
       └── cleanup >14d
4. State in .state/last-backup.json speichern
5. OpenClaw Notification senden
```

---

## Installation

### 1. Skill-Verzeichnis erstellen

```bash
# Bereits erstellt:
# agent/skills/backup-automation/
# ├── SKILL.md
# ├── scripts/
# │   ├── backup-full.sh
# │   ├── backup-github.sh
# │   ├── backup-usb.sh
# │   ├── backup-status.sh
# │   ├── backup-verify.sh
# │   └── backup-restore.sh
# ├── systemd/
# │   ├── backup-automation.service
# │   ├── backup-automation.timer
# │   ├── backup-github-check.timer
# │   └── backup-verify.timer
# └── .state/
```

### 2. Berechtigungen setzen

```bash
cd /home/steges/agent/skills/backup-automation/scripts
chmod +x *.sh
```

### 3. systemd Services installieren

```bash
# Symlinks erstellen
sudo ln -s /home/steges/agent/skills/backup-automation/systemd/backup-automation.service \
    /etc/systemd/system/
sudo ln -s /home/steges/agent/skills/backup-automation/systemd/backup-automation.timer \
    /etc/systemd/system/
sudo ln -s /home/steges/agent/skills/backup-automation/systemd/backup-github-check.timer \
    /etc/systemd/system/
sudo ln -s /home/steges/agent/skills/backup-automation/systemd/backup-verify.timer \
    /etc/systemd/system/

# Reload & Enable
sudo systemctl daemon-reload
sudo systemctl enable backup-automation.timer
sudo systemctl enable backup-github-check.timer
sudo systemctl enable backup-verify.timer
sudo systemctl start backup-automation.timer
sudo systemctl start backup-github-check.timer
sudo systemctl start backup-verify.timer
```

### 4. USB-Mount vorbereiten

```bash
# /etc/fstab Eintrag (UUID anpassen!)
echo 'UUID=1234-5678 /mnt/usb-backup ext4 defaults,noatime,nofail 0 0' | sudo tee -a /etc/fstab

# Mount-Verzeichnis erstellen
sudo mkdir -p /mnt/usb-backup

# Testen
sudo mount /mnt/usb-backup
```

---

## Verwendung

### Manuelles Backup

```bash
# Vollständiges Backup
/home/steges/agent/skills/backup-automation/scripts/backup-full.sh

# Mit custom Message
/home/steges/agent/skills/backup-automation/scripts/backup-full.sh \
    "backup: before system update"

# Nur GitHub
/home/steges/agent/skills/backup-automation/scripts/backup-full.sh \
    "" --skip-usb

# Nur USB
/home/steges/agent/skills/backup-automation/scripts/backup-full.sh \
    "" --skip-github
```

### Status checken

```bash
/home/steges/agent/skills/backup-automation/scripts/backup-status.sh

# Ausgabe:
# GitHub: OK (clean, branch: main, last: 2 hours ago)
# USB: OK (45% used, latest: 20260410)
# Last Backup: SUCCESS (20260410_020005)
```

### Verifikation

```bash
# Letztes Backup prüfen
/home/steges/agent/skills/backup-automation/scripts/backup-verify.sh

# Spezifisches Datum
/home/steges/agent/skills/backup-automation/scripts/backup-verify.sh 20260401
```

### Wiederherstellung

```bash
# Dry-Run (was würde passieren?)
/home/steges/agent/skills/backup-automation/scripts/backup-restore.sh --dry-run

# Letztes Backup restoren
/home/steges/agent/skills/backup-automation/scripts/backup-restore.sh

# Spezifisches Datum
/home/steges/agent/skills/backup-automation/scripts/backup-restore.sh 20260315

# Ohne Bestätigung
/home/steges/agent/skills/backup-automation/scripts/backup-restore.sh --yes
```

---

## OpenClaw Integration

### Automatische Notifications

| Event | Nachricht | Priorität |
|-------|-----------|-----------|
| Backup Success | ✅ Backup completed: GitHub + USB (DATE) | normal |
| Partial (GitHub OK, USB fail) | ⚠️ Backup partial: GitHub OK, USB failed | warning |
| Partial (USB OK, GitHub fail) | ⚠️ Backup partial: USB OK, GitHub failed | warning |
| Complete Failure | 🚨 Backup FAILED: Both GitHub and USB | critical |
| Verify Failed | 🚨 Backup verification failed | critical |

### Manuelle Nutzung via OpenClaw

```bash
# Über claw-send.sh
/home/steges/scripts/claw-send.sh "Backup status check"

# Oder direkt
docker exec openclaw openclaw agent \
    --message "Run backup status check" \
    --session backup
```

---

## State Management

### .state/last-backup.json

```json
{
  "timestamp": "20260410_020005",
  "date": "20260410",
  "github": {
    "success": true,
    "commit": "a1b2c3d"
  },
  "usb": {
    "success": true,
    "path": "/mnt/usb-backup/backups/20260410",
    "size_mb": 450,
    "files": 125
  },
  "overall_success": true
}
```

### .state/last-verify.json

```json
{
  "verified_at": "2026-04-10T04:00:00Z",
  "backup_date": "20260410",
  "status": "PASSED",
  "checks": {
    "completeness": true,
    "checksums": true,
    "sqlite": true
  }
}
```

---

## Vergleich: Alt vs. Neu

| Aspekt | Vorher (alt) | Nachher (backup-automation Skill) |
|--------|--------------|-----------------------------------|
| **Skripte** | `scripts/backup.sh`, `backup-daily.sh` | 6 spezialisierte Skripte |
| **Skill-Struktur** | ❌ Keine | ✅ SKILL.md, .state/, systemd/ |
| **OpenClaw Integration** | Manuelle claw-send.sh Aufrufe | ✅ Integrierte Notifications |
| **Status-Tracking** | ❌ Kein State | ✅ JSON State in .state/ |
| **Verifikation** | ❌ Keine | ✅ Weekly Verify |
| **Restore** | ❌ Kein Restore | ✅ backup-restore.sh |
| **systemd** | ❌ Manuelle Timer | ✅ 4 Timer/Services |
| **Dokumentation** | ❌ Inline | ✅ SKILL.md, separate Docs |

---

## Troubleshooting

### USB nicht gemountet

```bash
# Manuell mounten
sudo mount /mnt/usb-backup

# Oder fstab prüfen
cat /etc/fstab | grep usb-backup
```

### Git push failed

```bash
# Manuell pushen
cd /home/steges
git push origin main

# Oder GitHub Token prüfen
git remote -v
```

### Service logs

```bash
# systemd Logs
sudo journalctl -u backup-automation -f

# Script Logs
tail -f /var/log/backup-automation.log

# Status
systemctl list-timers backup-*
```

---

## Integration mit skill-forge

### Lifecycle

```
DISCOVERED -> DRAFTED -> CANARY -> ACTIVE
```

Dieser Skill ist im Status **ACTIVE** (produktiv).

### Provenance

```json
{
  "skill": "backup-automation",
  "version": "1.0.0",
  "author": "steges",
  "generated_by": "skill-forge",
  "based_on": [
    "skill-forge/templates/bash-script",
    "clawhub.ai/steipete/github"
  ],
  "created": "2026-04-10",
  "state": "ACTIVE"
}
```

---

## Referenzen

- `agent/skills/backup-automation/SKILL.md` - Haupt-Definition
- `agent/skills/backup-automation/scripts/` - Alle Skripte
- `agent/skills/backup-automation/systemd/` - Services/Timers
- `docs/infrastructure/backup-strategy.md` - Strategie-Doku
- `skill-forge/` - Generator-Framework
- [GitHub Skill auf ClawHub](https://clawhub.ai/steipete/github)
