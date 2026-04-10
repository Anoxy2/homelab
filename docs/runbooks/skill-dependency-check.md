# Skill Dependency Health Check

> Überprüfung der Skill-Abhängigkeiten  
> Diagnose und Fix für broken dependencies

---

## Überblick

### Skill-Abhängigkeiten Graph

```
github-automation/
└── Wird genutzt von:
    └── backup-automation/
        ├── backup-full.sh
        └── backup-status.sh

skill-forge/
└── Wird genutzt von:
    ├── backup-automation/
    └── github-automation/
```

---

## Schnell-Check

### Alle Skills prüfen

```bash
#!/bin/bash
# skill-health-check.sh

SKILL_DIR="/home/steges/agent/skills"

echo "=== Skill Health Check ==="
echo ""

for skill in "$SKILL_DIR"/*/; do
    name=$(basename "$skill")
    echo "Checking: $name"
    
    # SKILL.md vorhanden?
    if [[ -f "$skill/SKILL.md" ]]; then
        echo "  ✅ SKILL.md exists"
    else
        echo "  ❌ Missing SKILL.md"
    fi
    
    # Scripts-Verzeichnis?
    if [[ -d "$skill/scripts" ]]; then
        script_count=$(ls "$skill/scripts/"*.sh 2>/dev/null | wc -l)
        echo "  ✅ Scripts: $script_count"
    fi
    
    # Dependencies prüfen
    if [[ -f "$skill/SKILL.md" ]]; then
        deps=$(grep "dependencies:" "$skill/SKILL.md" | cut -d: -f2 | tr -d '[]')
        if [[ -n "$deps" ]]; then
            echo "  📦 Dependencies: $deps"
            
            # Prüfe ob andere Skills existieren
            for dep in $(echo "$deps" | tr ',' ' '); do
                dep=$(echo "$dep" | xargs)  # trim
                if [[ "$dep" == "github-automation" ]]; then
                    if [[ -d "$SKILL_DIR/github-automation" ]]; then
                        echo "    ✅ $dep found"
                    else
                        echo "    ❌ $dep MISSING"
                    fi
                fi
            done
        fi
    fi
    
    echo ""
done
```

---

## Szenario 1: github-automation fehlt

### Symptome

```bash
# backup-full.sh läuft:
ERROR: github-automation skill not found at /home/steges/agent/skills/github-automation/scripts
```

### Diagnose

```bash
# Check
ls -la /home/steges/agent/skills/github-automation/

# Sollte zeigen:
# SKILL.md
# scripts/
```

### Lösung

```bash
# 1. github-automation existiert nicht
# → Muss neu erstellt werden

# 2. Falls nur verschoben/umbenannt:
# Link erstellen
ln -s /path/to/actual/github-automation \
    /home/steges/agent/skills/github-automation

# 3. Oder backup-automation anpassen:
# GITHUB_SKILL Variable in backup-full.sh ändern
```

---

## Szenario 2: Script fehlt in Dependency

### Symptome

```bash
./backup-full.sh: line 62: ../github-automation/scripts/git-status.sh: No such file or directory
```

### Diagnose

```bash
# Check welches Script fehlt
ls /home/steges/agent/skills/github-automation/scripts/

# Sollte haben:
# git-status.sh
# git-commit.sh
# git-push.sh
```

### Lösung

```bash
# 1. Script neu erstellen
# → Siehe docs/infrastructure/skills-overview.md

# 2. Oder backup-automation fallback:
# backup-full.sh sollte checken ob Script existiert
```

---

## Szenario 3: Permission denied

### Symptome

```bash
./git-status.sh: Permission denied
```

### Diagnose

```bash
# Permissions prüfen
ls -la /home/steges/agent/skills/github-automation/scripts/git-status.sh

# Sollte zeigen:
# -rwxr-xr-x 1 steges steges ... git-status.sh
```

### Lösung

```bash
# Fix permissions
chmod +x /home/steges/agent/skills/*/scripts/*.sh

# Oder install.sh laufen lassen
sudo /home/steges/agent/skills/backup-automation/scripts/install.sh
```

---

## Szenario 4: Path-Resolution failed

### Problem

