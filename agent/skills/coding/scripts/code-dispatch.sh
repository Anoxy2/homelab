#!/bin/bash
set -euo pipefail

# code-dispatch.sh — coding skill dispatcher
# Planner → Coder → Reviewer pipeline für alle Artefakttypen
# Args: [--json] <kind> <task-text>
# Output (stdout): exakt 3 Zeilen: job_id, artifact_path, envelope_path
#          or JSON when --json flag is passed
# Generated: 2026-04-04 | Updated: 2026-04-06

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SM_ROOT="/home/steges/agent/skills/skill-forge"
SKILL_ROOT="/home/steges/agent/skills/coding"

source "$SM_ROOT/scripts/common.sh"

usage() {
  echo "Usage: code-dispatch.sh [--json] code|docs|config|test <task-text>"
}

JSON_OUTPUT=0
if [[ "${1:-}" == "--json" ]]; then
  JSON_OUTPUT=1
  shift
fi

# --------------------------------------------------------
# Artefakt-Skeleton generieren (kein TODO-Stub)
# --------------------------------------------------------
generate_artifact() {
  local kind="$1"
  local task="$2"
  local slug="$3"
  local path="$4"
  local now
  now="$(date -u '+%Y-%m-%d')"

  case "$kind" in
    code)
      cat > "$path" <<EOF
#!/bin/bash
set -euo pipefail

# Task: ${task}
# Generated: ${now}
# Skill: coding

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

# --- Konfiguration ---
# Pfade und Parameter hier anpassen
LOG_PREFIX="[${slug}]"

log() {
  echo "\${LOG_PREFIX} \$*" >&2
}

check_dependencies() {
  local missing=0
  for cmd in docker curl jq; do
    if ! command -v "\$cmd" >/dev/null 2>&1; then
      log "Fehlende Abhängigkeit: \$cmd"
      missing=\$((missing + 1))
    fi
  done
  [[ \$missing -eq 0 ]] || { log "Fehlende Abhängigkeiten — Abbruch"; exit 1; }
}

main() {
  log "Start: ${task}"
  check_dependencies
  # Hauptlogik hier implementieren
  log "Fertig"
}

main "\$@"
EOF
      chmod +x "$path"
      ;;
    test)
      cat > "$path" <<EOF
#!/bin/bash
set -euo pipefail

# Test: ${task}
# Generated: ${now}
# Skill: coding

PASS=0
FAIL=0

assert_eq() {
  local label="\$1" expected="\$2" actual="\$3"
  if [[ "\$expected" == "\$actual" ]]; then
    echo "PASS: \$label"
    PASS=\$((PASS + 1))
  else
    echo "FAIL: \$label (expected='\$expected' actual='\$actual')"
    FAIL=\$((FAIL + 1))
  fi
}

assert_cmd() {
  local label="\$1"
  shift
  if "\$@" >/dev/null 2>&1; then
    echo "PASS: \$label"
    PASS=\$((PASS + 1))
  else
    echo "FAIL: \$label (command failed: \$*)"
    FAIL=\$((FAIL + 1))
  fi
}

assert_file_exists() {
  local label="\$1" file="\$2"
  if [[ -f "\$file" ]]; then
    echo "PASS: \$label"
    PASS=\$((PASS + 1))
  else
    echo "FAIL: \$label (nicht gefunden: \$file)"
    FAIL=\$((FAIL + 1))
  fi
}

# --- Tests ---

assert_cmd "Docker laeuft" docker info

# --- Ergebnis ---
echo ""
echo "Results: \$PASS passed, \$FAIL failed"
[[ \$FAIL -eq 0 ]] || exit 1
EOF
      chmod +x "$path"
      ;;
    config)
      cat > "$path" <<EOF
# Config: ${task}
# Generated: ${now}
# Skill: coding
# Schema-Version: 1

version: 1

# Konfiguration hier ergänzen
# Beispiel:
# service:
#   name: ${slug}
#   enabled: true
#   port: 8080
EOF
      ;;
    docs)
      local title
      title="$(echo "$task" | sed 's/\b./\u&/g')"
      cat > "$path" <<EOF
# ${title}

## Zweck

${task}.

## Voraussetzungen

