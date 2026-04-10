# GitHub-Automation Setup Guide

> Einrichtung des github-automation Skills  
> GitHub CLI (gh) Installation und Authentifizierung

---

## Überblick

Der `github-automation` Skill basiert auf dem [steipete/github](https://clawhub.ai/steipete/github) Skill von ClawHub und nutzt die offizielle GitHub CLI (`gh`).

**Voraussetzungen:**
- Git installiert (`git >= 2.30`)
- GitHub Account
- SSH Key oder HTTPS mit Token

---

## Installation

### Schritt 1: gh CLI installieren

```bash
# Debian/Ubuntu (Raspberry Pi OS)
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg

sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

sudo apt update
sudo apt install gh -y
```

**Verifizieren:**
```bash
gh --version
# Output: gh version 2.40.0 (2024-01-01)
```

---

### Schritt 2: Authentifizierung

**Option A: Interaktiv (empfohlen)**

```bash
gh auth login
```

Wähle:
- **GitHub.com**
- **HTTPS** (einfacher auf Pi)
- Login via Browser oder Token

**Option B: Mit Token (Headless)**

```bash
# Token erstellen: https://github.com/settings/tokens
# Scopes needed: repo, workflow, read:org

gh auth login --with-token < token.txt
```

---

### Schritt 3: Verifizierung

```bash
# Auth Status prüfen
gh auth status

# Output:
# github.com
#   ✓ Logged in to github.com as steges (/home/steges/.config/gh/hosts.yml)
#   ✓ Git operations for github.com configured to use https protocol.
```

---

## Repository Setup

### Schritt 4: Repo konfigurieren

```bash
cd /home/steges

# Remote URL prüfen
git remote -v

# Sollte zeigen:
# origin  https://github.com/steges/homelab.git (fetch)
# origin  https://github.com/steges/homelab.git (push)
```

### Schritt 5: Git Config

```bash
# Falls nicht bereits gesetzt
git config --global user.name "steges"
git config --global user.email "your@email.com"

# Default branch
git config --global init.defaultBranch main
```

---

## Skill-Verifizierung

### Test: git-status.sh

```bash
/home/steges/agent/skills/github-automation/scripts/git-status.sh
```

**Erwartete Ausgabe:**
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
    "hash": "abc123...",
    "short": "abc123",
    "time": "2026-04-10 02:30:00",
    "message": "backup: automated"
  },
  "remote": "https://github.com/steges/homelab.git"
}
```

### Test: git-commit.sh

```bash
# Test-Datei erstellen
echo "test" > /tmp/test-file.txt

# Commit
/home/steges/agent/skills/github-automation/scripts/git-commit.sh "test: verify setup"
```

### Test: git-push.sh

```bash
/home/steges/agent/skills/github-automation/scripts/git-push.sh
```

---

## Troubleshooting

### Problem: "gh: command not found"

```bash
# Prüfe PATH
echo $PATH

# Falls gh in /usr/local/bin
export PATH=$PATH:/usr/local/bin

# Oder neu installieren
sudo apt reinstall gh
```

### Problem: "authentication required"

```bash
# Token neu generieren
gh auth refresh

# Oder logout/login
gh auth logout
gh auth login
```

### Problem: "permission denied (publickey)"

```bash
# Für SSH:
ssh-keygen -t ed25519 -C "steges@homelab"
cat ~/.ssh/id_ed25519.pub

# Key zu GitHub hinzufügen: https://github.com/settings/keys
```

### Problem: "could not resolve host"

```bash
# DNS check
cat /etc/resolv.conf

# Falls Pi-hole blockt:
nslookup github.com

# Temporär anderer DNS:
sudo sed -i 's/nameserver.*/nameserver 1.1.1.1/' /etc/resolv.conf
```

---

## Integration mit backup-automation

Der `backup-automation` Skill ruft `github-automation` auf:

```bash
# backup-full.sh ruft:
../github-automation/scripts/git-status.sh
../github-automation/scripts/git-commit.sh "msg"
../github-automation/scripts/git-push.sh
```

**Wichtig:** github-automation muss vor backup-automation funktionieren!

---

## Konfigurations-Dateien

| Datei | Zweck |
|-------|-------|
| `~/.config/gh/hosts.yml` | Auth Token (sensitive!) |
| `~/.config/gh/config.yml` | CLI Einstellungen |
| `~/.gitconfig` | Git global config |

**Backup:**
```bash
# Auth nicht backuppen (Token)!
# Nur config:
cp ~/.gitconfig /home/steges/dotfiles/
```

---

## Sicherheit

### Token-Scopes

Minimal benötigt:
- `repo` – Repository Zugriff
- `workflow` – GitHub Actions

**NICHT** speichern:
- Token in Git
- Token in Logs
- Token in Env (wenn möglich)

### Rotation

```bash
# Token alle 90 Tage rotieren
# GitHub → Settings → Developer settings → Personal access tokens
gh auth refresh
```

---

## Weiterführend

- [GitHub CLI Manual](https://cli.github.com/manual/)
- `docs/infrastructure/backup-automation-skill.md` – Nutzt diesen Skill
- `docs/runbooks/github-auth-refresh.md` – Token erneuern
