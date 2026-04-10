# GitHub-Automation Skill

> Standalone Skill für GitHub-Operationen  
> Basiert auf [steipete/github](https://clawhub.ai/steipete/github) von ClawHub

---

## Überblick

| Eigenschaft | Wert |
|-------------|------|
| **Name** | `github-automation` |
| **Basierend auf** | [steipete/github](https://clawhub.ai/steipete/github) (ClawHub) |
| **Zweck** | GitHub CLI (`gh`) + Git-Operationen |
| **Version** | 1.0.0 |
| **Ort** | `agent/skills/github-automation/` |
| **Abhängigkeiten** | `git`, `gh`, `jq` |

---

## Architektur

```
┌─────────────────────────────────────────────┐
│           github-automation                  │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────────┐    ┌──────────────┐      │
│  │ Git Layer    │    │ GitHub Layer  │      │
│  │              │    │               │      │
│  │ • status     │    │ • repo view   │      │
│  │ • add        │    │ • pr list     │      │
│  │ • commit     │    │ • pr create   │      │
│  │ • push       │    │ • issue list  │      │
│  │ • diff       │    │ • issue create│      │
│  │              │    │ • run list    │      │
│  └──────────────┘    └──────────────┘      │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │ Scripts Layer                         │  │
│  │                                       │  │
│  │ • git-status.sh    → JSON output     │  │
│  │ • git-commit.sh    → Commit + sign   │  │
│  │ • git-push.sh      → Push + verify   │  │
│  │ • gh-issue-create.sh → API wrapper     │  │
│  │                                       │  │
│  └──────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

---

## Tools

### github.git.status

**Script:** `scripts/git-status.sh`

**Output:**
```json
{
  "clean": true,
  "branch": "main",
  "ahead": 0,
  "behind": 0,
  "modified": [],
  "staged": [],
  "untracked": [],
  "last_commit": {
    "hash": "abc123def456...",
    "short": "abc123",
    "time": "2026-04-10 02:30:00",
    "message": "backup: automated"
  },
  "remote": "https://github.com/steges/homelab.git"
}
```

**Usage:**
```bash
/home/steges/agent/skills/github-automation/scripts/git-status.sh
```

---

### github.git.commit

**Script:** `scripts/git-commit.sh`

**Parameter:**
| Parameter | Beschreibung | Default |
|-----------|--------------|---------|
| `-m, --message` | Commit-Message | required |
| `--files` | Spezifische Files | `-A` (alle) |
| `--signoff` | Signed-off-by hinzufügen | `false` |

**Usage:**
```bash
# Einfach
/home/steges/agent/skills/github-automation/scripts/git-commit.sh "feat: neue Funktion"

# Mit Flags
/home/steges/agent/skills/github-automation/scripts/git-commit.sh \
    -m "fix: bug behoben" \
    --files "docs/*.md" \
    --signoff
```

**Output:**
```json
{
  "success": true,
  "commit_hash": "abc123def456...",
  "short_hash": "abc123",
  "files_changed": 5,
  "message": "feat: neue Funktion"
}
```

---

### github.git.push

**Script:** `scripts/git-push.sh`

**Parameter:**
| Parameter | Beschreibung | Default |
|-----------|--------------|---------|
| `--remote` | Remote-Name | `origin` |
| `--branch` | Branch-Name | current |
| `--force` | Force push | `false` |

**Usage:**
```bash
/home/steges/agent/skills/github-automation/scripts/git-push.sh
```

**Output:**
```json
{
  "success": true,
  "remote": "origin",
  "branch": "main",
  "remote_url": "https://github.com/steges/homelab.git",
  "forced": false
}
```

---

### github.issue.create

**Script:** `scripts/gh-issue-create.sh`

**Parameter:**
| Parameter | Beschreibung | Required |
|-----------|--------------|----------|
| `--title` | Issue-Titel | ✅ |
| `--body` | Issue-Body | ❌ |
| `--labels` | Komma-separierte Labels | ❌ |

**Usage:**
```bash
/home/steges/agent/skills/github-automation/scripts/gh-issue-create.sh \
    --title "Backup failed" \
    --body "Logs attached..." \
    --labels "bug,urgent"
```

**Output:**
```json
{
  "success": true,
  "issue_number": 42,
  "url": "https://github.com/steges/homelab/issues/42"
}
```

---

## Installation

### Voraussetzungen

```bash
# Git
git --version  # >= 2.30

# GitHub CLI
gh --version   # >= 2.40

# jq
jq --version   # >= 1.6
```

### Schritt 1: gh CLI installieren

```bash
# Debian/Ubuntu/Raspberry Pi OS
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg

sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

sudo apt update
sudo apt install gh -y
```

### Schritt 2: Authentifizierung

```bash
# Interaktiv
gh auth login

# Oder mit Token
gh auth login --with-token < token.txt
```

### Schritt 3: Skill-Setup

```bash
# Berechtigungen
chmod +x /home/steges/agent/skills/github-automation/scripts/*.sh

# Test
/home/steges/agent/skills/github-automation/scripts/git-status.sh
```

---

## Integration

### Nutzer dieses Skills

| Skill | Nutzt Script | Zweck |
|-------|--------------|-------|
| `backup-automation` | `git-status.sh` | Git-Status Check |
| `backup-automation` | `git-commit.sh` | Backup-Commit |
| `backup-automation` | `git-push.sh` | Push Backup |
| `heartbeat` | `git-status.sh` | Repo Health |

### Code-Beispiel (Integration)

```bash
#!/bin/bash
# Beispiel: backup-automation nutzt github-automation

readonly GITHUB_SKILL="/home/steges/agent/skills/github-automation/scripts"

# 1. Status prüfen
status=$("$GITHUB_SKILL/git-status.sh")
if echo "$status" | grep -q '"clean": true'; then
    echo "Nothing to commit"
    exit 0
fi

# 2. Commit
"$GITHUB_SKILL/git-commit.sh" -m "backup: automated"

# 3. Push
"$GITHUB_SKILL/git-push.sh"
```

---

## Konfiguration

### Environment

| Variable | Zweck | Default |
|----------|-------|---------|
| `REPO_DIR` | Repository-Pfad | `/home/steges` |
| `GITHUB_TOKEN` | Token (optional) | aus `~/.config/gh/` |

### Git Config

```bash
git config --global user.name "steges"
git config --global user.email "your@email.com"
git config --global init.defaultBranch main
```

---

## Fehlerbehandlung

### Exit Codes

| Code | Bedeutung |
|------|-----------|
| 0 | Erfolg |
| 1 | Validierungsfehler |
| 2 | Netzwerk/API-Fehler |
| 3 | Authentifizierungsfehler |

### Häufige Fehler

**"gh: command not found"**
```bash
sudo apt install gh
```

**"Could not resolve host: github.com"**
```bash
# DNS check
nslookup github.com
# Falls Pi-hole blockt, temporär 1.1.1.1
```

**"authentication required"**
```bash
gh auth refresh
```

---

## Sicherheit

### Token-Speicher

```
~/.config/gh/hosts.yml
```

**Permissions:**
```bash
chmod 600 ~/.config/gh/hosts.yml
```

**Nicht im Git:**
```bash
echo ".config/gh/" >> ~/.gitignore
```

### Token-Scopes

Benötigt:
- `repo` – Repository-Zugriff
- `workflow` – GitHub Actions

Nicht benötigt:
- `admin` – Nicht nötig
- `delete_repo` – Nicht nötig

---

## Monitoring

### Health-Check

```bash
#!/bin/bash
# github-health-check.sh

if ! /home/steges/agent/skills/github-automation/scripts/git-status.sh >/dev/null 2>&1; then
    echo "❌ GitHub automation failed"
    exit 1
fi

echo "✅ GitHub automation healthy"
```

### Prometheus Metrics (optional)

```bash
# Pushgateway für GitHub-Status
echo "github_commits_ahead $(git rev-list --count HEAD...@{upstream})" | \
    curl --data-binary @- http://pushgateway:9091/metrics/job/github
```

---

## Vergleich: Original vs. Diese Version

| Aspekt | Original (steipete/github) | Diese Version |
|--------|---------------------------|---------------|
| **Basis** | ClawHub Skill | Skill-Forge Template |
| **Sprache** | Python | Bash |
| **Abhängigkeiten** | gh CLI, Python | gh CLI, Bash |
| **Output** | Text | JSON |
| **Integration** | OpenClag Gateway | Direkte Script-Aufrufe |
| **Pi-Optimierung** | Generisch | Pi 5 optimiert |

---

## Referenzen

- Original: https://clawhub.ai/steipete/github
- GitHub CLI Manual: https://cli.github.com/manual/
- Nutzer: `docs/infrastructure/backup-automation-skill.md`
- Setup: `docs/setup/github-automation-setup.md`
