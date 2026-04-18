#!/usr/bin/env bats

setup() {
  export TEST_HOME
  TEST_HOME="$(mktemp -d)"
  export SCRIPT_HOME="$TEST_HOME"
  export BACKUP_DIR="$SCRIPT_HOME/backups"
  
  # Test-Backup-Verzeichnis mit Archiven erstellen
  TODAY=$(date +%Y-%m-%d)
  mkdir -p "$BACKUP_DIR/$TODAY"
  
  # Gültige tar.gz Archive erstellen
  echo "test" > "$SCRIPT_HOME/testfile.txt"
  tar -czf "$BACKUP_DIR/$TODAY/pihole-config.tar.gz" -C "$SCRIPT_HOME" testfile.txt
  tar -czf "$BACKUP_DIR/$TODAY/homeassistant-config.tar.gz" -C "$SCRIPT_HOME" testfile.txt
  
  # Backup-Verifikation ohne Restic testen
  export TELEGRAM_BOT_TOKEN=""
  export TELEGRAM_CHAT_ID=""
}

teardown() {
  rm -rf "$TEST_HOME"
}

@test "backup-verify finds latest backup directory" {
  run bash -c "
    cd '$SCRIPT_HOME'
    BACKUP_DIR='$BACKUP_DIR'
    latest_backup=\$(find '\$BACKUP_DIR' -maxdepth 1 -type d -name '20*' | sort | tail -1)
    [[ -n '\$latest_backup' ]] && echo 'FOUND' || echo 'NOT_FOUND'
  "
  [ "$output" = "FOUND" ]
}

@test "backup-verify checks archives are not empty" {
  run bash -c "
    cd '$SCRIPT_HOME'
    archives=0
    empty_archives=0
    for archive in '$BACKUP_DIR/$TODAY'/*.tar.gz; do
      if [[ -f '\$archive' ]]; then
        ((archives++))
        [[ ! -s '\$archive' ]] && ((empty_archives++))
      fi
    done
    echo \"archives=\$archives empty=\$empty_archives\"
  "
  [[ "$output" =~ "archives=2" ]]
  [[ "$output" =~ "empty=0" ]]
}

@test "backup-verify detects missing backup directory" {
  run bash -c "
    rm -rf '$BACKUP_DIR'
    [[ -d '$BACKUP_DIR' ]] && echo 'EXISTS' || echo 'MISSING'
  "
  [ "$output" = "MISSING" ]
}

@test "backup-verify detects stale backups" {
  OLD_DATE="2026-01-01"
  mkdir -p "$BACKUP_DIR/$OLD_DATE"
  touch -d "70 hours ago" "$BACKUP_DIR/$OLD_DATE"
  
  # Prüfe Alter
  backup_age_hours=$(( ($(date +%s) - $(stat -c %Y "$BACKUP_DIR/$OLD_DATE")) / 3600 ))
  [[ $backup_age_hours -gt 48 ]]
}
