#!/bin/bash
# Sichert alle config/-Ordner der Docker-Stacks

set -e

BACKUP_DIR="$HOME/backups/$(date +%Y-%m-%d)"
mkdir -p "$BACKUP_DIR"

STACKS=("pihole" "homeassistant")

for stack in "${STACKS[@]}"; do
    src="$HOME/$stack/config"
    if [ -d "$src" ]; then
        echo "Backing up $stack..."
        tar -czf "$BACKUP_DIR/${stack}-config.tar.gz" -C "$HOME/$stack" config/
        echo "  -> $BACKUP_DIR/${stack}-config.tar.gz"
    else
        echo "Skipping $stack (no config/ dir)"
    fi
done

echo "Backup done: $BACKUP_DIR"

# Backups älter als 30 Tage löschen
find "$HOME/backups" -maxdepth 1 -type d -mtime +30 -exec rm -rf {} + 2>/dev/null || true
