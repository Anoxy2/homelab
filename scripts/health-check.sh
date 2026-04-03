#!/bin/bash
# Prüft ob alle Services erreichbar sind

PI_IP="192.168.2.101"
OK=0
FAIL=0

check() {
    local name="$1"
    local url="$2"
    if curl -sf --max-time 5 "$url" > /dev/null 2>&1; then
        echo "[OK]   $name ($url)"
        ((OK++))
    else
        echo "[FAIL] $name ($url)"
        ((FAIL++))
    fi
}

check "Pi-hole Web UI"    "http://$PI_IP:8080/admin"
check "Home Assistant"    "http://$PI_IP:8123"
check "Portainer"         "http://$PI_IP:9000"

echo ""
echo "Result: $OK OK, $FAIL FAIL"
[ $FAIL -eq 0 ] && exit 0 || exit 1