Relative Pfade funktionieren nicht:
```bash
../github-automation/scripts/git-status.sh
```

### Lösung

```bash
# Absoluten Pfad nutzen
readonly GITHUB_SKILL="/home/steges/agent/skills/github-automation/scripts"

# Check
if [[ ! -f "$GITHUB_SKILL/git-status.sh" ]]; then
    echo "ERROR: github-automation skill not found"
    exit 1
fi
```

---

## Szenario 5: Version-Mismatch

### Problem

Skill A erwartet Funktion X, Skill B hat nur Funktion Y.

### Lösung

```bash
# SKILL.md version check
# In backup-automation/SKILL.md:
# dependencies: [github-automation >= 1.0.0]

# Prüfen:
grep "version:" /home/steges/agent/skills/github-automation/SKILL.md
```

---

## Szenario 6: Zirkuläre Dependencies

### Problem

```
A → B → C → A (Zirkel!)
```

### Check

```bash
# Sollte nicht passieren, aber prüfen:
# github-automation hat keine dependencies
# backup-automation hängt von github-automation ab
# Keine Rückwärts-Abhängigkeit
```

---

## Automatischer Health-Check

### Script

```bash
#!/bin/bash
# /home/steges/scripts/skill-health-check.sh

readonly SKILL_DIR="/home/steges/agent/skills"
readonly STATE_FILE="$SKILL_DIR/.state/health.json"

ERRORS=0

check_skill() {
    local skill=$1
    local name=$(basename "$skill")
    
    # Check SKILL.md
    [[ ! -f "$skill/SKILL.md" ]] && {
        echo "❌ $name: Missing SKILL.md"
        ((ERRORS++))
        return
    }
    
    # Check dependencies
    local deps=$(grep -oP 'dependencies: \[\K[^\]]+' "$skill/SKILL.md" 2>/dev/null)
    for dep in $(echo "$deps" | tr ',' ' '); do
        dep=$(echo "$dep" | xargs)
        [[ "$dep" == "rsync" || "$dep" == "git" ]] && continue
        
        if [[ ! -d "$SKILL_DIR/$dep" ]]; then
            echo "❌ $name: Dependency '$dep' not found"
            ((ERRORS++))
        fi
    done
    
    # Check executable scripts
    if [[ -d "$skill/scripts" ]]; then
        for script in "$skill/scripts/"*.sh; do
            [[ -x "$script" ]] || {
                echo "⚠️  $name: $(basename $script) not executable"
            }
        done
    fi
}

# Run checks
mkdir -p "$SKILL_DIR/.state"
echo "{\"timestamp\": \"$(date -Iseconds)\", \"checks\": [" > "$STATE_FILE"

for skill in "$SKILL_DIR"/*/; do
    check_skill "$skill"
done

echo ""]" >> "$STATE_FILE"

# Summary
if [[ $ERRORS -eq 0 ]]; then
    echo "✅ All skills healthy"
    exit 0
else
    echo "❌ $ERRORS skill issues found"
    exit 1
fi
```

### Cron

```bash
# Täglich um 08:00
0 8 * * * /home/steges/scripts/skill-health-check.sh || \
    /home/steges/scripts/claw-send.sh "🚨 Skill health check failed"
```

---

## Dependency Management

### SKILL.md Format

```yaml
# Standard Format für dependencies:
dependencies: 
  - github-automation  # Skill-Name
  - rsync             # System-Package
  - git >= 2.30       # Mit Version
```

### Install-Script

```bash
# In install.sh:
# 1. System dependencies prüfen
command -v rsync >/dev/null || sudo apt install rsync
command -v git >/dev/null || sudo apt install git

# 2. Skill dependencies prüfen
if [[ ! -d "/home/steges/agent/skills/github-automation" ]]; then
    echo "ERROR: github-automation skill required"
    echo "Install: https://clawhub.ai/steipete/github"
    exit 1
fi
```

---

## Verweise

- `docs/infrastructure/skills-overview.md` – Skill-Übersicht
- `docs/skills/skill-forge-governance.md` – Skill-Development
- `agent/skills/backup-automation/SKILL.md` – Dependency-Beispiel
