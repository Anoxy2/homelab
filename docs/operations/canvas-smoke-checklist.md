# Canvas Smoke Checklist

Ziel: Schneller Release-Sanity-Check fuer das Ops-UI/Canvas, bevor Aenderungen als stabil gelten.

## Vorbereitung

- Browser-Cache leeren oder privaten Tab verwenden.
- Canvas oeffnen: `http://192.168.2.101:8090` oder `http://canvas.lan`.
- Optional: Caddy-Route mit Host-Header pruefen.

## Pflicht-Checks

1. Navigation
- Seitenwechsel ueber die Top-Navigation funktioniert.
- Neue Tabs `Operations`, `Decisions` und `Runbooks` oeffnen ohne JS-Fehler.
- Keyboard-Shortcuts funktionieren: `1-5` (Core-Seiten), `r` (Health Refresh), `Esc` (Dialog/Fokus schliessen).

2. Health-Chips
- Health-Ansicht laedt ohne JS-Fehler.
- Refresh aktualisiert Status sichtbar.

3. MQTT Connect
- Settings speichern MQTT Host/Port/Username/Password in localStorage.
- Connect-Versuch wird ausgeloeest und zeigt Erfolg/Fehler klar an.

4. Chat Send
- Chat-Panel akzeptiert Eingabe.
- Sendeaktion wird ausgefuehrt; UI bleibt responsiv.

5. PWA Basis
- `manifest.json` wird geladen.
- `sw.js` wird registriert (keine Fehler in Console).
- `ops-brief.latest.json` laedt frisch nach einem manuellen Refresh in den neuen Doc-Tabs.

## Automatisierter Smoke-Run

Der automatisierte Lauf erzeugt gleichzeitig Smoke-Ergebnis und Visual-Baselines:

```bash
~/scripts/canvas-playwright-smoke.sh
```

Artefakte landen unter:
- `docs/visual-baselines/canvas/YYYY-MM-DD/ops-dashboard.png`
- `docs/visual-baselines/canvas/YYYY-MM-DD/chat-page.png`
- `docs/visual-baselines/canvas/YYYY-MM-DD/mqtt-page.png`
- `docs/visual-baselines/canvas/YYYY-MM-DD/smoke-result.json`

## Ergebnis-Template

```text
Datum:
Build/Commit:
Tester:

Navigation: OK/FAIL
Operations/Decisions/Runbooks: OK/FAIL
Scout/Health/Metrics: OK/FAIL
Health-Chips: OK/FAIL
MQTT Connect: OK/FAIL
Chat Send: OK/FAIL
PWA: OK/FAIL

Bemerkungen:
```

## UI-Metriken (Definition)

- Action-Success-Rate: `erfolgreiche Aktionen / alle Aktionen * 100`.
	Aktionen: Navigation, Health-Refresh, MQTT-Connect-Versuch, Chat-Senden.
- Fehlerquote: `fehlgeschlagene Aktionen / alle Aktionen * 100`.

Auswertung:
- Werte pro Smoke-Run protokollieren und als Wochenmittel beobachten.
- Zielwert initial: Success-Rate >= 95%, Fehlerquote <= 5%.
