# Uptime Kuma Setup (Core Services + Telegram)

## Ziel

In Uptime Kuma alle Core-Services als Monitore hinterlegen und Telegram-Alerting aktivieren.

## Service-Monitorliste

Diese Monitore als `HTTP(s)` Typ anlegen:

1. OpenClaw: `http://192.168.2.101:18789`
2. Home Assistant: `http://192.168.2.101:8123`
3. Pi-hole: `http://192.168.2.101:8080/admin`
4. Mosquitto WebSocket: `http://192.168.2.101:9001`
5. Ops-UI: `http://192.168.2.101:8090`
6. Portainer: `http://192.168.2.101:9000`

Empfehlung:
- Interval: 30s
- Retries: 3
- Timeout: 10s

## Telegram Notification

1. Uptime Kuma oeffnen: `http://uptime.lan`
2. `Settings -> Notifications -> Setup Notification`
3. Typ: `Telegram`
4. Bot Token: denselben Token wie OpenClaw (`TELEGRAM_BOT_TOKEN`)
5. Chat ID: dieselbe Ziel-Chat-ID wie OpenClaw Heartbeat
6. `Test` ausfuehren und speichern
7. Notification allen Core-Monitoren zuweisen

## Validierung

- Einen Monitor absichtlich auf falsche URL setzen und Alarm ausloesen
- Telegram-Nachricht pruefen
- URL korrigieren und Recovery-Nachricht pruefen
