# Skill Dependencies Graph

> Abhängigkeiten zwischen Skills visualisiert  
> Wer nutzt wen? Zirkuläre Abhängigkeiten vermeiden.

---

## Aktueller Stand (April 2026)

### Dependency Graph

```
┌─────────────────────────────────────────────────────────────────┐
│                        CORE SKILLS                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐      ┌──────────────────┐                  │
│  │ core/            │      │ skill-forge/     │                  │
│  │ (system.info,    │      │ (templates,      │                  │
│  │  file.read)      │      │  governance)     │                  │
│  └────────┬─────────┘      └────────┬─────────┘                  │
│           │                         │                            │
│           │  ▲                      │  ▲                         │
│           │  │                      │  │                         │
│           └──┼──────────────────────┘  │                         │
│              │                         │                         │
│              │    Alle Skills nutzen   │                         │
│              │    diese beiden         │                         │
│              │                         │                         │
│  ┌───────────┴─────────────────────────┴───────────┐              │
│  │                                                │              │
│  │              AUTOMATION SKILLS                 │              │
│  │                                                │              │
│  │  ┌──────────────────────────────────────┐      │              │
│  │  │ github-automation/                   │      │              │
│  │  │ • git-status.sh                      │      │              │
│  │  │ • git-commit.sh                      │      │              │
│  │  │ • git-push.sh                        │      │              │
│  │  │ • gh-issue-create.sh                 │      │              │
│  │  │                                      │      │              │
│  │  │ Based on: steipete/github (ClawHub)  │      │              │
│  │  └────────┬──────────────────────────────┘      │              │
│  │           │  ▲                                  │              │
│  │           │  │                                  │              │
│  │           │  │ Dependency: github-automation     │              │
│  │           │  │ required for GitHub ops        │              │
│  │           │  │                                  │              │
│  │  ┌────────┴──┐                                │              │
│  │  │ backup-   │                                │              │
│  │  │ automation/│                                │              │
│  │  │           │                                │              │
│  │  │ USB:      │── Custom scripts               │              │
│  │  │ • backup- │   (backup-usb.sh, etc)         │              │
│  │  │   usb.sh  │                                │              │
│  │  │ • backup- │                                │              │
│  │  │   verify  │                                │              │
│  │  │           │                                │              │
│  │  │ GitHub:   │── Delegated to                 │              │
│  │  │ Calls     │   github-automation/            │              │
│  │  │ ../github │                                │              │
│  │  │ -automat..│                                │              │
│  │  │ /scripts/ │                                │              │
│  │  └───────────┘                                │              │
│  │                                                │              │
│  └────────────────────────────────────────────────┘              │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────────┐│
│  │                    OTHER SKILLS (20+)                         ││
│  │                                                              ││
│  │  health/ ──► check-disk-space.sh                             ││
│  │           │  (siehe backup-monitoring.md)                    ││
│  │           │                                                  ││
│  │  openclaw-rag/ ──► SKILL.md                                  ││
│  │                 │  (wird von allen gelesen)                  ││
│  │                 │                                            ││
│  │  heartbeat/ ──► HEARTBEAT.md                                 ││
│  │              │  (checkt skills/ Ordner)                       ││
│  │              │                                               ││
│  └──────────────┴───────────────────────────────────────────────┘│
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Detaillierte Abhängigkeiten

### github-automation

**Bietet an (Exports):**
| Script | Funktion | Nutzer |
|--------|----------|--------|
| `git-status.sh` | JSON Git-Status | backup-automation |
| `git-commit.sh` | Commit mit Message | backup-automation |
| `git-push.sh` | Push zu origin | backup-automation |
| `gh-issue-create.sh` | Issue erstellen | (standalone) |

**Abhängigkeiten (Imports):**
- `git` (System-Package)
- `gh` (System-Package)
- `jq` (System-Package, für JSON)

---

### backup-automation

**Bietet an (Exports):**
| Script | Funktion | Nutzer |
|--------|----------|--------|
| `backup-usb.sh` | USB-Rsync | standalone |
| `backup-verify.sh` | Integritätscheck | standalone |
| `backup-restore.sh` | Restore aus USB | standalone |
| `backup-status.sh` | Status-Anzeige | standalone |
| `backup-full.sh` | Orchestrator | systemd timer |

**Abhängigkeiten (Imports):**
| Dependency | Wofür | Typ |
|------------|-------|-----|
| `github-automation/scripts/git-status.sh` | Git-Check | Skill |
| `github-automation/scripts/git-commit.sh` | Commit | Skill |
| `github-automation/scripts/git-push.sh` | Push | Skill |
| `rsync` | USB-Backup | System |
| `mount` | USB-Mount | System |
| `sqlite3` | DB Verify | System |

**Code-Ausschnitt (Dependency-Check):**
```bash
# backup-full.sh
readonly GITHUB_SKILL="/home/steges/agent/skills/github-automation/scripts"

