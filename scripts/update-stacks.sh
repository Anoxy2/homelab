#!/bin/bash
# Pulled neue Images für alle Stacks und startet sie neu

set -e

STACKS=("pihole" "homeassistant" "infra")

for stack in "${STACKS[@]}"; do
    dir="$HOME/$stack"
    if [ -f "$dir/docker-compose.yml" ]; then
        echo "Updating $stack..."
        cd "$dir"
        docker compose pull
        docker compose up -d
        echo "  -> $stack updated"
    else
        echo "Skipping $stack (no docker-compose.yml)"
    fi
done

echo "All stacks updated."
