# SearxNG Web Search

> Selbstgehostete, privacy-fokussierte Metasuchmaschine
> Kein Tracking, keine Werbung, aggregiert mehrere Quellen

---

## Überblick

**SearxNG** ist die private Alternative zu Google – aggregiert Suchergebnisse ohne Tracking.

| Attribut | Wert |
|----------|------|
| **Image** | `searxng/searxng:latest` (Digest gepinnt) |
| **Container** | searxng |
| **Port** | `192.168.2.101:8085` → Container `8080` |
| **LAN URL** | `http://search.lan` |
| **Config** | `./searxng/config/settings.yml` |

---

## Architektur

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   User      │────→│   SearxNG   │────→│  Google,    │
│  (Browser)  │     │   :8085     │     │  DDG,       │
└─────────────┘     └─────────────┘     │  Bing...    │
        │                               └─────────────┘
        │
        ↓
┌─────────────┐
│  OpenClaw   │ ←── Für Web-Search-Features
│  (API)      │
└─────────────┘
```

---

## Konfiguration

### Docker Compose

```yaml
services:
  searxng:
    image: searxng/searxng@sha256:6a89a150d0163877caab1982b7a20d0a03fd4b39401a0d3f26f61ad205949442
    container_name: searxng
    ports:
      - "192.168.2.101:8085:8080"
    volumes:
      - ./searxng/config:/etc/searxng:rw
    environment:
      SEARXNG_BASE_URL: "http://search.lan/"
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - SETGID
      - SETUID
      - DAC_OVERRIDE
```

### settings.yml

```yaml
# searxng/config/settings.yml

general:
  debug: false
  instance_name: "PiLab Search"
  contact_url: false
  enable_metrics: false

search:
  safe_search: 0  # 0=off, 1=moderate, 2=strict
  autocomplete: duckduckgo
  default_lang: de
  formats:
    - html
    - json  # Für API-Zugriff

server:
  port: 8080
  bind_address: "0.0.0.0"
  secret_key: "your-secret-key-here-change-this"  # Ändern!
  limiter: false
  public_instance: false
  base_url: "http://search.lan/"

# Search Engines
engines:
  # Allgemein
  - name: google
    engine: google
    shortcut: go
    enabled: true
    
  - name: duckduckgo
    engine: duckduckgo
    shortcut: ddg
    enabled: true
    
  - name: bing
    engine: bing
    shortcut: bi
    enabled: true
    
  # Wikipedia
  - name: wikipedia
    engine: wikipedia
    shortcut: wp
    enabled: true
    
  # Technisch
  - name: github
    engine: github
    shortcut: gh
    enabled: true
    
  - name: stackoverflow
    engine: stackoverflow
    shortcut: so
    enabled: true
    
  # News
  - name: bing_news
    engine: bing_news
    shortcut: bin
    enabled: true
    
  # Images
  - name: google_images
    engine: google_images
    shortcut: img
    enabled: true
    
  # Deaktivierte Engines (zu langsam oder unzuverlässig)
  - name: yahoo
    engine: yahoo
    enabled: false
    
  - name: yandex
    engine: yandex
    enabled: false

# UI
ui:
  static_path: ""
  templates_path: ""
  default_theme: simple
  default_locale: de
  theme_args:
    simple_style: auto  # auto, light, dark

# Plugins
plugins:
  - hash_plugin
  - self_info
  - tracker_url_remover
  - vim_hotkeys
```

### Caddyfile

```caddyfile
search.lan {
    reverse_proxy 192.168.2.101:8085
}
```

---

## Verwendung

### Browser-Setup

**Als Standard-Suchmaschine:**

```
URL: http://search.lan/search?q=%s
```

**Firefox:**
1. `about:preferences#search`
2. "Add search bar in toolbar"
3. `http://search.lan` besuchen
4. Suchfeld rechtsklick → "Add a Keyword for this Search"
5. Keyword: `s`

**Chrome:**
1. Einstellungen → Suchmaschine → Verwalten
2. Hinzufügen:
   - Name: PiLab Search
   - Keyword: s
   - URL: `http://search.lan/search?q=%s`

### Bang-Syntax (Shortcuts)

| Bang | Engine |
|------|--------|
| `!go` | Google |
| `!ddg` | DuckDuckGo |
| `!wp` | Wikipedia |
| `!gh` | GitHub |
| `!so` | StackOverflow |
| `!img` | Google Images |
| `!bin` | Bing News |

**Beispiel:**
```
!gh docker compose volumes
```

---

## API-Zugriff (für OpenClaw)

```bash
# JSON-Suche
curl "http://search.lan/search?q=docker+compose&format=json" \
  -H "Accept: application/json"

# Mit Python
import requests

response = requests.get(
    "http://192.168.2.101:8085/search",
    params={"q": "prometheus metrics", "format": "json"}
)
results = response.json()

for result in results['results'][:5]:
    print(f"{result['title']}: {result['url']}")
```

---

## OpenClaw Integration

```yaml
# In OpenClaw-Config
web_search:
  enabled: true
  endpoint: "http://searxng:8080"
  timeout: 30
  max_results: 5
```

**Features:**
- Web-Search für aktuelle Informationen
- Dokumentationen nachschlagen
- Troubleshooting-Suchanfragen

---

## Troubleshooting

### "No results found"

```bash
# Logs prüfen
docker logs searxng --tail 50

# Engine-Status
curl "http://search.lan/stats/errors" | jq .

# Ratelimit?
docker exec searxng sh -c "cat /var/log/uwsgi/app/searxng.log"
```

### Langsame Antworten

```yaml
# settings.yml - Timeouts reduzieren
search:
  request_timeout: 5.0  # Default: 3.0
  max_request_timeout: 15.0
  
# Weniger Engines parallel
  max_requests: 4  # Default: 8
```

### "Invalid secret key"

```bash
# Secret generieren
openssl rand -hex 32

# In settings.yml einfügen
server:
  secret_key: "generated-key-here"
```

### Container startet nicht

```bash
# Berechtigungen
docker exec searxng ls -la /etc/searxng/

# Config validieren
docker exec searxng searxng-check
```

---

## Privacy-Features

| Feature | Beschreibung |
|---------|--------------|
| **No Cookies** | Keine Tracking-Cookies |
| **No IP Logging** | IPs werden nicht gespeichert |
| **Tor Support** | Kann über Tor laufen |
| **POST Requests** | Suchbegriffe nicht in URL |
| **HTTPS** | Verschlüsselte Verbindung (via Tailscale/HTTPS) |

---

## Backup

```bash
# Config ist wichtig
./searxng/config/ → /mnt/usb-backup/backups/YYYYMMDD/searxng/

# Oder Git
git add searxng/config/
```

---

## Changelog

| Datum | Änderung |
|-------|----------|
| 2026-04-10 | Dokumentation erstellt |