if [[ ! -d "$GITHUB_SKILL" ]]; then
    echo "ERROR: github-automation skill not found"
    exit 1
fi

# Aufruf:
"$GITHUB_SKILL/git-status.sh"
"$GITHUB_SKILL/git-commit.sh" -m "$message"
"$GITHUB_SKILL/git-push.sh"
```

---

## System-Abhängigkeiten

### Von allen Skills genutzt

| Package | Nutzer | Zweck |
|---------|--------|-------|
| `jq` | github-automation, backup-automation | JSON Parsing |
| `rsync` | backup-automation | File Sync |
| `sqlite3` | backup-automation | DB Verify |
| `curl` | health, heartbeat | HTTP Checks |
| `docker` | health, multiple | Container Ops |

---

## Anti-Patterns vermeiden

### ❌ Zirkuläre Abhängigkeiten

```
# NICHT SO:
A/ → B/ → C/ → A/  (Zirkel!)

# SO:
A/ → B/ → C/        (Baum-Struktur)
```

### ❌ Deep Dependency Chains

```
# NICHT SO:
A → B → C → D → E  (Zu tief!)

# BESSER:
A → B
A → C
A → D
```

### ❌ Version-Mismatch

```
# NICHT SO:
backup-automation erwartet github-automation v2.0
aber github-automation ist v1.0

# LÖSUNG:
# In SKILL.md versions deklarieren
dependencies: [github-automation >= 1.0.0]
```

---

## Best Practices

### ✅ Relative Pfade nutzen

```bash
# backup-automation ruft github-automation:
readonly GITHUB_SKILL="/home/steges/agent/skills/github-automation/scripts"

# Nicht:
# readonly GITHUB_SKILL="$HOME/agent/skills/..."  (env-var abhängig)
# readonly GITHUB_SKILL="../github-automation/..."  (cwd abhängig)
```

### ✅ Graceful Degradation

```bash
# Skill sollte auch ohne Dependency laufen (reduzierter Modus)

if [[ -f "$GITHUB_SKILL/git-status.sh" ]]; then
    # Full mode mit GitHub
    "$GITHUB_SKILL/git-status.sh"
else
    # Fallback: nur USB-Backup
    echo "WARNING: github-automation not found, USB backup only"
fi
```

### ✅ Dependency Injection

```bash
# Nicht hardcoded:
# readonly GITHUB_SKILL="/fixed/path"

# Besser: Configurierbar
readonly GITHUB_SKILL="${GITHUB_SKILL_PATH:-/home/steges/agent/skills/github-automation/scripts}"
```

---

## Health-Checks

### Automatische Prüfung

```bash
#!/bin/bash
# skill-dependency-check.sh

SKILL_DIR="/home/steges/agent/skills"

check_dependencies() {
    local skill=$1
    local skill_name=$(basename "$skill")
    
    # Parse SKILL.md
    local deps=$(grep "dependencies:" "$skill/SKILL.md" 2>/dev/null | \
                 sed 's/dependencies: \[\(.*\)\]/\1/' | tr ',' '\n')
    
    for dep in $deps; do
        dep=$(echo "$dep" | xargs | tr -d '"')
        
        # Skip system packages
        [[ "$dep" =~ ^(git|rsync|jq|curl|docker|mount)$ ]] && continue
        
        # Check skill exists
        if [[ ! -d "$SKILL_DIR/$dep" ]]; then
            echo "❌ $skill_name: Missing dependency '$dep'"
        else
            echo "✅ $skill_name: $dep OK"
        fi
    done
}

# Check all skills
for skill in "$SKILL_DIR"/*/; do
    [[ -f "$skill/SKILL.md" ]] && check_dependencies "$skill"
done
```

---

## Neue Skill-Struktur

### Template für neue Skills

```markdown
---
name: my-skill
description: Does something useful
dependencies: [core, other-skill]
---

# my-skill

## Purpose
...

## Dependencies
- `core` - System operations
- `other-skill` - Specific functionality
```

---

## Statistik

| Metrik | Wert |
|--------|------|
| Total Skills | 22 |
| Mit Dependencies | 5 |
| Core Skills (0 deps) | 17 |
| Dependency Depth (max) | 2 |
| Zirkuläre Abhängigkeiten | 0 ✅ |

---

## Verweise

- `docs/runbooks/skill-dependency-check.md` – Troubleshooting
- `agent/skills/backup-automation/SKILL.md` – Dependency-Beispiel
- `agent/skills/github-automation/SKILL.md` – Provider-Beispiel
