#!/bin/bash
# Prüft ob alle Services erreichbar sind

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/home/steges/scripts/common.sh
source "$SCRIPT_DIR/common.sh"

PI_IP="192.168.2.101"
OK=0
FAIL=0
log_info "Health-Check gestartet"
echo ""

check_http() {
    local name="$1"
    local url="$2"
    if curl -sf --max-time 5 "$url" > /dev/null 2>&1; then
        log_info "OK   $name ($url)"
        OK=$((OK + 1))
    else
        log_error "FAIL $name ($url)"
        FAIL=$((FAIL + 1))
    fi
}

check_influx_query() {
    # InfluxDB Query-Test: verifiziert echte Query-Ausfuehrung statt nur ping.
    if ! command -v docker >/dev/null 2>&1; then
        log_warn "WARN InfluxDB Query-Test uebersprungen (docker nicht verfuegbar)"
        return
    fi

    if ! docker ps --filter name=influxdb --format "{{.Names}}" | grep -q "^influxdb$"; then
        log_error "FAIL InfluxDB Query-Test (Container influxdb nicht erreichbar)"
        FAIL=$((FAIL + 1))
        return
    fi

    if docker exec influxdb sh -lc 'influx query --org "${DOCKER_INFLUXDB_INIT_ORG:-pilab}" --token "${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN:-}" "buckets() |> limit(n:1)" >/dev/null 2>&1' ; then
        log_info "OK   InfluxDB Query-Test"
        OK=$((OK + 1))
    else
        log_error "FAIL InfluxDB Query-Test (Query fehlgeschlagen)"
        FAIL=$((FAIL + 1))
    fi
}

check_http_host() {
    local name="$1"
    local ip="$2"
    local host_header="$3"
    if curl -sf --max-time 5 -H "Host: $host_header" "http://$ip/" > /dev/null 2>&1; then
        log_info "OK   $name (Host: $host_header via http://$ip/)"
        OK=$((OK + 1))
    else
        log_error "FAIL $name (Host: $host_header via http://$ip/)"
        FAIL=$((FAIL + 1))
    fi
}

check_tcp() {
    local name="$1"
    local host="$2"
    local port="$3"
    if timeout 5 bash -c ">/dev/tcp/$host/$port" 2>/dev/null; then
        log_info "OK   $name ($host:$port)"
        OK=$((OK + 1))
    else
        log_error "FAIL $name ($host:$port)"
        FAIL=$((FAIL + 1))
    fi
}

check_disk() {
    local threshold=80
    local usage
    usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    if [ "$usage" -lt "$threshold" ]; then
        log_info "OK   Disk / (${usage}% belegt)"
        OK=$((OK + 1))
    else
        log_warn "FAIL Disk / (${usage}% belegt - ueber ${threshold}%)"
        FAIL=$((FAIL + 1))
    fi
}

check_pi_temp() {
    local warn_threshold=70
    local crit_threshold=80

    if ! command -v vcgencmd >/dev/null 2>&1; then
        log_warn "WARN Pi-Temperatur-Check uebersprungen (vcgencmd nicht verfuegbar)"
        return
    fi

    local raw
    raw=$(vcgencmd measure_temp 2>/dev/null || true)
    local temp
    temp=$(echo "$raw" | sed -n "s/.*temp=\([0-9.,]*\).*/\1/p" | tr ',' '.')
    if [[ -z "$temp" ]]; then
        temp=$(echo "$raw" | sed -n "s/.*=\([0-9.,]*\).*/\1/p" | tr ',' '.')
    fi

    if [[ -z "$temp" ]]; then
        if echo "$raw" | grep -qi "Can't open device file"; then
            log_warn "WARN Pi-Temperatur-Check uebersprungen (kein Zugriff auf /dev/vcio)"
            return
        fi
        log_warn "WARN Pi-Temperatur konnte nicht gelesen werden"
        FAIL=$((FAIL + 1))
        return
    fi

    local temp_int
    temp_int=$(printf '%.0f' "$temp")
    if (( temp_int >= crit_threshold )); then
        log_error "FAIL Pi-Temperatur (${temp}C - >= ${crit_threshold}C)"
        FAIL=$((FAIL + 1))
    elif (( temp_int >= warn_threshold )); then
        log_warn "WARN Pi-Temperatur (${temp}C - >= ${warn_threshold}C)"
        FAIL=$((FAIL + 1))
    else
        log_info "OK   Pi-Temperatur (${temp}C)"
        OK=$((OK + 1))
    fi
}

