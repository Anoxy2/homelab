#!/bin/bash
set -euo pipefail

VULN_LOG="/home/steges/docs/monitoring/vuln-log.md"
TELEGRAM_API="https://api.telegram.org"

usage() {
  echo "Usage: $0 --weekly [--dry-run] [--json] | --summary | --json"
}

send_telegram() {
  local text="$1"
  local token="${TELEGRAM_BOT_TOKEN:-}"
  local chat_id="${TELEGRAM_CHAT_ID:-${OPENCLAW_TELEGRAM_CHAT_ID:-}}"
  [[ -n "$token" && -n "$chat_id" ]] || return 0
  curl -fsS --max-time 10 \
    "$TELEGRAM_API/bot${token}/sendMessage" \
    -d "chat_id=${chat_id}" \
    -d "disable_web_page_preview=true" \
    --data-urlencode "text=${text}" >/dev/null 2>&1 || true
}

ensure_vuln_log() {
  if [[ ! -f "$VULN_LOG" ]]; then
    cat > "$VULN_LOG" << 'HEADER'
# Vuln-Watch Log

Automatisch befüllt durch den `vuln-watch`-Skill.
Quellen: GitHub Issues/PRs zu Prompt Injection, Jailbreak, LLM-CVEs.

| Datum | Titel | URL | Typ |
|---|---|---|---|
HEADER
  fi
}

count_known_urls() {
  [[ -f "$VULN_LOG" ]] || { echo 0; return; }
  grep -c "https://github.com" "$VULN_LOG" 2>/dev/null || echo 0
}

run_weekly() {
  local dry_run="${1:-0}"
  local json_mode="${2:-0}"

  ensure_vuln_log

  local since
  since="$(python3 -c "
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc) - timedelta(days=7)).strftime('%Y-%m-%dT%H:%M:%SZ'))
")"

  local today
  today="$(date -u +%Y-%m-%d)"

  # Bekannte URLs aus Log lesen
  local known_urls
  known_urls="$(grep -oE 'https://github\.com/[^|[:space:]]+' "$VULN_LOG" 2>/dev/null | sort -u || true)"

  local search_terms=(
    "prompt+injection"
    "jailbreak+LLM"
    "LLM+vulnerability"
    "AI+security+CVE"
    "openclaw+security"
  )

  local tmp_results
  tmp_results="$(mktemp)"
  : > "$tmp_results"

  local search_error=0
  for term in "${search_terms[@]}"; do
    local tmp_resp
    tmp_resp="$(mktemp)"
    if curl -fsS --max-time 15 \
        -H "Accept: application/vnd.github.v3+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/search/issues?q=${term}+created:>${since}&sort=created&order=desc&per_page=10" \
        -o "$tmp_resp" 2>/dev/null; then
      python3 - "$tmp_resp" "${term//+/ }" >> "$tmp_results" <<'PY'
import json, sys
path, term = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        data = json.load(f)
    for item in data.get('items', []):
        url = item.get('html_url', '')
        title = item.get('title', '').replace('|', '-').strip()[:100]
        created = item.get('created_at', '')[:10]
        if url and 'github.com' in url:
            print(f"{created}\t{title}\t{url}\t{term}")
except Exception as e:
    sys.stderr.write(f"Parse error: {e}\n")
PY
    else
      search_error=1
    fi
    rm -f "$tmp_resp"
    # Rate-limit: 10 req/min unauthenticated
    sleep 7
  done

  # Dedup: neue URLs vs. bekannte
  local new_entries=()
  while IFS=$'\t' read -r date title url typ; do
    [[ -z "$url" ]] && continue
    if ! echo "$known_urls" | grep -qF "$url"; then
      new_entries+=("${date}|${title}|${url}|${typ}")
    fi
  done < "$tmp_results"
  rm -f "$tmp_results"

  local new_count="${#new_entries[@]}"
  local total_known
  total_known="$(count_known_urls)"

  if [[ "$dry_run" -eq 1 ]]; then
    if [[ "$json_mode" -eq 1 ]]; then
      echo "{\"new_count\":${new_count},\"total_known\":${total_known},\"status\":\"dry-run\"}"
    else
      echo "Dry-run: ${new_count} neue Funde (würden in vuln-log.md geschrieben)"
      for entry in "${new_entries[@]:-}"; do
        [[ -z "$entry" ]] && continue
        IFS='|' read -r d t u ty <<< "$entry"
        echo "  [${ty}] ${t}"
        echo "         ${u}"
      done
    fi
    return 0
  fi

  # Neue Einträge in vuln-log.md schreiben
  if [[ $new_count -gt 0 ]]; then
    for entry in "${new_entries[@]}"; do
      IFS='|' read -r d t u ty <<< "$entry"
      printf '| %s | %s | %s | %s |\n' "$d" "$t" "$u" "$ty" >> "$VULN_LOG"
    done
  fi

  total_known="$(count_known_urls)"

  # Telegram senden (Top 5)
  if [[ $new_count -gt 0 ]]; then
    local msg="🔐 Vuln-Watch — ${today}"$'\n'"${new_count} neue AI-Security-Funde:"$'\n'
    local i=0
    for entry in "${new_entries[@]}"; do
      [[ $i -ge 5 ]] && break
      IFS='|' read -r d t u ty <<< "$entry"
      msg+=$'\n'"$((i+1)). ${t} — ${ty}"$'\n'"   ${u}"
      i=$(( i + 1 ))
    done
    [[ $new_count -gt 5 ]] && msg+=$'\n\n'"[+$((new_count-5)) weitere in ~/docs/monitoring/vuln-log.md]"
    send_telegram "$msg"
  fi

  if [[ "$json_mode" -eq 1 ]]; then
    local status="ok"
    [[ $search_error -eq 1 ]] && status="error"
    echo "{\"new_count\":${new_count},\"total_known\":${total_known},\"status\":\"${status}\"}"
  else
    echo "vuln-watch: ${new_count} neue Funde, ${total_known} gesamt bekannt"
  fi
}

run_summary() {
  local json_mode="${1:-0}"
  ensure_vuln_log
  local total
  total="$(count_known_urls)"
  if [[ "$json_mode" -eq 1 ]]; then
    echo "{\"new_count\":0,\"total_known\":${total},\"status\":\"ok\"}"
  else
    echo "vuln-log.md: ${total} bekannte Einträge"
    echo ""
    echo "Letzte 10 Funde:"
    grep "https://github.com" "$VULN_LOG" 2>/dev/null | tail -10 | \
      awk -F'|' '{printf "  [%s] %s\n         %s\n", $2, $3, $4}'
  fi
}

# Dotenv laden (Telegram-Credentials)
if [[ -f "/home/steges/scripts/lib/env.sh" ]]; then
  # shellcheck source=/dev/null
  source "/home/steges/scripts/lib/env.sh"
  load_dotenv 2>/dev/null || true
fi

dry_run=0
json_mode=0
cmd=""

for arg in "$@"; do
  case "$arg" in
    --weekly)   cmd="weekly" ;;
    --summary)  cmd="summary" ;;
    --dry-run)  dry_run=1 ;;
    --json)     json_mode=1 ;;
    --help|-h)  usage; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; usage; exit 1 ;;
  esac
done

case "${cmd:-}" in
  weekly)   run_weekly "$dry_run" "$json_mode" ;;
  summary)  run_summary "$json_mode" ;;
  "")
    if [[ "$json_mode" -eq 1 ]]; then
      run_summary "1"
    else
      usage
      exit 1
    fi
    ;;
esac
