#!/usr/bin/env bash
set -euo pipefail

SERVICE_SRC="/home/steges/systemd/openclaw-compose.service"
SERVICE_DST="/etc/systemd/system/openclaw-compose.service"

if [[ ! -f "$SERVICE_SRC" ]]; then
  echo "Service source not found: $SERVICE_SRC"
  exit 1
fi

echo "Installing systemd unit to $SERVICE_DST"
sudo cp "$SERVICE_SRC" "$SERVICE_DST"

echo "Reloading systemd daemon"
sudo systemctl daemon-reload

echo "Enabling service"
sudo systemctl enable openclaw-compose.service

echo "Starting service now"
sudo systemctl start openclaw-compose.service

echo "Status:"
sudo systemctl --no-pager --full status openclaw-compose.service || true

echo "Done. OpenClaw will auto-start on boot."