check_rag_index_freshness() {
    local index_path="/home/steges/infra/openclaw-data/rag/index.db"
    local max_age_hours=48

    if [[ ! -f "$index_path" ]]; then
        log_warn "WARN RAG Index Freshness uebersprungen (index.db nicht gefunden)"
        return
    fi

    local now_ts mtime_ts age_seconds age_hours
    now_ts=$(date +%s)
    mtime_ts=$(stat -c %Y "$index_path" 2>/dev/null || echo 0)
    if [[ "$mtime_ts" -le 0 ]]; then
        log_warn "WARN RAG Index Freshness konnte nicht gelesen werden"
        FAIL=$((FAIL + 1))
        return
    fi

    age_seconds=$((now_ts - mtime_ts))
    age_hours=$((age_seconds / 3600))

    if (( age_hours > max_age_hours )); then
        log_warn "FAIL RAG Index Freshness (${age_hours}h alt - > ${max_age_hours}h)"
        FAIL=$((FAIL + 1))
    else
        log_info "OK   RAG Index Freshness (${age_hours}h alt)"
        OK=$((OK + 1))
    fi
}

check_rag_reindex_state() {
    local status_path="/home/steges/infra/openclaw-data/rag/.reindex.status"

    if [[ ! -f "$status_path" ]]; then
        log_warn "WARN RAG Reindex State uebersprungen (.reindex.status nicht gefunden)"
        return
    fi

    local parsed
    parsed="$(python3 - "$status_path" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
except Exception:
    print('error||')
    raise SystemExit(0)

state = str(data.get('state', '')).strip().lower()
detail = str(data.get('detail', '')).strip()
ts = str(data.get('ts', '')).strip()
print(f'{state}|{detail}|{ts}')
PY
)"

    local state detail ts
    state="$(echo "$parsed" | cut -d'|' -f1)"
    detail="$(echo "$parsed" | cut -d'|' -f2)"
    ts="$(echo "$parsed" | cut -d'|' -f3)"

    case "$state" in
        success)
            log_info "OK   RAG Reindex State (success, ts=${ts:-unknown})"
            OK=$((OK + 1))
            ;;
        running)
            log_warn "WARN RAG Reindex State (running, detail=${detail:-none})"
            FAIL=$((FAIL + 1))
            ;;
        failed)
            log_error "FAIL RAG Reindex State (failed, detail=${detail:-none})"
            FAIL=$((FAIL + 1))
            ;;
        *)
            log_warn "WARN RAG Reindex State (unbekannt: ${state:-empty})"
            FAIL=$((FAIL + 1))
            ;;
    esac
}

