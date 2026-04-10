# OpenClaw – Integrationen

> Übersicht aller verfügbaren Integrationen und Plugins  
> Stand: April 2026 · Quelle: [openclaw.ai/integrations](https://openclaw.ai/integrations)

---

## Überblick

OpenClaw unterstützt **50+ Integrationen** über Chat-Apps, Entwicklungs-Tools, Cloud-Services und IoT-Geräte.

→ [Vollständige Integrations-Liste](https://openclaw.ai/integrations)

---

## Chat & Kommunikation

| Integration | Beschreibung | Features |
|-------------|--------------|----------|
| **Telegram** | Primärer Chat-Kanal | DMs, Gruppen, Custom Commands |
| **WhatsApp** | Mobile Kommunikation | Vollständige Unterstützung |
| **Discord** | Community & Gaming | Server-Integration |
| **Slack** | Workplace Chat | Team-Kommunikation |
| **Signal** | Privacy-Fokus | Ende-zu-Ende verschlüsselt |
| **iMessage** | Apple-Ökosystem | Native iOS/Mac Integration |

---

## LLM-Provider

| Provider | Models | Konfiguration |
|----------|--------|---------------|
| **Anthropic** | Claude 3.5/4 Sonnet, Opus | API-Key |
| **OpenAI** | GPT-4, GPT-4o, GPT-4.1 | API-Key |
| **GitHub Copilot** | GPT-4.1 | Copilot-Proxy |
| **Groq** | Llama 3, Mixtral | API-Key |
| **Local Models** | Ollama, LM Studio | Local Endpoint |

---

## Development & Coding

| Integration | Zweck |
|-------------|-------|
| **Claude Code CLI** | `@anthropic-ai/claude-code` Integration |
| **GitHub** | Repositories, Issues, PRs |
| **GitLab** | CI/CD, Repository-Management |
| **VS Code** | Extension-Support |
| **Cursor** | AI-Coding-Editor |
| **Codex** | OpenAI Coding-Agent |

---

## Cloud & Hosting

| Integration | Anwendung |
|-------------|-----------|
| **Hetzner** | Server-Management |
| **AWS** | Cloud-Ressourcen |
| **Google Cloud** | API-Key-Management |
| **Cloudflare** | Tunnel, DNS |
| **Vercel** | Deployment |
| **Netlify** | Static Hosting |

---

## Produktivität & Tools

| Integration | Funktion |
|-------------|----------|
| **Gmail** | E-Mail-Verwaltung |
| **Google Calendar** | Terminplanung |
| **Obsidian** | Knowledge Base |
| **Notion** | Dokumentation |
| **Todoist** | Task-Management |
| **Trello** | Projekt-Management |
| **Linear** | Issue-Tracking |
| **Jira** | Enterprise-Tracking |

---

## Datenbanken & Storage

| Integration | Typ |
|-------------|-----|
| **PostgreSQL** | SQL-Datenbank |
| **SQLite** | Lokale Datenbank |
| **Redis** | Cache & Queue |
| **MongoDB** | NoSQL-Dokumente |
| **Supabase** | Firebase-Alternative |

---

## Speech & Audio

| Integration | Funktion |
|-------------|----------|
| **Deepgram** | Speech-to-Text |
| **ElevenLabs** | High-Quality TTS |
| **Whisper** | Lokale Transkription |

---

## Health & Wearables

| Integration | Daten |
|-------------|-------|
| **WHOOP** | Fitness & Recovery |
| **Apple Health** | iOS Health-Daten |
| **Fitbit** | Aktivitäts-Tracking |

---

## Home Automation

| Integration | Steuerung |
|-------------|-----------|
| **Home Assistant** | Smart Home Hub |
| **Philips Hue** | Beleuchtung |
| **Winix** | Luftreiniger |
| **ESP32** | Custom IoT |

---

## Monitoring & Alerting

| Integration | Zweck |
|-------------|-------|
| **Sentry** | Error-Tracking |
| **Datadog** | Monitoring |
| **Grafana** | Visualisierung |
| **PagerDuty** | On-Call |

---

## Social & Content

| Integration | Nutzung |
|-------------|---------|
| **Twitter/X** | Posting, Monitoring |
| **LinkedIn** | Professionelles Netzwerk |
| **YouTube** | Video-Analyse |
| **WordPress** | CMS-Management |

---

## Finanzen

| Integration | Anwendung |
|-------------|-----------|
| **Stripe** | Zahlungsabwicklung |
| **Plaid** | Bank-Integration |
| **QuickBooks** | Buchhaltung |

---

## E-Commerce

| Integration | Funktion |
|-------------|----------|
| **Shopify** | Store-Management |
| **WooCommerce** | WordPress-E-Commerce |

---

## Security

| Integration | Zweck |
|-------------|-------|
| **1Password** | Secrets-Management |
| **Bitwarden** | Passwort-Manager |
| **VirusTotal** | Skill-Security-Scanning |

---

## Web-Scraping & Browser

| Tool | Funktion |
|------|----------|
| **Puppeteer** | Headless Chrome |
| **Playwright** | Cross-Browser |
| **Cheerio** | HTML-Parsing |
| **Browser-Use** | Agent-Steuerung |

---

## Custom Integration Guide

### Eigene Integration bauen

```javascript
// Skill-Template für neue Integration
export default {
  name: 'my-integration',
  version: '1.0.0',
  description: 'Beschreibung',
  
  tools: [
    {
      name: 'toolName',
      description: 'Was das Tool macht',
      parameters: { /* ... */ },
      handler: async (params) => {
        // Implementation
      }
    }
  ]
}
```

### Integration via ClawHub

1. Skill entwickeln
2. Auf [clawhub.ai](https://clawhub.ai) veröffentlichen
3. Community-Nutzung

---

## Native Extensions (~70 Plugins)

### Kategorien

| Kategorie | Anzahl |
|-----------|--------|
| **Channels** | 10+ (Telegram, Discord, Slack, ...) |
| **LLM** | 5+ (Anthropic, OpenAI, Groq, ...) |
| **Speech** | 3+ (Deepgram, ElevenLabs, ...) |
| **Tools** | 50+ (verschiedene Services) |

→ Vollständige Liste: `openclaw.mjs --list-plugins`

---

## Community Skills (~35+)

### Beliebte Community-Beiträge

| Skill | Autor | Beschreibung |
|-------|-------|--------------|
| `whoop` | Community | WHOOP-Daten-Integration |
| `obsidian` | Community | Knowledge-Base-Link |
| `wordpress` | Community | CMS-Steuerung |
| `flight-search` | @wizaj | Multi-Provider Flugsuche |
| `todoist` | @iamsubhrajyoti | Task-Automation |

→ [Showcase ansehen](https://openclaw.ai/showcase)

---

## Integration Testing

### Verfügbarkeit prüfen

```bash
# Alle verfügbaren Plugins anzeigen
docker exec openclaw openclaw plugins list

# Spezifische Integration testen
docker exec openclaw openclaw agent --message "test telegram connection"
```

---

## Fehlersuche

| Problem | Lösung |
|---------|--------|
| Auth-Fehler | API-Keys in `openclaw.json` prüfen |
| Timeout | Netzwerk-Verbindung testen |
| Rate-Limit | Retry-Logik implementieren |
| Skill-Fehler | Logs: `docker logs openclaw` |
