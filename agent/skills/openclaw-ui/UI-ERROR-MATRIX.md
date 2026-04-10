# UI Error Matrix

## Bridge Layer
1. Error: Bridge helper missing
- Signal: `window.openclawSendUserAction` unavailable
- User message: "Bridge nicht verfuegbar auf diesem Device"
- Recovery: fallback hint + reconnect instructions

2. Error: Action timeout
- Signal: no status event in timeout window
- User message: "Aktion hat Zeitlimit erreicht"
- Recovery: retry with exponential backoff

## API Layer
3. Error: Home Assistant unreachable
- Signal: fetch/network failure
- User message: "Home Assistant derzeit nicht erreichbar"
- Recovery: show degraded mode and health panel details

4. Error: Unauthorized response
- Signal: HTTP 401/403
- User message: "Authentifizierung fehlgeschlagen"
- Recovery: operator runbook reference only (no token details)

## Data Layer
5. Error: Invalid payload
- Signal: schema mismatch / parse failure
- User message: "Unerwartete Datenstruktur"
- Recovery: ignore bad payload, keep last known good state

## Runtime Policy
- Retry only idempotent actions.
- Avoid infinite retries.
- Persist last good status for degraded view.