check_rag_chunk_drift() {
    local index_path="/home/steges/infra/openclaw-data/rag/index.db"

    if [[ ! -f "$index_path" ]]; then
        log_warn "WARN RAG Chunk Drift uebersprungen (index.db nicht gefunden)"
        FAIL=$((FAIL + 1))
        return
    fi

    local counts
    counts="$(python3 - "$index_path" <<'PY'
import sqlite3, sys
path = sys.argv[1]
try:
    conn = sqlite3.connect(path)
    chunks = int(conn.execute('SELECT COUNT(*) FROM chunks').fetchone()[0])
    fts = int(conn.execute('SELECT COUNT(*) FROM chunks_fts').fetchone()[0])
    sources = int(conn.execute('SELECT COUNT(DISTINCT source) FROM chunks').fetchone()[0])
    conn.close()
    print(f'{chunks}|{fts}|{sources}')
except Exception:
    print('error|error|error')
PY
)"

    local chunks fts sources
    chunks="$(echo "$counts" | cut -d'|' -f1)"
    fts="$(echo "$counts" | cut -d'|' -f2)"
    sources="$(echo "$counts" | cut -d'|' -f3)"

    if [[ "$chunks" == "error" || "$fts" == "error" ]]; then
        log_error "FAIL RAG Chunk Drift (SQLite-Abfrage fehlgeschlagen)"
        FAIL=$((FAIL + 1))
        return
    fi

    local diff threshold
    diff=$(( chunks > fts ? chunks - fts : fts - chunks ))
    threshold=50
    local pct_threshold=$(( chunks / 50 )) # 2%
    if (( pct_threshold > threshold )); then
        threshold=$pct_threshold
    fi

    if (( chunks == 0 || fts == 0 )); then
        log_error "FAIL RAG Chunk Drift (chunks=${chunks}, fts=${fts})"
        FAIL=$((FAIL + 1))
    elif (( diff > threshold )); then
        log_error "FAIL RAG Chunk Drift (chunks=${chunks}, fts=${fts}, diff=${diff} > ${threshold})"
        FAIL=$((FAIL + 1))
    elif (( sources < 5 )); then
        log_warn "WARN RAG Chunk Drift (sehr wenige Quellen: ${sources})"
        FAIL=$((FAIL + 1))
    else
        log_info "OK   RAG Chunk Drift (chunks=${chunks}, fts=${fts}, sources=${sources})"
        OK=$((OK + 1))
    fi
}

check_rag_sanity_query() {
    local retrieve_script="/home/steges/agent/skills/openclaw-rag/scripts/retrieve.py"
    local goldset_path="/home/steges/agent/skills/openclaw-rag/GOLD-SET.json"

    if [[ ! -f "$retrieve_script" ]]; then
        log_warn "WARN RAG Sanity Query uebersprungen (retrieve.py nicht gefunden)"
        FAIL=$((FAIL + 1))
        return
    fi

    # Dynamische Frage aus GOLD-SET.json wählen
    local query="Welche Zielwerte gelten fuer die Growbox-Luftfeuchtigkeit?"  # Default
    if [[ -f "$goldset_path" ]]; then
        local random_query
        random_query="$(python3 - "$goldset_path" <<'PY'
import json, sys, random
path = sys.argv[1]
try:
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    questions = data.get('questions', [])
    if questions:
        q = random.choice(questions)
        print(q.get('query', ''))
except Exception:
    pass
PY
)"
        if [[ -n "$random_query" ]]; then
            query="$random_query"
        fi
    fi

    local result
    result="$(python3 "$retrieve_script" "$query" --limit 3 --timeout-ms 1500 2>/dev/null || true)"
    if [[ -z "$result" ]]; then
        log_error "FAIL RAG Sanity Query (keine Antwort)"
        FAIL=$((FAIL + 1))
        return
    fi

    local parsed
    parsed="$(python3 - <<'PY' "$result"
import json, sys
raw = sys.argv[1]
try:
    payload = json.loads(raw)
except Exception:
    print('error|error|error')
    raise SystemExit(0)

