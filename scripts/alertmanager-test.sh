#!/bin/bash
# Alertmanager Konfiguration testen (dry-run, keine echte Telegram-Nachricht)
# Usage: ./alertmanager-test.sh [--validate-config] [--test-webhook]

set -euo pipefail

ALERTMANAGER_CONFIG="/home/steges/alertmanager/config/alertmanager.yml"
ALERTMANAGER_URL="http://192.168.2.101:9093"
DRY_RUN=true

log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*"; }
log_error() { echo "[ERROR] $*"; }
log_ok() { echo "[OK] $*"; }

validate_config() {
  log_info "Validiere Alertmanager Konfiguration..."
  
  if [[ ! -f "$ALERTMANAGER_CONFIG" ]]; then
    log_error "Config nicht gefunden: $ALERTMANAGER_CONFIG"
    return 1
  fi
  
  # Prüfe auf Telegram-Token
  if grep -q "bot_token:" "$ALERTMANAGER_CONFIG"; then
    token=$(grep "bot_token:" "$ALERTMANAGER_CONFIG" | sed 's/.*bot_token: *//' | tr -d "'\"" | tr -d ' ')
    if [[ -n "$token" && "$token" != *"YOUR_BOT_TOKEN"* ]]; then
      log_ok "Telegram Bot Token konfiguriert"
    else
      log_warn "Telegram Bot Token ist leer oder ein Platzhalter"
    fi
  else
    log_warn "Kein bot_token in Config gefunden"
  fi
  
  # Prüfe auf Chat-ID
  if grep -q "chat_id:" "$ALERTMANAGER_CONFIG"; then
    chat_id=$(grep "chat_id:" "$ALERTMANAGER_CONFIG" | sed 's/.*chat_id: *//' | tr -d ' ')
    if [[ -n "$chat_id" && "$chat_id" =~ ^[0-9]+$ ]]; then
      log_ok "Telegram Chat ID konfiguriert: $chat_id"
    else
      log_warn "Telegram Chat ID ungültig oder leer"
    fi
  else
    log_warn "Keine chat_id in Config gefunden"
  fi
  
  # YAML-Syntax prüfen
  if command -v yq >/dev/null 2>&1; then
    if yq eval '.' "$ALERTMANAGER_CONFIG" >/dev/null 2>&1; then
      log_ok "YAML-Syntax ist gültig"
    else
      log_error "YAML-Syntax Fehler in Config"
      return 1
    fi
  else
    log_warn "yq nicht installiert, YAML-Validierung übersprungen"
  fi
  
  return 0
}

test_alertmanager_api() {
  log_info "Teste Alertmanager API..."
  
  if ! curl -sf "$ALERTMANAGER_URL/-/healthy" >/dev/null 2>&1; then
    log_warn "Alertmanager API nicht erreichbar unter $ALERTMANAGER_URL"
    log_info "Starte Alertmanager Container: docker compose up -d alertmanager"
    return 1
  fi
  
  log_ok "Alertmanager API erreichbar"
  
  # Zeige aktuelle Alerts
  log_info "Aktive Alerts:"
  curl -sf "$ALERTMANAGER_URL/api/v2/alerts" 2>/dev/null | \
    python3 -c "import sys,json; data=json.load(sys.stdin); print(f'  {len(data)} aktive Alerts')" || \
    echo "  Keine Alerts oder API-Fehler"
  
  return 0
}

dry_run_telegram() {
  log_info "[DRY-RUN] Simuliere Telegram-Nachricht..."
  
  # Lese Token und Chat ID aus Config
  token=$(grep "bot_token:" "$ALERTMANAGER_CONFIG" 2>/dev/null | sed "s/.*bot_token: *//;s/['\"]//g" | tr -d ' ' || echo "")
  chat_id=$(grep "chat_id:" "$ALERTMANAGER_CONFIG" 2>/dev/null | sed 's/.*chat_id: *//' | tr -d ' ' || echo "")
  
  if [[ -z "$token" || -z "$chat_id" ]]; then
    log_warn "Telegram nicht vollständig konfiguriert"
    return 1
  fi
  
  log_info "[DRY-RUN] Würde senden an Chat $chat_id:"
  echo "  📊 Alertmanager Test"
  echo "  Status: OK"
  echo "  Zeit: $(date '+%Y-%m-%d %H:%M:%S')"
  
  return 0
}

show_config_summary() {
  log_info "Alertmanager Konfiguration Zusammenfassung:"
  echo "  Config: $ALERTMANAGER_CONFIG"
  echo "  URL: $ALERTMANAGER_URL"
  
  if [[ -f "$ALERTMANAGER_CONFIG" ]]; then
    receivers=$(grep "receiver:" "$ALERTMANAGER_CONFIG" | head -1 | sed 's/.*receiver: *//' | tr -d "'\"" || echo "unbekannt")
    echo "  Default Receiver: $receivers"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Hauptlogik
# ═══════════════════════════════════════════════════════════════════════════

echo "════════════════════════════════════════════════════════════"
echo "  Alertmanager Test & Validierung"
echo "════════════════════════════════════════════════════════════"
echo ""

show_config_summary
echo ""

if validate_config; then
  echo ""
  test_alertmanager_api
  echo ""
  dry_run_telegram
  echo ""
  log_info "Test abgeschlossen."
  log_info "Für echten Test: Trigger einen Alert oder sende manuell:"
  log_info "  curl -X POST $ALERTMANAGER_URL/api/v2/alerts -d '[{\"labels\":{...}}]'"
  exit 0
else
  log_error "Validierung fehlgeschlagen."
  exit 1
fi
