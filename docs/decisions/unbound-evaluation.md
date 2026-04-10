# Unbound Evaluation (Pi 5, arm64)

Datum: 06.04.2026

## Ergebnis
Unbound laeuft produktiv auf dem Pi als lokaler rekursiver Resolver; Pi-hole nutzt jetzt `127.0.0.1#5335` als einzigen Upstream.

## Image- und Laufzeitpruefung
- `mvance/unbound:latest`: nicht arm64-tauglich (historischer Befund vom 05.04.2026).
- `ghcr.io/klutchell/unbound:latest`: arm64-Manifest vorhanden.
- `crazymax/unbound:latest`: arm64-Manifest vorhanden, lauffaehig und fuer Compose-Einsatz verwendet.

## Implementierter Zielzustand
- Neuer Compose-Service `unbound` (host-network).
- Persistente Config unter `~/unbound/config/pilab.conf`.
- Listener: `0.0.0.0@5335`.
- Pi-hole Upstream in `~/pihole/config/pihole.toml` auf `127.0.0.1#5335` gesetzt.

## Verifikation
- Container-Health: `unbound=healthy`, `pihole=healthy`.
- DNS-Funktion:
  - `dig @127.0.0.1 -p 5335 example.com` liefert Antwort.
  - `dig @127.0.0.1 -p 53 example.com` liefert ebenfalls Antwort (ueber Pi-hole mit Unbound-Upstream).

## Latenzvergleich (variiertes 12-Domain-Set)
- Vorher (Pi-hole -> externer Upstream): `avg ~15 ms`, `p95 ~16 ms`.
- Nachher (Pi-hole -> Unbound lokal): `avg ~21.11 ms`, `p95 ~22.97 ms`.

## Einordnung
Der Rekursionspfad ist erwartungsgemaess etwas langsamer als direkter externer Upstream, bietet dafuer aber mehr Resolver-Souveraenitaet und lokale Kontrolle. Der aktuelle Latenzbereich ist fuer LAN-Betrieb weiterhin unkritisch.