count = int(payload.get('count', 0))
mode = str(payload.get('search_mode', 'none'))
warning = str(payload.get('warning', ''))
print(f'{count}|{mode}|{warning}')
PY
)"

    local count mode warning
    count="$(echo "$parsed" | cut -d'|' -f1)"
    mode="$(echo "$parsed" | cut -d'|' -f2)"
    warning="$(echo "$parsed" | cut -d'|' -f3-)"

    if [[ "$count" == "error" ]]; then
        log_error "FAIL RAG Sanity Query (invalid JSON)"
        FAIL=$((FAIL + 1))
    elif (( count < 1 )); then
        log_error "FAIL RAG Sanity Query (keine Treffer)"
        FAIL=$((FAIL + 1))
    elif [[ "$mode" == "none" ]]; then
        log_warn "WARN RAG Sanity Query (search_mode=none, warning=${warning:-none})"
        FAIL=$((FAIL + 1))
    else
        log_info "OK   RAG Sanity Query (count=${count}, mode=${mode})"
        OK=$((OK + 1))
    fi
}

check_nvme_smart() {
    local device="/dev/nvme0n1"

    if ! command -v smartctl >/dev/null 2>&1; then
        log_warn "WARN NVMe SMART-Check uebersprungen (smartctl nicht verfuegbar)"
        return
    fi

    local output=""
    output="$(smartctl -H "$device" 2>&1 || true)"
    if command -v sudo >/dev/null 2>&1; then
        if [[ -z "$output" ]] || echo "$output" | grep -Eqi "permission denied|failed:"; then
            output="$(sudo -n smartctl -H "$device" 2>&1 || true)"
        fi
    fi

    if [[ -z "$output" ]]; then
        log_error "FAIL NVMe SMART-Status konnte nicht gelesen werden ($device)"
        FAIL=$((FAIL + 1))
        return
    fi

    if echo "$output" | grep -Eqi "PASSED"; then
        log_info "OK   NVMe SMART-Status (PASSED)"
        OK=$((OK + 1))
    else
        log_error "FAIL NVMe SMART-Status nicht PASSED"
        FAIL=$((FAIL + 1))
    fi
}

check_tailscale() {
    if ! command -v tailscale >/dev/null 2>&1; then
        log_warn "WARN Tailscale-Check uebersprungen (tailscale CLI nicht verfuegbar)"
        return
    fi

    local status
    status="$(tailscale status 2>&1 || true)"

    if echo "$status" | grep -q "Logged out"; then
        log_error "FAIL Tailscale (nicht eingeloggt)"
        FAIL=$((FAIL + 1))
    elif echo "$status" | grep -qE "^#.*;(direct|relay|idle)"; then
        log_info "OK   Tailscale (verbunden)"
        OK=$((OK + 1))

        # Connectivity-Test via tailnet ping (Peer, sonst eigene Tailnet-IP).
        local ping_target=""
        ping_target="$(tailscale status --json 2>/dev/null | python3 - <<'PY'
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)

peers = data.get("Peer", {}) or {}
for peer in peers.values():
    if peer.get("Online") and peer.get("TailscaleIPs"):
        ips = peer.get("TailscaleIPs")
        if ips:
            print(ips[0])
            raise SystemExit(0)

print("")
PY
)"

        if [[ -z "$ping_target" ]]; then
            ping_target="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
        fi

        if [[ -z "$ping_target" ]]; then
            log_warn "WARN Tailscale Connectivity-Test uebersprungen (kein Ping-Target)"
            return
        fi

        if timeout 5 tailscale ping -c 1 "$ping_target" >/dev/null 2>&1; then
            log_info "OK   Tailscale Connectivity (ping ${ping_target})"
            OK=$((OK + 1))
        else
            log_error "FAIL Tailscale Connectivity (ping ${ping_target})"
            FAIL=$((FAIL + 1))
        fi
    elif echo "$status" | grep -q "Tailscale is stopped"; then
        log_error "FAIL Tailscale (gestoppt)"
        FAIL=$((FAIL + 1))
    else
        log_warn "WARN Tailscale-Status unklar (keine Peers sichtbar)"
        FAIL=$((FAIL + 1))
    fi
}

