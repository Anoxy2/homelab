#!/usr/bin/env bats

setup() {
  export TEST_ROOT
  TEST_ROOT="$(mktemp -d)"
  export STUB_BIN="$TEST_ROOT/bin"
  mkdir -p "$STUB_BIN"

  cat > "$STUB_BIN/curl" <<'SH'
#!/bin/bash
if [[ -n "${CURL_FAIL_PATTERN:-}" ]]; then
  for arg in "$@"; do
    if [[ "$arg" == *"$CURL_FAIL_PATTERN"* ]]; then
      exit 1
    fi
  done
fi
exit 0
SH

  cat > "$STUB_BIN/timeout" <<'SH'
#!/bin/bash
# emulate: timeout 5 bash -c "..."
shift
"$@"
SH

  cat > "$STUB_BIN/bash" <<'SH'
#!/bin/bash
if [[ "${1:-}" == "-c" ]]; then
  exit 0
fi
exec /bin/bash "$@"
SH

  cat > "$STUB_BIN/df" <<'SH'
#!/bin/bash
cat <<'EOF'
Filesystem     1K-blocks    Used Available Use% Mounted on
/dev/root       10000000 1000000   9000000  10% /
EOF
SH

  cat > "$STUB_BIN/vcgencmd" <<'SH'
#!/bin/bash
echo "temp=50.0'C"
SH

  cat > "$STUB_BIN/smartctl" <<'SH'
#!/bin/bash
cat <<'EOF'
=== START OF SMART DATA SECTION ===
SMART overall-health self-assessment test result: PASSED
EOF
SH

  cat > "$STUB_BIN/stat" <<'SH'
#!/bin/bash
if [[ "${1:-}" == "-c" && "${2:-}" == "%Y" ]]; then
  date +%s
  exit 0
fi
exec /usr/bin/stat "$@"
SH

  cat > "$STUB_BIN/docker" <<'SH'
#!/bin/bash
if [[ "${1:-}" == "ps" ]]; then
  # health-check erwartet hier den Containernamen auf stdout
  if [[ "$*" == *"name=mosquitto"* ]]; then
    echo "mosquitto"
    exit 0
  fi
  if [[ "$*" == *"name=influxdb"* ]]; then
    echo "influxdb"
    exit 0
  fi
  exit 0
fi

if [[ "${1:-}" == "exec" ]]; then
  # Fuer die Tests reicht ein erfolgreiches no-op Verhalten.
  exit 0
fi

exit 0
SH

  cat > "$STUB_BIN/python3" <<'SH'
#!/bin/bash
# Stub fuer die verschiedenen python3-Aufrufe im health-check Script.
if [[ "${1:-}" == "/home/steges/agent/skills/openclaw-rag/scripts/retrieve.py" ]]; then
  echo '{"count":1,"search_mode":"semantic"}'
  exit 0
fi

if [[ "${1:-}" == "-" ]]; then
  case "${2:-}" in
    /home/steges/infra/openclaw-data/rag/.reindex.status)
      echo 'success||2026-01-01T00:00:00Z'
      exit 0
      ;;
    /home/steges/infra/openclaw-data/rag/index.db)
      echo '100|100|10'
      exit 0
      ;;
    \{*)
      echo '1|semantic|'
      exit 0
      ;;
  esac
fi

exit 0
SH

  chmod +x "$STUB_BIN"/*
}

teardown() {
  rm -rf "$TEST_ROOT"
}

@test "health-check returns 0 when probes are healthy" {
  run env PATH="$STUB_BIN:/usr/bin:/bin" LOG_LEGACY_TEXT=1 /home/steges/scripts/health-check.sh
  if [ "$status" -ne 0 ]; then
    echo "$output"
    false
  fi
  [[ "$output" == *"Result:"* ]]
}

@test "health-check returns 1 when one HTTP probe fails" {
  run env PATH="$STUB_BIN:/usr/bin:/bin" LOG_LEGACY_TEXT=1 CURL_FAIL_PATTERN=":18789" /home/steges/scripts/health-check.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL OpenClaw"* ]]
}
