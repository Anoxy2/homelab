#!/bin/bash
# Sichert alle relevanten Daten der Docker-Stacks

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/steges/scripts/common.sh
source "$SCRIPT_DIR/common.sh"

BACKUP_DIR="$HOME/backups/$(date +%Y-%m-%d)"
mkdir -p "$BACKUP_DIR"

ERRORS=0

backup_dir() {
    local name="$1"
    local src="$2"
    local dest="$BACKUP_DIR/${name}.tar.gz"

    if [ ! -d "$src" ]; then
        log_warn "SKIP $name - Verzeichnis nicht gefunden: $src"
        return
    fi

    local parent
    parent=$(dirname "$src")
    local base
    base=$(basename "$src")

    log_info "Backup starte: $name"
    if tar -czf "$dest" -C "$parent" "$base/" 2>/dev/null; then
        # Integrität: Datei muss > 0 Bytes sein
        if [ -s "$dest" ]; then
            log_info "Backup ok: $dest ($(du -sh "$dest" | cut -f1))"
        else
            log_error "$name - Archiv ist leer"
            rm -f "$dest"
            ((ERRORS++))
        fi
    else
        log_error "$name - tar fehlgeschlagen"
        rm -f "$dest"
        ((ERRORS++))
    fi
}

# Config-Verzeichnisse der Stacks
backup_dir "pihole-config"       "$HOME/pihole/config"
backup_dir "homeassistant-config" "$HOME/homeassistant/config"
backup_dir "esphome-config"      "$HOME/esphome/config"

# Mosquitto
backup_dir "mosquitto-config"    "$HOME/mosquitto/config"

# Tailscale State
backup_dir "tailscale-state"     "$HOME/tailscale/state"

# Agent Skills
backup_dir "agent-skills"        "$HOME/agent/skills"

# OpenClaw RAG-Index und UI-State
# Hinweis: rag/snapshots/ ist im rag/-Backup enthalten, kein separates Backup nötig
backup_dir "openclaw-rag"        "$HOME/infra/openclaw-data/rag"
backup_dir "openclaw-ui-state"   "$HOME/infra/openclaw-data/ui-state"

# InfluxDB 2 Zeitreihen-Daten
backup_dir "influxdb-data"       "$HOME/influxdb/data"

echo ""
if [ $ERRORS -eq 0 ]; then
    log_info "Backup abgeschlossen: $BACKUP_DIR"
else
    log_warn "Backup mit $ERRORS Fehler(n) abgeschlossen: $BACKUP_DIR"
fi

# Backups älter als 30 Tage löschen
find "$HOME/backups" -maxdepth 1 -type d -mtime +30 -exec rm -rf {} + 2>/dev/null || true

# ─── Offsite-Backup via Restic ─────────────────────────────────────────────
# Nur aktiv wenn RESTIC_REPOSITORY und RESTIC_PASSWORD in .env gesetzt sind.
# Konfiguration: .env.example für Vorlagen, docs/operations/maintenance-and-backups.md für Einrichtung.
if [[ -n "${RESTIC_REPOSITORY:-}" && -n "${RESTIC_PASSWORD:-}" ]]; then
    log_info "Restic: Offsite-Backup starte nach $RESTIC_REPOSITORY"

    # Repo initialisieren falls noch nicht vorhanden
    if ! restic snapshots --quiet >/dev/null 2>&1; then
        log_info "Restic: Initialisiere neues Repository"
        if ! restic init 2>&1 | grep -q "created restic repository"; then
            log_warn "Restic: Repository-Init fehlgeschlagen oder bereits vorhanden"
        fi
    fi

    # Backup der lokalen Quell-Verzeichnisse (nicht der tar.gz Archive)
    RESTIC_SOURCES=(
        "$HOME/pihole/config"
        "$HOME/homeassistant/config"
        "$HOME/esphome/config"
        "$HOME/mosquitto/config"
        "$HOME/tailscale/state"
        "$HOME/agent/skills"
        "$HOME/infra/openclaw-data/rag"
        "$HOME/infra/openclaw-data/ui-state"
        "$HOME/influxdb/data"
    )
    RESTIC_EXCLUDES=(
        "--exclude=*.pyc"
        "--exclude=__pycache__"
        "--exclude=*.log"
        "--exclude=node_modules"
    )

    if restic backup "${RESTIC_EXCLUDES[@]}" "${RESTIC_SOURCES[@]}" \
        --tag "pilab-daily" \
        --host "pilab" \
        2>&1 | tail -3; then
        log_info "Restic: Backup abgeschlossen"
    else
        log_warn "Restic: Backup fehlgeschlagen (Fehlercode $?)"
        ((ERRORS++))
    fi

    # Retention: 7 tägliche, 4 wöchentliche, 3 monatliche Snapshots behalten
    restic forget \
        --keep-daily 7 \
        --keep-weekly 4 \
        --keep-monthly 3 \
        --prune \
        --tag "pilab-daily" \
        --quiet 2>&1 || log_warn "Restic: forget/prune fehlgeschlagen"
else
    log_info "Restic: Übersprungen (RESTIC_REPOSITORY oder RESTIC_PASSWORD nicht gesetzt)"
fi

[ $ERRORS -eq 0 ] && exit 0 || exit 1