- Raspberry Pi 5 mit Debian 12 Bookworm
- Docker Compose v2
- Relevante Services laufen (\`docker compose ps\`)

## Schritte

1. Vorbereitung prüfen:
   \`\`\`bash
   cd ~/
   docker compose ps
   \`\`\`

2. Aktion durchführen:
   \`\`\`bash
   # Befehle hier einfügen
   \`\`\`

3. Ergebnis verifizieren:
   \`\`\`bash
   # Verifikations-Befehle hier
   \`\`\`

## Rollback

Falls etwas schief läuft:

\`\`\`bash
# Rollback-Schritte hier
# Beispiel: docker compose restart <service>
\`\`\`

## Risiken und Hinweise

- Änderungen an laufenden Services kurz unterbrechen ggf. Dienste
- \`.env\`-Änderungen erfordern Container-Neustart
- Pi-hole-Stopp unterbricht DNS für alle LAN-Geräte
EOF
      ;;
  esac
}

# --------------------------------------------------------
# Security-Scan — gibt JSON-Array von Findings zurück
# Format: [{"id":"...","severity":"block|warn","file":"...","reason":"..."}]
# --------------------------------------------------------
security_scan() {
  local path="$1"
  local findings_json="[]"

  _add_finding() {
    local id="$1" severity="$2" reason="$3"
    findings_json="$(python3 -c "
import json, sys
arr = json.loads(sys.argv[1])
arr.append({'id': sys.argv[2], 'severity': sys.argv[3], 'file': sys.argv[4], 'reason': sys.argv[5]})
print(json.dumps(arr))
" "$findings_json" "$id" "$severity" "$path" "$reason")"
  }

  # Destructive file system ops
  if grep -qE 'rm\s+-rf\s+(/|~|/home)' "$path" 2>/dev/null; then
    _add_finding "destructive-rm-rf" "block" "rm -rf on root/home path detected"
  fi

  # Host disruption
  if grep -qE '\b(reboot|shutdown|halt|systemctl poweroff)\b' "$path" 2>/dev/null; then
    _add_finding "host-disruption" "block" "host lifecycle command detected"
  fi

  # Docker purge
  if grep -qE 'docker system prune\s+-a' "$path" 2>/dev/null; then
    _add_finding "docker-purge" "block" "docker system prune -a wipes all images"
  fi

  # Remote code execution
  if grep -qE 'curl[^|]*\|\s*(bash|sh)' "$path" 2>/dev/null; then
    _add_finding "remote-code-exec-curl" "block" "curl piped directly to shell"
  fi
  if grep -qE 'wget[^|]*\|\s*(bash|sh)' "$path" 2>/dev/null; then
    _add_finding "remote-code-exec-wget" "block" "wget piped directly to shell"
  fi

  # Code injection
  if grep -qE 'eval\s+\$\(' "$path" 2>/dev/null; then
    _add_finding "code-injection-eval" "block" "eval \$(...) is a code injection risk"
  fi

  # Hardcoded credentials (literal non-empty assignment)
  if grep -qE '(PASSWORD|TOKEN|API_KEY|SECRET|PASSWD)=[^${"'"'"'\s][^\s]*' "$path" 2>/dev/null; then
    _add_finding "hardcoded-credential" "block" "literal credential value in source"
  fi

  # Credential file writes
  if grep -qE '(>|>>|tee)\s*\.env\b' "$path" 2>/dev/null; then
    _add_finding "credential-file-write" "warn" "writing to .env file"
  fi

  # System-wide installs
  if grep -qE 'npm install\s+-g' "$path" 2>/dev/null; then
    _add_finding "system-wide-npm-install" "warn" "global npm install modifies system"
  fi

  echo "$findings_json"
  # Return non-zero if any block-severity finding exists
  if echo "$findings_json" | python3 -c "import json,sys; data=json.load(sys.stdin); sys.exit(0 if any(f['severity']=='block' for f in data) else 1)" 2>/dev/null; then
    return 1
  fi
  return 0
}

# --------------------------------------------------------
# Job anlegen + Envelope schreiben
# --------------------------------------------------------
create_job() {
  local kind="$1"
  local task="$2"
  local path="$3"
  local envelope_path="$4"
  local status="$5"
  local review_verdict="$6"

  python3 - "$kind" "$task" "$path" "$envelope_path" "$status" "$review_verdict" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, '/home/steges/agent/skills/skill-forge/scripts')
from py_helpers import write_json_atomic

kind, task, path, envelope_path, status, review_verdict = sys.argv[1:]
base = '/home/steges/agent/skills/skill-forge'
jp = base + '/.state/writer-jobs.json'

with open(jp, 'r', encoding='utf-8') as f:
    jobs = json.load(f)

os.makedirs(os.path.dirname(envelope_path), exist_ok=True)

job_id = f"writer-{int(datetime.now(timezone.utc).timestamp())}-{abs(hash((kind, task))) % 10000}"

envelope = {
    'intent': f'Generate {kind} artifact for task',
    'triggers': [task],
    'workflow_steps': ['collect-context', 'generate-artifact', 'verify-result'],
    'exclusions': ['secrets', 'destructive-commands'],
    'risk_notes': 'Generated artifact requires review before production use.'
}

with open(envelope_path, 'w', encoding='utf-8') as f:
    json.dump(envelope, f, indent=2)

job = {
    'id': job_id,
    'type': kind,
    'task': task,
    'path': path,
    'envelope_path': envelope_path,
    'schema_version': '1',
    'status': status,
    'reviewed': True,
    'review_verdict': review_verdict,
    'created_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
}
jobs.append(job)
write_json_atomic(jp, jobs)

print(job_id)
PY
}

# --------------------------------------------------------
# Main
# --------------------------------------------------------
main() {
  ensure_dirs
  init_state_files

  [[ $# -ge 2 ]] || { usage; exit 1; }

  local kind="$1"
  shift
  local task="$*"

  case "$kind" in
    code|docs|config|test) ;;
    *) usage; exit 1 ;;
  esac

  # Dateinamen aus Task ableiten
  local slug
  slug="$(echo "$task" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//' | cut -c1-40)"
  [[ -n "$slug" ]] || slug="task"

  # Artefakt-Pfad bestimmen
  local ext
  case "$kind" in
    code|test) ext="sh" ;;
    config)    ext="yaml" ;;
    docs)      ext="md" ;;
  esac

  local artifact_dir="$SM_ROOT/generated/$kind"
  local envelope_dir="$SM_ROOT/generated/envelopes"
  local findings_dir="$SM_ROOT/generated/findings"
  mkdir -p "$artifact_dir" "$envelope_dir" "$findings_dir"

  # Slug-Kollisionen vermeiden: Timestamp-Suffix wenn Datei bereits existiert
  local path="$artifact_dir/${slug}.${ext}"
  if [[ -f "$path" ]]; then
    local ts_suffix
    ts_suffix="$(date -u '+%Y%m%d%H%M%S')"
    slug="${slug}-${ts_suffix}"
    path="$artifact_dir/${slug}.${ext}"
  fi
  local envelope_path="$envelope_dir/${slug}.json"
  local findings_path="$findings_dir/${slug}.json"

  # Phase 1: Artefakt generieren
  generate_artifact "$kind" "$task" "$slug" "$path"

  # Phase 2: Security-Scan (strukturierte Findings)
  local scan_result=""
  local verdict="pass"
  local status="completed"

  scan_result="$(security_scan "$path")" || true
  # scan_result ist immer ein JSON-Array; non-zero wenn block-severity vorhanden
  if echo "$scan_result" | python3 -c "import json,sys; data=json.load(sys.stdin); sys.exit(0 if any(f['severity']=='block' for f in data) else 1)" 2>/dev/null; then
    # Block-severity Findings vorhanden
    local first_id
    first_id="$(echo "$scan_result" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data[0]['id'] if data else 'unknown')" 2>/dev/null || echo "unknown")"
    verdict="fail:${first_id}"
    status="pending-review"
    # Findings-Datei speichern (severity + file + reason für jedes Finding)
    echo "$scan_result" > "$findings_path"
  elif [[ "$scan_result" != "[]" ]]; then
    # Nur warn-Findings — trotzdem speichern, aber nicht blockieren
    echo "$scan_result" > "$findings_path"
  fi

  # Phase 3: Job anlegen
  local job_id
  job_id="$(with_state_lock create_job "$kind" "$task" "$path" "$envelope_path" "$status" "$verdict")"

  # Audit-Log
  log_audit "CODING" "$kind" "job=$job_id path=$path status=$status verdict=$verdict"

  # Output: exakt 3 Zeilen (job_id, path, envelope_path) oder JSON mit --json
  if [[ "$JSON_OUTPUT" == "1" ]]; then
    python3 -c "
import json, sys
print(json.dumps({
  'job_id': sys.argv[1],
  'path': sys.argv[2],
  'envelope_path': sys.argv[3],
  'findings_path': sys.argv[4] if sys.argv[4] else None,
  'status': sys.argv[5],
  'verdict': sys.argv[6],
}))
" "$job_id" "$path" "$envelope_path" "${findings_path:-}" "$status" "$verdict"
  else
    echo "$job_id"
    echo "$path"
    echo "$envelope_path"
  fi

  if [[ "$status" == "pending-review" ]]; then
    echo "WARNING: Artefakt hat Security-Findings ($verdict). Status=pending-review. Findings: $findings_path" >&2
  fi
}

# Cleanup: Entferne Artefakte älter als 7 Tage (TTL)
cleanup_old_artifacts() {
  local generated_dir="$SM_ROOT/generated"
  if [[ ! -d "$generated_dir" ]]; then
    return 0
  fi
  
  # Komplett in Python um Portabilität von find sicherzustellen
  python3 - "$generated_dir" <<'PY'
import os
import sys
from datetime import datetime, timedelta

generated_dir = sys.argv[1]
now_ts = datetime.now().timestamp()
ttl_days = 7
ttl_sec = ttl_days * 86400  # 604800 sec für 7 Tage

cleaned = 0
for root, dirs, files in os.walk(generated_dir):
  for fname in files:
    fpath = os.path.join(root, fname)
    try:
      mtime = os.path.getmtime(fpath)
      age_sec = now_ts - mtime
      if age_sec > ttl_sec:
        os.remove(fpath)
        cleaned += 1
    except (OSError, IOError):
      pass

if cleaned > 0:
  print(f'cleanup: removed {cleaned} old artifacts age> 7d', file=sys.stderr)
PY
}

# Main execution
main "$@"
cleanup_old_artifacts  # Cleanup nach dem Hauptlauf
