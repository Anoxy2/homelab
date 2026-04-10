---
name: backup-automation
description: Automated backup management using github-automation skill for GitHub + custom scripts for USB. Dual backup strategy with OpenClaw notifications.
version: 1.0.0
author: steges (via skill-forge)
dependencies: [github-automation, rsync, mount]
generated_by: skill-forge
based_on:
  - skill-forge/templates/bash-script
  - agent/skills/github-automation (for GitHub operations)
---

# backup-automation

## Purpose

Zero-touch backup system combining **github-automation** (GitHub operations) and **USB-Scripts** (local backup). Fully automated with systemd timers and OpenClaw integration.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    backup-automation                      │
├─────────────────────────────────────────────────────────┤
│  GitHub Layer            │  USB Layer                  │
│  (uses github-automation) │  (custom scripts)          │
│  ├── git-status.sh       │  ├── mount check            │
│  ├── git-commit.sh       │  ├── rsync databases        │
│  └── git-push.sh         │  ├── rsync secrets          │
│                          │  └── cleanup 14d retention │
├─────────────────────────────────────────────────────────┤
│  Orchestration: backup-full.sh                            │
│  Status: backup-status.sh                                 │
│  Verify: backup-verify.sh                                 │
│  Restore: backup-restore.sh                               │
└─────────────────────────────────────────────────────────┘
```

## Dependency: github-automation

This skill **requires** the `github-automation` skill for all GitHub operations.

| Operation | Uses Script |
|-----------|-------------|
| Git status | `github-automation/scripts/git-status.sh` |
| Git commit | `github-automation/scripts/git-commit.sh` |
| Git push | `github-automation/scripts/git-push.sh` |
| Issues/PRs | `github-automation/scripts/gh-*.sh` |

**No duplicate git logic** - all GitHub operations delegated to github-automation.

## Tools

### backup.github (delegated)

All GitHub operations call `github-automation` scripts:

- `github.git.status` → `../github-automation/scripts/git-status.sh`
- `github.git.commit` → `../github-automation/scripts/git-commit.sh`
- `github.git.push` → `../github-automation/scripts/git-push.sh`

### backup.usb.status

Description: Check USB mount and available space

Parameters: none

Returns:
- mounted: boolean
- device: string
- available_gb: number
- used_percent: number

### backup.usb.run

Description: Execute USB backup (custom scripts)

Parameters:
- verify: boolean (default: true)
- cleanup: boolean (default: true)

Returns:
- success: boolean
- backup_path: string
- size_mb: number

### backup.full

Description: Run complete backup (GitHub via skill + USB via scripts)

Parameters:
- github_message: string (default: "backup: daily automated")

Returns:
- github: object (from github-automation)
- usb: object (from usb scripts)
- overall_success: boolean

### backup.verify

Description: Verify USB backup integrity

Parameters:
- date: string (optional, YYYYMMDD)

Returns:
- status: "PASSED" | "FAILED"
- checks: object

## USB-Only Scripts

These are custom (not delegated):

| Script | Purpose | GitHub Skill |
|--------|---------|--------------|
| `backup-usb.sh` | USB rsync | ❌ Custom |
| `backup-verify.sh` | Integrity check | ❌ Custom |
| `backup-status.sh` | Status display | ❌ Custom |
| `backup-restore.sh` | Restore from USB | ❌ Custom |
| `backup-full.sh` | Orchestrator | ✅ Uses github-automation |

## Data Flow

### Daily Backup (02:00)

```
1. systemd → backup-full.sh
2. ├── GitHub (delegated to github-automation)
   │   ├── git-status.sh → check changes
   │   ├── git-commit.sh → commit
   │   └── git-push.sh → push
   │
   └── USB (local scripts)
       ├── backup-usb.sh
       │   ├── mount check
       │   ├── rsync openclaw-memory/
       │   ├── rsync pihole/
       │   └── cleanup 14d
       └── verify checksums
3. Save state → .state/last-backup.json
4. Notify OpenClaw
```

## Scripts

### GitHub Operations (delegated)

Calls `../github-automation/scripts/`:
- `git-status.sh` - Repository status
- `git-commit.sh -m "msg"` - Create commit
- `git-push.sh` - Push to origin

### USB Operations (custom)

| Script | Function |
|--------|----------|
| `backup-usb.sh` | Rsync databases, secrets to USB |
| `backup-verify.sh` | Verify SQLite integrity, checksums |
| `backup-restore.sh` | Restore from USB backup |
| `backup-status.sh` | Show GitHub + USB status |

## State

```
.state/
├── last-backup.json       # Results from both sources
└── last-verify.json       # USB verification results
```

## Installation

```bash
# 1. Ensure github-automation is installed first
ls /home/steges/agent/skills/github-automation/

# 2. Install backup-automation
sudo /home/steges/agent/skills/backup-automation/scripts/install.sh
```

## Usage

```bash
# Full backup (uses github-automation + USB)
/home/steges/agent/skills/backup-automation/scripts/backup-full.sh

# USB only
/home/steges/agent/skills/backup-automation/scripts/backup-usb.sh

# GitHub only (via github-automation)
/home/steges/agent/skills/github-automation/scripts/git-commit.sh "msg"
/home/steges/agent/skills/github-automation/scripts/git-push.sh

# Status
/home/steges/agent/skills/backup-automation/scripts/backup-status.sh
```

## Integration

### With github-automation
```bash
# backup-full.sh calls:
../github-automation/scripts/git-status.sh
../github-automation/scripts/git-commit.sh "$message"
../github-automation/scripts/git-push.sh
```

### With OpenClaw
```bash
# Notification via claw-send.sh or docker exec
/home/steges/scripts/claw-send.sh "Backup completed"
```

## References

- `github-automation/SKILL.md` - GitHub operations (dependency)
- `docs/infrastructure/backup-strategy.md` - Strategy documentation
- `docs/infrastructure/backup-automation-skill.md` - This skill's docs
