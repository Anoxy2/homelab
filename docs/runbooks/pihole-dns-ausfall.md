# Runbook: Pi-hole DNS ausgefallen

## Symptome
- Webseiten laden im LAN nicht mehr oder nur sporadisch.
- DNS-Aufloesung auf Clients schlaegt fehl.

## Sofortmassnahme
1. Speedport Admin-Oberflaeche oeffnen.
2. DHCP am Router temporaer wieder aktivieren, damit Clients einen funktionierenden DNS erhalten.

## Diagnose
```bash
cd /home/steges

docker compose logs pihole --tail 50

docker compose ps pihole
```

## Recovery
```bash
cd /home/steges

docker compose restart pihole

./scripts/health-check.sh
```

## Fallback pro Endgeraet
- DNS manuell auf `8.8.8.8` setzen, bis Pi-hole wieder stabil ist.

## Abschluss
- Router-DHCP wieder deaktivieren, sobald Pi-hole DHCP/DNS stabil laeuft.
- Vorfall kurz in Changelog/Handover vermerken.