check_mqtt_pubsub() {
    # Erweiterter MQTT-Test: Pub/Sub statt nur TCP-Port
    # Nutzt docker exec mosquitto weil mosquitto_pub/sub nicht lokal installiert

    local host="$PI_IP"
    local port=1883
    local test_topic="health-check/test-$(date +%s)"
    local test_msg="ping-$(date +%s)"

    # Prüfe ob Mosquitto Container läuft
    if ! docker ps --filter name=mosquitto --format "{{.Names}}" | grep -q "^mosquitto$"; then
        log_warn "WARN MQTT Pub/Sub - Mosquitto Container nicht erreichbar"
        FAIL=$((FAIL + 1))
        return
    fi

    # Versuche Pub/Sub Test via Docker
    # mosquitto_pub/sub sind im mosquitto Image vorhanden
    local sub_result=""
    local sub_tmp
    sub_tmp="$(mktemp)"

    # Starte Subscriber im Hintergrund (mit timeout) und speichere Ausgabe.
    docker exec mosquitto timeout 5 sh -c "mosquitto_sub -h localhost -p $port -t '$test_topic' -W 3" >"$sub_tmp" 2>/dev/null &
    local sub_pid=$!

    sleep 1  # Warte auf Subscriber

    # Publiziere Test-Message
    if docker exec mosquitto mosquitto_pub -h localhost -p $port -t "$test_topic" -m "$test_msg" -q 1 2>/dev/null; then
        wait $sub_pid 2>/dev/null || true
        sub_result="$(cat "$sub_tmp" 2>/dev/null || true)"

        if [[ "$sub_result" == "$test_msg" ]]; then
            log_info "OK   MQTT Pub/Sub (Roundtrip funktioniert)"
            OK=$((OK + 1))
        else
            log_warn "WARN MQTT Pub/Sub - Publish OK, aber Subscribe timeout (kann normal sein)"
            # Nicht FAIL - TCP-Check ist bereits erfolgreich
        fi
    else
        log_warn "WARN MQTT Pub/Sub - Publish fehlgeschlagen (MQTT braucht Auth?)"
        # Bei auth-fähigem MQTT ist Pub/Sub ohne Credentials erwarteterweise fehl
        # TCP-Check ist bereits erfolgreich, also kein FAIL
    fi

    # Cleanup Subscriber falls noch läuft
    kill $sub_pid 2>/dev/null || true
    rm -f "$sub_tmp"
}

check_http  "Pi-hole Web UI"    "http://$PI_IP:8080/admin"
check_http  "Home Assistant"    "http://$PI_IP:8123"
check_http  "ESPHome"           "http://$PI_IP:6052"
check_http  "Portainer"         "http://$PI_IP:9000"
check_http  "OpenClaw"          "http://$PI_IP:18789"
check_http  "RAG Embed API"     "http://$PI_IP:18790/health"
check_http  "ops-ui (Canvas)"   "http://$PI_IP:8090"
check_http_host "Caddy Reverse Proxy (openclaw.lan)" "$PI_IP" "openclaw.lan"
check_tcp   "Mosquitto MQTT"    "$PI_IP" 1883
check_mqtt_pubsub
check_http  "Loki"              "http://$PI_IP:3100/ready"
check_http  "Alertmanager"      "http://$PI_IP:9093/-/healthy"
check_http  "Vaultwarden"       "http://$PI_IP:8888/alive"
check_http  "Ntfy"              "http://$PI_IP:8900/v1/health"
check_http  "Scrutiny"          "http://$PI_IP:8891/api/health"
check_http  "Authelia"          "http://$PI_IP:9091/api/health"
check_disk
check_pi_temp
check_nvme_smart
check_tailscale
check_influx_query
check_rag_index_freshness
check_rag_reindex_state
check_rag_chunk_drift
check_rag_sanity_query

echo ""
echo "Result: $OK OK, $FAIL FAIL"
# Exit-Code: 0 = alles OK, 1 = mindestens ein Fehler
[ $FAIL -eq 0 ] && exit 0 || exit 1
