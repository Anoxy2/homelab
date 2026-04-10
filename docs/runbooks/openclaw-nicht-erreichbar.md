# Runbook: OpenClaw nicht erreichbar

## Symptome
- Gateway unter `http://192.168.2.101:18789` antwortet nicht.
- Chat/Automation ueber OpenClaw faellt aus.

## Check
```bash
curl -sf http://192.168.2.101:18789
```

## Diagnose
```bash
cd /home/steges

docker compose logs openclaw --tail 50

docker compose ps openclaw
```

## Recovery
```bash
cd /home/steges

docker compose restart openclaw

./scripts/health-check.sh
```

## Wichtiger Hinweis zu OPENCLAW_NO_RESPAWN
`OPENCLAW_NO_RESPAWN=1` ist absichtlich gesetzt.
- Ohne diese Variable erkennt OpenClaw Docker nicht als Supervisor.
- Bei Reload kann ein detached Child-Prozess entstehen (Port-Konflikt auf 18789).
- Mit der Variable uebernimmt Docker (`restart: unless-stopped`) die Lifecycle-Kontrolle.

## Abschluss
- Nach erfolgreichem Restart kurz API-Health pruefen.
- Ursache (z. B. OOM, Netzwerk, Token) im Handover dokumentieren.
