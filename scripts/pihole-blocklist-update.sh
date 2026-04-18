#!/bin/bash
# Pi-hole Blocklist Update mit automatischem Rollback bei Fehler
# Wichtig: Pi-hole ist DNS + DHCP für das LAN - Ausfall = kompletter LAN-Ausfall

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/steges/scripts/common.sh
source "$SCRIPT_DIR/common.sh"
# shellcheck source=/home/steges/scripts/lib/env.sh
source "$SCRIPT_DIR/lib/env.sh"
load_dotenv

PIHOLE_CONFIG="/home/steges/pihole/config"
BACKUP_DIR="$PIHOLE_CONFIG/manual_backups"
GRAVITY_DB="$PIHOLE_CONFIG/gravity.db"
TEST_DOMAIN="google.com"
MAX_RETRIES=3
RETRY_DELAY=5

# Erstelle Backup-Verzeichnis
mkdir -p "$BACKUP_DIR"

# ═════════════════════════════════════════════════════════════════════════════
# 1. PRE-UPDATE BACKUP
# ═════════════════════════════════════════════════════════════════════════════
log_info "Pre-Update Backup: gravity.db und adlists.list"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_GRAVITY="$BACKUP_DIR/gravity.db.$TIMESTAMP"
BACKUP_ADLISTS="$BACKUP_DIR/adlists.list.$TIMESTAMP"

cp "$GRAVITY_DB" "$BACKUP_GRAVITY"
cp "$PIHOLE_CONFIG/adlists.list" "$BACKUP_ADLISTS"

log_info "Backup erstellt: $BACKUP_GRAVITY"

# Alte Backups aufräumen (nur die letzten 5 behalten)
ls -t "$BACKUP_DIR"/gravity.db.* 2>/dev/null | tail -n +6 | xargs -r rm -f
ls -t "$BACKUP_DIR"/adlists.list.* 2>/dev/null | tail -n +6 | xargs -r rm -f

# ═════════════════════════════════════════════════════════════════════════════
# 2. BLOCKLIST UPDATE
# ═════════════════════════════════════════════════════════════════════════════
log_info "Starte Pi-hole gravity update (pihole -g)"

# Prüfe ob Pi-hole Container läuft
if ! docker ps --filter name=pihole --format "{{.Names}}" | grep -q "^pihole$"; then
    log_error "Pi-hole Container läuft nicht!"
    exit 1
fi

# Führe Update durch
if ! docker exec pihole pihole -g; then
    log_error "Pi-hole gravity update fehlgeschlagen"
    # Trotzdem weiter zu Post-Check (manchmal ist DB trotzdem OK)
fi

# ═════════════════════════════════════════════════════════════════════════════
# 3. POST-UPDATE VALIDIERUNG
# ═════════════════════════════════════════════════════════════════════════════
log_info "Post-Update Validierung..."

# Warte auf DNS-Propagation
sleep 3

# Teste DNS-Auflösung mehrfach
DNS_OK=false
for i in $(seq 1 $MAX_RETRIES); do
    if docker exec pihole dig +short "$TEST_DOMAIN" @127.0.0.1 >/dev/null 2>&1; then
        DNS_OK=true
        break
    fi
    log_warn "DNS-Test $i/$MAX_RETRIES fehlgeschlagen, warte ${RETRY_DELAY}s..."
    sleep $RETRY_DELAY
done

# Teste Blocklist-Funktionalität (sollte blockierte Domain nicht auflösen)
BLOCKED_DOMAIN="doubleclick.net"
BLOCK_TEST=$(docker exec pihole dig +short "$BLOCKED_DOMAIN" @127.0.0.1 2>/dev/null || true)

# Wenn DNS OK und Blocklist funktioniert (leere Antwort oder 0.0.0.0)
if [[ "$DNS_OK" == "true" ]] && [[ -z "$BLOCK_TEST" || "$BLOCK_TEST" == "0.0.0.0" ]]; then
    log_info "Update erfolgreich: DNS funktioniert, Blocklist aktiv"
    send_telegram "✅ *Pi-hole Update erfolgreich*

Blocklists aktualisiert.
DNS-Resolution: OK
Blocklist-Test: OK (doubleclick.net geblockt)"
    exit 0
fi

# ═════════════════════════════════════════════════════════════════════════════
# 4. ROLLBACK BEI FEHLER
# ═════════════════════════════════════════════════════════════════════════════
log_error "Post-Update Check fehlgeschlagen - Starte Rollback!"
log_info "Stelle gravity.db aus Backup wieder her: $BACKUP_GRAVITY"

# Stoppe Pi-hole nicht - nur gravity.db ersetzen
cp "$BACKUP_GRAVITY" "$GRAVITY_DB"
cp "$BACKUP_ADLISTS" "$PIHOLE_CONFIG/adlists.list"

# Lade gravity neu (ohne erneuten Download der Listen)
docker exec pihole pihole restartdns

sleep 3

# Teste DNS nach Rollback
ROLLBACK_OK=false
for i in $(seq 1 $MAX_RETRIES); do
    if docker exec pihole dig +short "$TEST_DOMAIN" @127.0.0.1 >/dev/null 2>&1; then
        ROLLBACK_OK=true
        break
    fi
    sleep $RETRY_DELAY
done

if [[ "$ROLLBACK_OK" == "true" ]]; then
    log_warn "Rollback erfolgreich - DNS funktioniert wieder"
    send_telegram "⚠️ *Pi-hole Rollback durchgeführt*

Update fehlgeschlagen, aber Rollback erfolgreich.
DNS-Resolution: Wiederhergestellt
Backup: $TIMESTAMP"
    exit 1
else
    log_error "Rollback fehlgeschlagen - Manuelle Intervention erforderlich!"
    send_telegram "🔴 *Pi-hole Update + Rollback fehlgeschlagen*

DNS nicht funktionsfähig!
Manuelle Intervention sofort erforderlich.
Backup: $TIMESTAMP"
    exit 1
fi
