#!/bin/bash
# consolidate.sh - Skill-Liste bereinigen nach Retention-Policy

consolidate_cmd() {
  local sub="${1:-run}"
  shift || true

  case "$sub" in
    run)
      consolidate_run "$@"
      ;;
    report)
      consolidate_report "$@"
      ;;
    *)
      echo "Usage: skill-forge consolidate run|report [--dry-run] [--aggressive]" >&2
      exit 2
      ;;
  esac
}

consolidate_report() {
  # Nur Report, kein Ändern
  python3 - <<'PY'
import json
from datetime import datetime, timezone, timedelta
from pathlib import Path

state_dir = Path("/home/steges/agent/skills/skill-forge/.state")
known_skills_file = state_dir / "known-skills.json"

if not known_skills_file.exists():
  print("ERROR: known-skills.json not found")
  exit(1)

with open(known_skills_file, 'r', encoding='utf-8') as f:
  skills = json.load(f)

now = datetime.now(timezone.utc)
to_delete = []
to_review = []
to_keep = []

for slug, entry in skills.items():
  status = entry.get('status', 'unknown')
  source = entry.get('source', '')
  
  # Lösch-Kandidaten: immediate
  if status in ['pending-blacklist']:
    to_delete.append((slug, status, 'pending-blacklist'))
    continue
  
  if slug.startswith('test-'):
    to_delete.append((slug, status, 'test-skill'))
    continue
  
  if 'demo' in slug.lower() or slug.startswith('deep-scan'):
    to_delete.append((slug, status, 'demo/temp skill'))
    continue
  
  # Alte Canaries: review
  if status == 'canary':
    discovered_at = entry.get('discovered_at', '')
    if discovered_at:
      try:
        disc_time = datetime.fromisoformat(discovered_at.replace('Z', '+00:00'))
        age_days = (now - disc_time).days
        if age_days > 14:
          to_review.append((slug, status, f'canary {age_days}d old'))
          continue
      except:
        pass
  
  to_keep.append((slug, status))

print("═══════════════════════════════════════════════════════════")
print(f"CONSOLIDATION REPORT — {now.isoformat()}")
print("═══════════════════════════════════════════════════════════")
print("")
print(f"TO DELETE (immediate): {len(to_delete)}")
for slug, status, reason in to_delete:
  print(f"  {slug:40} {status:20} ({reason})")

print("")
print(f"TO REVIEW (old canaries): {len(to_review)}")
for slug, status, reason in to_review:
  print(f"  {slug:40} {status:20} ({reason})")

print("")
print(f"KEEP (active/vetted/local): {len(to_keep)}")

print("")
print(f"TOTAL: {len(skills)} → {len(to_keep)} (remove {len(to_delete) + len(to_review)})")
PY
}

consolidate_run() {
  local dry_run=0
  local aggressive=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=1
        shift
        ;;
      --aggressive)
        aggressive=1
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  python3 - "$dry_run" "$aggressive" <<'PY'
import json
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

dry_run = int(sys.argv[1])
aggressive = int(sys.argv[2])

state_dir = Path("/home/steges/agent/skills/skill-forge/.state")
known_skills_file = state_dir / "known-skills.json"

if not known_skills_file.exists():
  print("ERROR: known-skills.json not found")
  sys.exit(1)

with open(known_skills_file, 'r', encoding='utf-8') as f:
  skills = json.load(f)

now = datetime.now(timezone.utc)
to_delete = []

for slug, entry in skills.items():
  status = entry.get('status', 'unknown')
  source = entry.get('source', '')
  
  # Kategorien zum Löschen
  
  # 1. Pending-Blacklist: sofort
  if status == 'pending-blacklist':
    to_delete.append(slug)
    continue
  
  # 2. Test-Skills: sofort
  if slug.startswith('test-'):
    to_delete.append(slug)
    continue
  
  # 3. Demo/Experimental: sofort
  if 'demo' in slug.lower() or slug.startswith('deep-scan') or 'resilience-extreme' in slug:
    to_delete.append(slug)
    continue
  
  # 4. Alte Canaries (>14 Tage): aggressive mode
  if aggressive and status == 'canary':
    discovered_at = entry.get('discovered_at', '')
    if discovered_at:
      try:
        disc_time = datetime.fromisoformat(discovered_at.replace('Z', '+00:00'))
        age_days = (now - disc_time).days
        if age_days > 14:
          to_delete.append(slug)
          continue
      except:
        pass
  
  # 5. Pending-Review längere Zeit (aggressive): nach 21 Tagen
  if aggressive and status == 'pending-review':
    discovered_at = entry.get('discovered_at', '')
    if discovered_at:
      try:
        disc_time = datetime.fromisoformat(discovered_at.replace('Z', '+00:00'))
        age_days = (now - disc_time).days
        if age_days > 21:
          to_delete.append(slug)
          continue
      except:
        pass

# Jetzt löschen
for slug in to_delete:
  del skills[slug]

# Speichern
if dry_run:
  print(f"[DRY-RUN] Würde {len(to_delete)} Skills löschen:")
  for s in to_delete:
    print(f"  - {s}")
else:
  with open(known_skills_file, 'w', encoding='utf-8') as f:
    json.dump(skills, f, indent=2, ensure_ascii=True)
  print(f"✅ Consolidated: {len(to_delete)} skills deleted, {len(skills)} remaining")

sys.exit(0)
PY
}
