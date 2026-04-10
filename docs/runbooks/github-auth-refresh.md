# GitHub Auth Refresh Runbook

> GitHub Token erneuern wenn abgelaufen oder invalid  
> Token-Rotation und Troubleshooting

---

## Überblick

| Problem | Symptom | Lösung |
|---------|---------|--------|
| Token abgelaufen | "authentication required" | Token refreshen |
| Token widerrufen | "401 Unauthorized" | Neu generieren |
| Scope fehlt | "Resource not accessible" | Scopes erweitern |
| 2FA aktiviert | "Requires authentication" | Token mit 2FA |

---

## Schnelle Lösung

### Schritt 1: Status prüfen

```bash
gh auth status
```

**Gut:**
```
github.com
  ✓ Logged in to github.com as steges
  ✓ Git operations for github.com configured to use https protocol.
```

**Schlecht:**
```
github.com
  X Not logged into any hosts
```

---

## Szenario 1: Token refreshen (einfach)

### Mit gh CLI

```bash
# 1. Token erneuern (öffnet Browser)
gh auth refresh

# 2. Oder non-interactive (wenn Token in clipboard)
pbpaste | gh auth login --with-token  # macOS
xclip -o | gh auth login --with-token  # Linux
```

### Verify

```bash
gh auth status
gh repo view steges/homelab
```

---

## Szenario 2: Neues Token generieren (manuell)

### Schritt 1: GitHub Web Interface

```
1. https://github.com/settings/tokens öffnen
2. "Generate new token" → "Classic"
3. Name: "homelab-pi-backup"
4. Expiration: 90 days (empfohlen)
5. Scopes auswählen:
   ✅ repo (Full control)
   ✅ workflow (GitHub Actions)
   ✅ read:org (wenn Org repos)
6. "Generate token"
7. TOKEN KOPIEREN (wird nur einmal gezeigt!)
```

### Schritt 2: Auf Pi eintragen

```bash
# Token speichern
echo 'YOUR_TOKEN_HERE' > /tmp/gh_token.txt

# Login
gh auth login --with-token < /tmp/gh_token.txt

# Cleanup
shred -u /tmp/gh_token.txt
```

### Schritt 3: Verify

```bash
# Auth prüfen
gh auth status

# Test: Repo clonen
cd /tmp
git clone https://github.com/steges/homelab.git test-clone
rm -rf test-clone
```

---

## Szenario 3: Token mit 2FA (Two-Factor Auth)

### Problem

Wenn GitHub-Account 2FA hat, braucht das Token die richtigen Scopes.

### Lösung

```bash
# 1. Personal Access Token mit 2FA-Support
# → In GitHub Settings → Tokens
# → Scopes: repo, workflow

# 2. HTTPS mit Token statt SSH nutzen (einfacher auf Pi)
git remote set-url origin https://github.com/steges/homelab.git

# 3. Token in URL (nicht empfohlen, aber funktioniert)
# → Besser: gh CLI nutzt Token aus ~/.config/gh/hosts.yml
```

---

## Szenario 4: Token-Rotation (Best Practice)

### Automatische Rotation

```bash
# Alle 90 Tage (via cron)
# 0 0 1 */3 * /home/steges/scripts/rotate-github-token.sh

# Script:
cat > /home/steges/scripts/rotate-github-token.sh << 'EOF'
#!/bin/bash
# Token-Rotation Erinnerung
/usr/local/bin/claw-send.sh "GitHub Token rotation due in 7 days"
EOF
```

### Manuelle Rotation

```bash
# 1. Altes Token prüfen
cat ~/.config/gh/hosts.yml | grep oauth_token

# 2. Neues Token generieren (siehe Szenario 2)

# 3. Altes widerrufen (GitHub Settings)

# 4. Neues eintragen
gh auth login --with-token < new_token.txt
```

---

## Troubleshooting

### Problem: "401 Bad credentials"

```bash
# Token invalid oder widerrufen

# Lösung:
# 1. GitHub Settings → Tokens → prüfen ob vorhanden
# 2. Falls nicht: Neues generieren
# 3. Falls ja: Re-generate
```

### Problem: "403 API rate limit"

```bash
# Rate Limit erreicht

# Lösung:
# 1. Authentifizierte Requests haben höheres Limit
#    gh auth status sollte zeigen: ✓

# 2. Oder warten:
sleep 3600  # 1 Stunde

# 3. Check limit:
gh api rate_limit
```

### Problem: "Repository not found"

```bash
# Zwei Möglichkeiten:

# A) Repo existiert nicht
gh repo view steges/homelab
# → Sollte zeigen: Repo info

# B) Token hat keinen repo Scope
# → Token neu generieren mit "repo" scope
```

### Problem: "Could not resolve host: github.com"

```bash
# Network-Problem, kein Auth-Problem!

# Lösung:
ping github.com
# Falls nicht: DNS check
nslookup github.com
```

---

## Token-Sicherheit

### Wo wird das Token gespeichert?

```bash
# gh CLI speichert hier:
cat ~/.config/gh/hosts.yml

# Format:
github.com:
    user: steges
    oauth_token: ghp_xxxxxxxx
    git_protocol: https
```

**Permissions:**
```bash
chmod 600 ~/.config/gh/hosts.yml
```

### Token im Backup

```bash
# NICHT im Git-Backup!
grep -r "oauth_token" /home/steges/

# Sollte nur in ~/.config/gh/hosts.yml sein
# → Diese Datei ist in .gitignore

# USB-Backup hat die Datei (lokal sicher)
ls /mnt/usb-backup/backups/*/home/steges/.config/gh/
```

---

## Verify nach Fix

### Komplettes Check

```bash
# 1. gh CLI Status
gh auth status

# 2. API-Zugriff
gh api user | jq '.login'

# 3. Repo-Zugriff
gh repo view steges/homelab --json name,description

# 4. Git Operations
cd /home/steges
git fetch origin

# 5. Backup-Skill testen
/home/steges/agent/skills/github-automation/scripts/git-status.sh
```

---

## Automation

### Health-Check

```bash
# Daily check (in scripts/health-check.sh)
if ! gh auth status >/dev/null 2>&1; then
    /home/steges/scripts/claw-send.sh "🚨 GitHub auth failed"
fi
```

### Auto-Refresh (experimental)

```bash
# Token läuft ab in 7 Tagen?
gh auth status 2>&1 | grep -q "expires" && \
    gh auth refresh
```

---

## Verweise

- `docs/setup/github-automation-setup.md` – Erst-Setup
- `docs/infrastructure/backup-automation-skill.md` – Backup-Skill
- https://github.com/settings/tokens – Token-Verwaltung
