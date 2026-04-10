---
name: github-automation
description: GitHub operations via gh CLI and git. Based on steipete/github from ClawHub. Provides status, commit, push, pr, issue operations.
version: 1.0.0
author: steges (via skill-forge)
dependencies: [git, gh]
generated_by: skill-forge
based_on:
  - https://clawhub.ai/steipete/github
---

# github-automation

## Purpose

Complete GitHub workflow automation using the official `gh` CLI and git. Handles repositories, commits, pushes, PRs, issues, and CI/CD runs.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    github-automation                      │
├─────────────────────────────────────────────────────────┤
│  git Layer               │  gh CLI Layer                │
│  ├── status              │  ├── repo view               │
│  ├── add                 │  ├── pr list/create          │
│  ├── commit              │  ├── issue list/create       │
│  ├── push                │  ├── run list/watch          │
│  └── diff                │  ├── api (custom queries)    │
└─────────────────────────────────────────────────────────┘
```

## Tools

### github.git.status

Description: Check git repository status

Parameters: none

Returns:
```json
{
  "clean": true,
  "branch": "main",
  "ahead": 0,
  "behind": 0,
  "modified": [],
  "staged": [],
  "untracked": []
}
```

### github.git.add

Description: Stage files for commit

Parameters:
- files: array (optional) - Specific files, default: all ("-A")
- dry_run: boolean (optional) - Show what would be staged

Returns:
- success: boolean
- staged: array of file paths

### github.git.commit

Description: Create commit with message

Parameters:
- message: string (required) - Commit message
- files: array (optional) - Specific files to commit
- signoff: boolean (optional) - Add Signed-off-by

Returns:
- success: boolean
- commit_hash: string
- files_changed: number

### github.git.push

Description: Push to remote

Parameters:
- remote: string (default: "origin")
- branch: string (optional) - defaults to current branch
- force: boolean (default: false)

Returns:
- success: boolean
- remote_url: string

### github.repo.view

Description: View repository information

Parameters:
- repo: string (optional) - Owner/repo, defaults to current

Returns:
```json
{
  "name": "homelab",
  "description": "Steges' Homelab",
  "visibility": "public",
  "url": "https://github.com/steges/homelab",
  "stars": 0,
  "forks": 0,
  "issues": 0,
  "default_branch": "main"
}
```

### github.pr.list

Description: List pull requests

Parameters:
- state: string (default: "open") - open, closed, merged, all
- limit: number (default: 10)

Returns: array of PR objects

### github.pr.create

Description: Create pull request

Parameters:
- title: string (required)
- body: string (optional)
- base: string (default: "main")
- head: string (required) - Branch to merge
- draft: boolean (default: false)

Returns:
- success: boolean
- pr_number: number
- url: string

### github.issue.list

Description: List issues

Parameters:
- state: string (default: "open")
- label: string (optional)
- limit: number (default: 10)

Returns: array of issue objects

### github.issue.create

Description: Create issue

Parameters:
- title: string (required)
- body: string (optional)
- labels: array (optional)
- assignees: array (optional)

Returns:
- success: boolean
- issue_number: number
- url: string

### github.run.list

Description: List workflow runs

Parameters:
- workflow: string (optional) - Workflow name or ID
- limit: number (default: 10)
- status: string (optional) - in_progress, completed, etc.

Returns: array of run objects

### github.run.view

Description: View specific workflow run

Parameters:
- run_id: string (required)

Returns: run details with logs URL

### github.api

Description: Custom GitHub API query

Parameters:
- endpoint: string (required) - API endpoint path
- method: string (default: "GET") - GET, POST, PUT, DELETE
- data: object (optional) - Request body for POST/PUT

Returns: API response

## Data Paths

| Type | Path | Notes |
|------|------|-------|
| Repository | `/home/steges` | Main homelab repo |
| Config | `~/.config/gh/` | gh CLI config |
| Auth | `~/.config/gh/hosts.yml` | GitHub token |

## Scripts

| Script | Purpose | Caller |
|--------|---------|--------|
| `scripts/git-status.sh` | Detailed git status | github.git.status |
| `scripts/git-commit.sh` | Commit with validation | github.git.commit |
| `scripts/git-push.sh` | Push with checks | github.git.push |
| `scripts/gh-pr-list.sh` | List PRs | github.pr.list |
| `scripts/gh-issue-create.sh` | Create issue | github.issue.create |
| `scripts/gh-run-watch.sh` | Watch CI runs | github.run.list |
| `scripts/repo-info.sh` | Repository metadata | github.repo.view |

## Usage Examples

### Check Status
```bash
/home/steges/agent/skills/github-automation/scripts/git-status.sh
```

### Commit and Push
```bash
/home/steges/agent/skills/github-automation/scripts/git-commit.sh "feat: add new feature"
/home/steges/agent/skills/github-automation/scripts/git-push.sh
```

### Create Issue
```bash
/home/steges/agent/skills/github-automation/scripts/gh-issue-create.sh \
    "Bug: Service down" \
    "Details here..." \
    "bug,urgent"
```

### Watch CI
```bash
/home/steges/agent/skills/github-automation/scripts/gh-run-watch.sh
```

## Integration with Other Skills

### Used by backup-automation
The backup-automation skill calls github-automation for:
- `github.git.status` - Check if changes exist
- `github.git.commit` - Commit with timestamp
- `github.git.push` - Push to origin

### Error Handling
All scripts return:
- Exit 0: Success
- Exit 1: Validation/operation error
- Exit 2: Network/API error
- JSON output to stdout on success

## Dependencies

Required:
- `git` (>= 2.30)
- `gh` CLI (>= 2.40)
- GitHub token configured (`gh auth status`)

Install gh CLI:
```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh -y

# Authenticate
git auth login
```

## References
- https://clawhub.ai/steipete/github
- https://cli.github.com/manual/
