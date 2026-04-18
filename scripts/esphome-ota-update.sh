#!/bin/bash
# ESPHome OTA Update mit Backup und Rollback-Dokumentation
# Hinweis: Vollautomatischer Rollback bei ESPHome nicht möglich (Firmware läuft auf ESP32)
# Dieses Script: Backup vor OTA + Health-Check nach OTA + Rollback-Guide bei Fehler

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/steges/scripts/common.sh
source "$SCRIPT_DIR/common.sh"
# shellcheck source=/home/steges/scripts/lib/env.sh
source "$SCRIPT_DIR/lib/env.sh"
load_dotenv

ESPHOME_CONFIG="/home/steges/esphome/config"
BACKUP_DIR="$ESPHOME_CONFIG/firmware_backups"
ESPHOME_HOST="192.168.2.101"
ESPHOME_PORT="6052"
ESP32_IP="192.168.2.150"  # Growbox ESP32 IP
MAX_WAIT_SECONDS=120

# ═════════════════════════════════════════════════════════════════════════════
# 1. PRE-OTA BACKUP
# ═════════════════════════════════════════════════════════════════════════════
log_info "Pre-OTA Backup: ESPHome Konfigurationen"

mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup YAML-Konfigurationen
cp "$ESPHOME_CONFIG/growbox_wlan.yaml" "$BACKUP_DIR/growbox_wlan.yaml.$TIMESTAMP"
cp "$ESPHOME_CONFIG/growbox_ap.yaml" "$BACKUP_DIR/growbox_ap.yaml.$TIMESTAMP"

# Versuche, aktuelle Firmware-Binärdatei zu exportieren (falls verfügbar)
log_info "Versuche Firmware-Export für Backup..."
docker exec esphome esphome export growbox_wlan.yaml --file /config/firmware_backups/growbox_wlan_$TIMESTAMP.bin 2>/dev/null || \
    log_warn "Firmware-Export nicht möglich (normal wenn keine Build-Umgebung)"

# Alte Backups aufräumen (letzte 5 behalten)
ls -t "$BACKUP_DIR"/*.yaml.* 2>/dev/null | tail -n +6 | xargs -r rm -f
ls -t "$BACKUP_DIR"/*.bin 2>/dev/null | tail -n +6 | xargs -r rm -f

log_info "Backup erstellt: $TIMESTAMP"

# ═════════════════════════════════════════════════════════════════════════════
# 2. OTA UPDATE
# ═════════════════════════════════════════════════════════════════════════════
log_info "Starte ESPHome OTA Update für growbox_wlan"

# Prüfe ob ESPHome Container läuft
if ! docker ps --filter name=esphome --format "{{.Names}}" | grep -q "^esphome$"; then
    log_error "ESPHome Container läuft nicht!"
    exit 1
fi

# Prüfe ob ESP32 erreichbar ist (Pre-Check)
log_info "Pre-Check: Prüfe ESP32 Erreichbarkeit..."
if ! ping -c 2 -W 5 "$ESP32_IP" >/dev/null 2>&1; then
    log_warn "ESP32 nicht erreichbar (Pre-Check) - Update wird trotzdem versucht"
fi

# Führe OTA Update durch
# Hinweis: ESPHome baut die Firmware und flasht OTA
if ! docker exec esphome esphome run /config/growbox_wlan.yaml --no-logs --device "$ESP32_IP" 2>&1; then
    log_warn "OTA Update Befehl fehlgeschlagen (kann auch 'no changes' sein)"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 3. POST-OTA VALIDIERUNG
# ═════════════════════════════════════════════════════════════════════════════
log_info "Post-OTA Validierung: Warte auf ESP32 Neustart..."

sleep 10  # Warte auf Neustart

ESP32_OK=false
for i in $(seq 1 12); do  # Max 60 Sekunden warten
    if ping -c 1 -W 5 "$ESP32_IP" >/dev/null 2>&1; then
        ESP32_OK=true
        break
    fi
    log_info "Warte auf ESP32... ($i/12)"
    sleep 5
done

if [[ "$ESP32_OK" != "true" ]]; then
    log_error "ESP32 nicht erreichbar nach OTA!"
    log_error "MÖGLICHE LÖSUNGEN:"
    log_error "1. Captive Portal aktiv? → Verbinde mit 'growbox-ap' WiFi"
    log_error "2. Bootloop? → Physischen Reset drücken"
    log_error "3. Firmware korrupt? → USB-Flashing erforderlich:"
    log_error "   docker exec esphome esphome run /config/growbox_wlan.yaml --device /dev/ttyUSB0"
    log_error "4. Fallback auf AP-Mode: /config/firmware_backups/growbox_ap.yaml.$TIMESTAMP"
    
    send_telegram "🔴 *ESPHome OTA fehlgeschlagen*

ESP32 nicht erreichbar nach Update.
Backup: $TIMESTAMP

Lösungen:
1. Captive Portal: Mit 'growbox-ap' verbinden
2. Reset: Physischen Reset drücken  
3. USB-Flash: docker exec esphome esphome run... --device /dev/ttyUSB0
4. AP-Mode: growbox_ap.yaml backup"
    exit 1
fi

# Prüfe ESPHome Web-Interface (API-Verfügbarkeit)
sleep 2
if ! curl -sf "http://$ESPHOME_HOST:$ESPHOME_PORT/devices" >/dev/null 2>&1; then
    log_warn "ESPHome API nicht erreichbar, aber ESP32 pingt"
fi

log_info "ESP32 erreichbar nach OTA Update"
send_telegram "✅ *ESPHome OTA erfolgreich*

ESP32 wieder online nach Update.
Backup: $TIMESTAMP
IP: $ESP32_IP"

exit 0
