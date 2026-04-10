#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

usage() {
  echo "Usage: dispatcher.sh [--validate-output <schema.json>] [--strict-output] <agent> <script> [args...]"
}

validate_json_output() {
  local schema_file="$1"
  local output_file="$2"
  local strict_mode="$3"
  python3 - "$schema_file" "$output_file" "$strict_mode" <<'PY'
import json, re, sys
schema_path, out_path, strict_mode = sys.argv[1], sys.argv[2], (sys.argv[3] == '1')
with open(schema_path, 'r', encoding='utf-8') as f:
  schema = json.load(f)
with open(out_path, 'r', encoding='utf-8') as f:
  data = json.load(f)

def fail(path, msg):
  raise SystemExit(f'{path}: {msg}')

def type_ok(expected, value):
  if expected == 'object':
    return isinstance(value, dict)
  if expected == 'array':
    return isinstance(value, list)
  if expected == 'string':
    return isinstance(value, str)
  if expected == 'integer':
    return isinstance(value, int) and not isinstance(value, bool)
  if expected == 'number':
    return isinstance(value, (int, float)) and not isinstance(value, bool)
  if expected == 'boolean':
    return isinstance(value, bool)
  if expected == 'null':
    return value is None
  return True

def validate(schema, value, path='$'):
  t = schema.get('type')
  if t is not None:
    if isinstance(t, list):
      if not any(type_ok(one, value) for one in t):
        fail(path, f'type mismatch, expected one of {t}')
    elif not type_ok(t, value):
      fail(path, f'type mismatch, expected {t}')

  if 'const' in schema and value != schema['const']:
    fail(path, 'const mismatch')

  if 'enum' in schema and value not in schema['enum']:
    fail(path, 'enum mismatch')

  if isinstance(value, str):
    if 'minLength' in schema and len(value) < schema['minLength']:
      fail(path, 'below minLength')
    if 'maxLength' in schema and len(value) > schema['maxLength']:
      fail(path, 'above maxLength')
    if 'pattern' in schema and not re.search(schema['pattern'], value):
      fail(path, 'pattern mismatch')

  if isinstance(value, (int, float)) and not isinstance(value, bool):
    if 'minimum' in schema and value < schema['minimum']:
      fail(path, 'below minimum')
    if 'maximum' in schema and value > schema['maximum']:
      fail(path, 'above maximum')

  if isinstance(value, list):
    if 'minItems' in schema and len(value) < schema['minItems']:
      fail(path, 'below minItems')
    if 'maxItems' in schema and len(value) > schema['maxItems']:
      fail(path, 'above maxItems')
    item_schema = schema.get('items')
    if isinstance(item_schema, dict):
      for idx, item in enumerate(value):
        validate(item_schema, item, f'{path}[{idx}]')

  if isinstance(value, dict):
    required = schema.get('required', [])
    for key in required:
      if key not in value:
        fail(path, f'missing required field: {key}')

    properties = schema.get('properties', {})
    for key, subschema in properties.items():
      if key in value:
        validate(subschema, value[key], f'{path}.{key}')

    if 'additionalProperties' in schema:
      additional = schema.get('additionalProperties', True)
    elif strict_mode and 'properties' in schema:
      additional = False
    else:
      additional = True
    if additional is False:
      extras = [k for k in value.keys() if k not in properties]
      if extras:
        fail(path, f'additionalProperties not allowed: {extras}')
    elif isinstance(additional, dict):
      for key, subval in value.items():
        if key not in properties:
          validate(additional, subval, f'{path}.{key}')

validate(schema, data)

print('OK')
PY
}

agent_enabled() {
  local agent="$1"
  python3 - "$agent" <<'PY'
import sys
agent = sys.argv[1]
p = '/home/steges/agent/skills/skill-forge/config/agents.yaml'
current = None
enabled = None
with open(p, 'r', encoding='utf-8') as f:
    for raw in f:
        line = raw.rstrip('\n')
        if line.startswith('  ') and line.strip().endswith(':'):
            current = line.strip().rstrip(':')
            continue
        if current == agent and 'enabled:' in line:
            enabled = line.split(':', 1)[1].strip().lower()
            break
print('1' if enabled == 'true' else '0')
PY
}

script_allowed_for_agent() {
  local agent="$1"
  local script_basename="$2"
  python3 - "$agent" "$script_basename" <<'PY'
import json, sys
agent, script = sys.argv[1], sys.argv[2]
p = '/home/steges/agent/skills/skill-forge/config/agent-contracts.json'
with open(p, 'r', encoding='utf-8') as f:
    d = json.load(f)
allowed = d.get(agent, [])
print('1' if script in allowed else '0')
PY
}

main() {
  ensure_dirs
  init_state_files
  local schema_file=""
  local strict_output="0"

  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      --validate-output)
        schema_file="${2:-}"
        [[ -n "$schema_file" ]] || { usage; exit "$EXIT_USAGE"; }
        shift 2
        ;;
      --strict-output)
        strict_output="1"
        shift
        ;;
      *)
        break
        ;;
    esac
  done

  [[ $# -ge 2 ]] || { usage; exit "$EXIT_USAGE"; }
  local agent="$1"
  local script="$2"
  local script_basename
  script_basename="$(basename "$script")"
  shift 2

  if [[ "$(agent_enabled "$agent")" != "1" ]]; then
    echo "Agent disabled: $agent"
    exit "$EXIT_CONTRACT"
  fi

  if [[ ! -x "$script" ]]; then
    echo "Script not executable: $script"
    exit "$EXIT_MISSING_EXECUTABLE"
  fi

  if [[ "$(script_allowed_for_agent "$agent" "$script_basename")" != "1" ]]; then
    echo "Contract violation: agent $agent cannot run $script_basename"
    exit "$EXIT_CONTRACT"
  fi

  if [[ -n "$schema_file" ]]; then
    [[ -f "$schema_file" ]] || { echo "Schema not found: $schema_file"; exit "$EXIT_USAGE"; }
    local out
    out="$(mktemp)"
    if ! "$script" "$@" >"$out"; then
      cat "$out"
      rm -f "$out"
      exit 1
    fi
    if ! validate_json_output "$schema_file" "$out" "$strict_output" >/dev/null 2>&1; then
      log_audit "CONTRACT" "$agent" "contract_output_violation script=$script_basename schema=$schema_file"
      echo "Contract output violation: agent=$agent script=$script_basename schema=$schema_file"
      rm -f "$out"
      exit "$EXIT_CONTRACT"
    fi
    log_audit "CONTRACT" "$agent" "contract_output_valid script=$script_basename schema=$schema_file"
    cat "$out"
    rm -f "$out"
    return
  fi

  "$script" "$@"
}

main "$@"
