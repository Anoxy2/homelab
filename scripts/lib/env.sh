#!/bin/bash
# Gemeinsame Hilfsfunktion zum Laden der .env-Datei.
# Usage: source /home/steges/scripts/lib/env.sh && load_dotenv

ENV_FILE="/home/steges/.env"

load_dotenv() {
  [[ -f "$ENV_FILE" ]] || return 0
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
}
