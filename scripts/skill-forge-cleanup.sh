#!/bin/bash
# Skill-Forge Cleanup: Entfernt leere Platzhalter und alte generierte Dateien
# Usage: ./skill-forge-cleanup.sh [--dry-run]

set -euo pipefail

GENERATED_DIR="/home/steges/agent/skills/skill-forge/generated"
STATE_DIR="/home/steges/agent/skills/skill-forge/.state"
BAK_KEEP=3
DRY_RUN=false
DELETED=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY-RUN] Keine Dateien werden wirklich gelöscht"
fi

log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*"; }
log_delete() { echo "[DELETE] $*"; }

rotate_bak_snapshots() {
  log_info "Rotiere Skill-Forge .bak Snapshots in $STATE_DIR (keep=$BAK_KEEP)..."

  if [[ ! -d "$STATE_DIR" ]]; then
    log_warn "State-Verzeichnis nicht gefunden: $STATE_DIR"
    return
  fi

  while IFS= read -r bak_file; do
    [[ -f "$bak_file" ]] || continue

    local base ts snapshot
    base="$(basename "$bak_file")"
    ts="$(date +%Y%m%d%H%M%S)"
    snapshot="$STATE_DIR/${base}.${ts}"

    if [[ "$DRY_RUN" == true ]]; then
      log_info "[DRY-RUN] Snapshot erstellen: $(basename "$snapshot")"
    else
      cp -f "$bak_file" "$snapshot"
      log_info "Snapshot erstellt: $(basename "$snapshot")"
    fi

    mapfile -t old_snapshots < <(ls -1t "$STATE_DIR/${base}."[0-9]* 2>/dev/null | tail -n +$((BAK_KEEP + 1)) || true)
    for old_file in "${old_snapshots[@]}"; do
      [[ -f "$old_file" ]] || continue
      if [[ "$DRY_RUN" == true ]]; then
        log_delete "[DRY-RUN] Altes .bak Snapshot: $(basename "$old_file")"
      else
        log_delete "Altes .bak Snapshot: $(basename "$old_file")"
        rm -f "$old_file"
        ((DELETED++))
      fi
    done
  done < <(find "$STATE_DIR" -maxdepth 1 -type f -name "*.bak" 2>/dev/null | sort)
}

cleanup_legacy_audit_log() {
  local legacy_log="$STATE_DIR/audit.log"
  if [[ -f "$legacy_log" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      log_delete "[DRY-RUN] Legacy Audit-Log: $(basename "$legacy_log")"
    else
      log_delete "Legacy Audit-Log entfernt: $(basename "$legacy_log")"
      rm -f "$legacy_log"
      ((DELETED++))
    fi
  fi
}

# Leere Dateien (nur Platzhalter-Kommentare)
cleanup_empty_placeholders() {
  log_info "Prüfe leere Platzhalter in $1..."
  
  while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    
    # Zähle Zeilen die nicht Kommentare oder leer sind
    code_lines=$(grep -v -E '^\s*(#|//|/\*|\*/|\*|\s*$)' "$file" 2>/dev/null | wc -l || echo "0")
    
    if [[ "$code_lines" -eq 0 ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        log_delete "[DRY-RUN] Leerer Platzhalter: $file"
      else
        log_delete "Leerer Platzhalter: $file"
        rm -f "$file"
        ((DELETED++))
      fi
    fi
  done < <(find "$1" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.js" \) 2>/dev/null)
}

# Temporäre/Test-Dateien in envelopes/
cleanup_test_files() {
  log_info "Prüfe Test-Dateien in $1/envelopes/..."
  
  while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    
    filename=$(basename "$file")
    
    # Lösche Test-Dateien (test*, *-test*, temp*, tmp*)
    if [[ "$filename" =~ ^(test|temp|tmp|slug-collision-test) ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        log_delete "[DRY-RUN] Test-Datei: $filename"
      else
        log_delete "Test-Datei: $filename"
        rm -f "$file"
        ((DELETED++))
      fi
    fi
  done < <(find "$1/envelopes" -type f -name "*.json" 2>/dev/null)
}

# Alte Config-Dateien (>30 Tage)
cleanup_old_configs() {
  log_info "Prüfe alte Config-Dateien in $1/config/..."
  
  while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    
    # Prüfe Alter (>30 Tage)
    if [[ -n "$(find "$file" -mtime +30 2>/dev/null)" ]]; then
      filename=$(basename "$file")
      if [[ "$DRY_RUN" == true ]]; then
        log_delete "[DRY-RUN] Alte Config (>30d): $filename"
      else
        log_delete "Alte Config (>30d): $filename"
        rm -f "$file"
        ((DELETED++))
      fi
    fi
  done < <(find "$1/config" -type f 2>/dev/null)
}

# Leere Verzeichnisse bereinigen
cleanup_empty_dirs() {
  log_info "Entferne leere Verzeichnisse..."
  
  find "$1" -type d -empty 2>/dev/null | while read -r dir; do
    if [[ "$DRY_RUN" == true ]]; then
      log_delete "[DRY-RUN] Leeres Verzeichnis: $dir"
    else
      rmdir "$dir" 2>/dev/null && log_delete "Leeres Verzeichnis: $dir"
    fi
  done
}

# ═══════════════════════════════════════════════════════════════════════════
# Hauptlogik
# ═══════════════════════════════════════════════════════════════════════════

if [[ ! -d "$GENERATED_DIR" ]]; then
  log_warn "Generated-Verzeichnis nicht gefunden: $GENERATED_DIR"
  exit 1
fi

log_info "Skill-Forge Cleanup gestartet: $GENERATED_DIR"
log_info "Mode: $([[ "$DRY_RUN" == true ]] && echo "DRY-RUN" || echo "LIVE")"
echo ""

# Cleanup durchführen
cleanup_empty_placeholders "$GENERATED_DIR"
cleanup_test_files "$GENERATED_DIR"
cleanup_old_configs "$GENERATED_DIR"
cleanup_empty_dirs "$GENERATED_DIR"
rotate_bak_snapshots
cleanup_legacy_audit_log

echo ""
if [[ "$DRY_RUN" == true ]]; then
  log_info "[DRY-RUN] Fertig. Nutze --dry-run entfernen für echtes Löschen."
else
  log_info "Fertig. $DELETED Dateien/Verzeichnisse gelöscht."
fi

exit 0
