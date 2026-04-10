#!/usr/bin/env bats

setup() {
  export TEST_HOME
  TEST_HOME="$(mktemp -d)"
  export SCRIPT_HOME="$TEST_HOME"

  mkdir -p "$SCRIPT_HOME/pihole/config"
  mkdir -p "$SCRIPT_HOME/homeassistant/config"
  mkdir -p "$SCRIPT_HOME/esphome/config"
  mkdir -p "$SCRIPT_HOME/mosquitto/config"
  mkdir -p "$SCRIPT_HOME/tailscale/state"
  mkdir -p "$SCRIPT_HOME/agent/skills"
  mkdir -p "$SCRIPT_HOME/infra/openclaw-data/rag"
  mkdir -p "$SCRIPT_HOME/infra/openclaw-data/ui-state"

  echo "ok" > "$SCRIPT_HOME/pihole/config/sample.txt"
  echo "ok" > "$SCRIPT_HOME/infra/openclaw-data/rag/index.db"
}

teardown() {
  rm -rf "$TEST_HOME"
}

@test "backup script creates tar archives and exits 0" {
  run env HOME="$SCRIPT_HOME" /home/steges/scripts/backup.sh
  [ "$status" -eq 0 ]

  backup_dir="$SCRIPT_HOME/backups/$(date +%Y-%m-%d)"
  [ -d "$backup_dir" ]
  [ -s "$backup_dir/pihole-config.tar.gz" ]
  [ -s "$backup_dir/openclaw-rag.tar.gz" ]
}

@test "backup skips missing directories but still succeeds" {
  rm -rf "$SCRIPT_HOME/esphome/config"
  run env HOME="$SCRIPT_HOME" /home/steges/scripts/backup.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"SKIP esphome-config"* ]]
}
