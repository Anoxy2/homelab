#!/usr/bin/env bash
# claw-send.sh — Claude→OpenClaw Kollaborationskanal (HANDSHAKE-Format)
#
# Sendet einen strukturierten HANDSHAKE-Request an den OpenClaw-Agenten
# über die dedizierte Session "claude-ops" — getrennt von Telegram/User-Chats.
#
# Pflichtfelder: --intent, --target
#
# Usage:
#   claw-send.sh --intent inspect --target "docker services"
#   claw-send.sh --intent inspect --target "growbox" --priority p0 \
#                --allowed "HA state lesen" --context "Temp über Schwelle"
#   claw-send.sh --intent report --target "service ports" --raw
#
# Intents: inspect | change | report | promote | rollback | classify
# Priorities: p0 (kritisch) | p1 | p2 | p3 (niedrig)
#
# --raw gibt den vollständigen JSON-Output aus statt nur den Reply-Text.
# --timeout und --session-id erlauben feinere Steuerung pro Aufruf.

set -euo pipefail

AGENT_ID="main"
SESSION_ID="claude-ops"   # dedizierte Session, getrennt von User/Telegram-Chats
TIMEOUT=120
RETRY_ON_GATEWAY_CLOSE=1

INTENT=""
PRIORITY="p2"
SCOPE=""
TARGET=""
ALLOWED=""
FORBIDDEN=""
SUCCESS="Aufgabe abgeschlossen, Ergebnis gemeldet"
ESCALATION="claude"
CONTEXT_TEXT=""
NOTES_TEXT=""
RAW=0

usage() {
  echo "Usage: $0 --intent <intent> --target <target> [options]"
  echo ""
  echo "Pflichtfelder:"
  echo "  --intent, -i   inspect|change|report|promote|rollback|classify"
  echo "  --target, -t   Primäres Zielobjekt (z.B. 'sensor.growbox_temp')"
  echo ""
  echo "Optional:"
  echo "  --priority, -p  p0|p1|p2|p3 (default: p2)"
  echo "  --scope         service|skill|doc|growbox|infra"
  echo "  --allowed, -a   Erlaubte Aktionen (Freitext)"
  echo "  --forbidden, -f Verbotene Aktionen"
  echo "  --success, -s   Erfolgskriterium"
  echo "  --escalation    claude|steges (default: claude)"
  echo "  --context, -c   Kontextinformationen (## Context Block)"
  echo "  --notes, -n     Optionale Hinweise (## Notes Block)"
  echo "  --timeout       Timeout in Sekunden fuer openclaw agent (default: 120)"
  echo "  --session-id    Session-ID (default: claude-ops)"
  echo "  --raw           Vollständiger JSON-Output statt Reply-Text"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --intent|-i)      INTENT="$2"; shift 2 ;;
    --priority|-p)    PRIORITY="$2"; shift 2 ;;
    --scope)          SCOPE="$2"; shift 2 ;;
    --target|-t)      TARGET="$2"; shift 2 ;;
    --allowed|-a)     ALLOWED="$2"; shift 2 ;;
    --forbidden|-f)   FORBIDDEN="$2"; shift 2 ;;
    --success|-s)     SUCCESS="$2"; shift 2 ;;
    --escalation|-e)  ESCALATION="$2"; shift 2 ;;
    --context|-c)     CONTEXT_TEXT="$2"; shift 2 ;;
    --notes|-n)       NOTES_TEXT="$2"; shift 2 ;;
    --timeout)        TIMEOUT="$2"; shift 2 ;;
    --session-id)     SESSION_ID="$2"; shift 2 ;;
    --raw)            RAW=1; shift ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "Unbekannte Option: $1" >&2; usage ;;
  esac
done

if [[ -z "$INTENT" ]] || [[ -z "$TARGET" ]]; then
  echo "ERROR: --intent und --target sind Pflichtfelder" >&2
  echo "" >&2
  usage
fi

if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --timeout muss eine ganze Zahl (Sekunden) sein" >&2
  exit 1
fi

if [[ -z "$SESSION_ID" ]]; then
  echo "ERROR: --session-id darf nicht leer sein" >&2
  exit 1
fi

# Request-ID generieren (Format: req-YYYYMMDD-HHMMSS-slug)
SLUG=$(echo "$TARGET" | tr -cs '[:alnum:]' '-' | sed 's/-*$//' | cut -c1-20)
REQ_ID="req-$(date +%Y%m%d-%H%M%S)-${SLUG}"

# HANDSHAKE Request Block zusammenbauen
REQUEST="## Request
- id: ${REQ_ID}
- sender: claude
- intent: ${INTENT}
- priority: ${PRIORITY}"

[[ -n "$SCOPE" ]]     && REQUEST+="
- scope: ${SCOPE}"

REQUEST+="
- target: ${TARGET}
- allowed_actions: ${ALLOWED:-lesen, prüfen, berichten}"

[[ -n "$FORBIDDEN" ]] && REQUEST+="
- forbidden_actions: ${FORBIDDEN}"

REQUEST+="
- success_criteria: ${SUCCESS}
- escalation_contact: ${ESCALATION}"

if [[ -n "$CONTEXT_TEXT" ]]; then
  REQUEST+="

## Context
${CONTEXT_TEXT}"
fi

if [[ -n "$NOTES_TEXT" ]]; then
  REQUEST+="

## Notes
${NOTES_TEXT}"
fi

# An OpenClaw senden (dedizierte Session; mit Retry bei transientem Gateway-Close)
send_once() {
  docker exec openclaw openclaw agent \
    --agent "$AGENT_ID" \
    --session-id "$SESSION_ID" \
    --message "$REQUEST" \
    --timeout "$TIMEOUT" \
    --json
}

set +e
RESULT="$(send_once 2>&1)"
RC=$?
set -e

if [[ "$RC" -ne 0 ]] && [[ "$RETRY_ON_GATEWAY_CLOSE" -eq 1 ]]; then
  if echo "$RESULT" | grep -Eqi 'gateway closed|abnormal closure|no close frame'; then
    set +e
    RESULT="$(send_once 2>&1)"
    RC=$?
    set -e
  fi
fi

if [[ "$RC" -ne 0 ]]; then
  echo "$RESULT" >&2
  exit "$RC"
fi

if [[ "$RAW" -eq 1 ]]; then
  echo "$RESULT"
  exit 0
fi

# Reply-Text extrahieren und ausgeben
echo "$RESULT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    payloads = d.get('result', {}).get('payloads', [])
    if payloads:
        print(payloads[0].get('text', ''))
    else:
        status = d.get('status', 'unknown')
        summary = d.get('summary', '')
        print(f'[{status}: {summary}]')
except Exception as e:
    print(f'(parse error: {e})', file=sys.stderr)
    sys.exit(1)
"
