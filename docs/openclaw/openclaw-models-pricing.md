# OpenClaw – Models & Pricing (Detaillierte Übersicht)

> Alle unterstützten LLM-Provider, Modelle, Kosten und Performance-Charakteristiken  
> Stand: April 2026

---

## Provider-Übersicht

### Empfohlene Kombination (für Pi/Self-Hosted)

| Rang | Provider | Primär-Use-Case | Kosten | Speed |
|------|----------|----------------|--------|-------|
| 1 | **GitHub Copilot** | Coding, Allgemein | ⭐⭐⭐ Günstig | ⚡⚡⚡ Schnell |
| 2 | **Groq** | Schnelle Antworten | ⭐⭐⭐ Günstig | ⚡⚡⚡⚡ Extrem schnell |
| 3 | **Anthropic** | Reasoning, Safety | ⭐⭐ Teuer | ⚡⚡ Mittel |
| 4 | **OpenAI** | Zuverlässigkeit | ⭐⭐ Mittel | ⚡⚡ Mittel |
| 5 | **Local/Ollama** | Offline, Privacy | ⭐ Kostenlos | 🐢 Langsam |

---

## 1. GitHub Copilot (Empfohlen)

### Verfügbare Modelle

| Modell | Kontext | Input | Output | Best für |
|--------|---------|-------|--------|----------|
| **GPT-4.1** | 1M Tokens | $0.50 | $1.50 | Coding, Tools |
| **GPT-4o** | 128K | $2.50 | $10.00 | Allgemein |
| **GPT-4o-mini** | 128K | $0.15 | $0.60 | Budget-Tasks |

### Setup

```json
{
  "agent": {
    "model": "github-copilot/gpt-4.1"
  }
}
```

### Auth
- OAuth über GitHub
- ODER: Copilot-Proxy (wie du es nutzt)

### Limits
- 20K Requests/Monat (Copilot Pro)
- Danach: Throttling

---

## 2. Groq (Speed-Demon)

### Verfügbare Modelle

| Modell | Kontext | Input | Output | Speed |
|--------|---------|-------|--------|-------|
| **Llama 3.3 70B** | 128K | $0.59 | $0.79 | 1000+ T/s |
| **Llama 3.1 70B** | 128K | $0.59 | $0.79 | 800 T/s |
| **Mixtral 8x22B** | 64K | $0.90 | $0.90 | 500 T/s |
| **Llama 3.1 8B** | 128K | $0.05 | $0.08 | 2000+ T/s |

### Setup

```json
{
  "agent": {
    "model": "groq/llama-3.3-70b-versatile",
    "apiKey": "${GROQ_API_KEY}"
  }
}
```

### Warum Groq?
- **Schnellste Inferenz** (Kernel-optimiert)
- **Günstig** für gute Qualität
- **Großer Kontext** (128K)

### Limits
- 20 RPM (kostenlos)
- 500 RPM (paid)

---

## 3. Anthropic (Reasoning)

### Verfügbare Modelle

| Modell | Kontext | Input | Output | Best für |
|--------|---------|-------|--------|----------|
| **Claude 3.5 Sonnet** | 200K | $3.00 | $15.00 | Complex Reasoning |
| **Claude 3.5 Haiku** | 200K | $0.80 | $4.00 | Schnelle Antworten |
| **Claude 3 Opus** | 200K | $15.00 | $75.00 | Extremes Reasoning |

### Setup

```json
{
  "agent": {
    "model": "anthropic/claude-3-5-sonnet-20241022",
    "apiKey": "${ANTHROPIC_API_KEY}"
  }
}
```

### Anthropic-spezifisch
- **Constitutional AI** (Safety)
- **Beste Tool-Usage** (inkl. Computer-Use)
- **Caching** (90% Discount für Prompt-Caching)

### Caching-Beispiel

```json
{
  "agent": {
    "model": "anthropic/claude-3-5-sonnet-20241022",
    "promptCaching": {
      "enabled": true,
      "checkpointEvery": 5
    }
  }
}
```

### Preis mit Caching
- Erster Request: $3.00/1M Input
- Gecachte Prompts: $0.30/1M Input (90% Ersparnis!)

---

## 4. OpenAI

### Verfügbare Modelle

| Modell | Kontext | Input | Output | Best für |
|--------|---------|-------|--------|----------|
| **GPT-4o** | 128K | $2.50 | $10.00 | Allgemein |
| **GPT-4o-mini** | 128K | $0.15 | $0.60 | Budget |
| **o1-preview** | 128K | $15.00 | $60.00 | Reasoning |
| **o1-mini** | 128K | $3.00 | $12.00 | Reasoning (klein) |

### Setup

```json
{
  "agent": {
    "model": "openai/gpt-4o",
    "apiKey": "${OPENAI_API_KEY}"
  }
}
```

### OpenAI-spezifisch
- **Zuverlässigste API**
- **Strukturierte Outputs** (JSON-Mode)
- **Codex** (neuer Coding-Agent)

---

## 5. Lokale Modelle (Ollama)

### Pi-taugliche Modelle

| Modell | Größe | RAM-Bedarf | Speed | Qualität |
|--------|-------|------------|-------|----------|
| **Llama 3.1 8B** | 4.7 GB | 6 GB | 10-20 T/s | Mittel |
| **Phi-4 14B** | 9.1 GB | 12 GB | 5-10 T/s | Gut |
| **Qwen 2.5 7B** | 4.5 GB | 6 GB | 15-25 T/s | Mittel |
| **DeepSeek-R1 7B** | 4.5 GB | 6 GB | 10-15 T/s | Reasoning |

### Setup

```bash
# Ollama installieren
curl -fsSL https://ollama.com/install.sh | sh

# Modell pullen
ollama pull llama3.1:8b

# Server starten
ollama serve
```

```json
{
  "agent": {
    "model": "ollama/llama3.1:8b",
    "baseUrl": "http://localhost:11434",
    "timeout": 300000
  }
}
```

### Warnungen
- **Tool-Usage oft unzuverlässig**
- **Langsame Antworten** auf Pi
- **Hoher RAM-Verbrauch**

---

## Model Failover

### Automatisches Failover

```json
{
  "agent": {
    "model": "github-copilot/gpt-4.1",
    "fallbackModels": [
      "groq/llama-3.3-70b-versatile",
      "anthropic/claude-3-5-sonnet-20241022"
    ],
    "failover": {
      "onError": true,
      "onTimeout": true,
      "timeout": 30000
    }
  }
}
```

### Retry-Policy

```json
{
  "agent": {
    "retry": {
      "maxAttempts": 3,
      "backoff": "exponential",
      "initialDelay": 1000
    }
  }
}
```

---

## Kosten-Optimierung

### Für Pi/Self-Hosted

| Strategie | Ersparnis | Implementierung |
|-----------|-----------|-----------------|
| **GitHub Copilot** | 80% vs. Anthropic | `model: github-copilot/gpt-4.1` |
| **Groq für schnelle Tasks** | 70% vs. GPT-4 | `model: groq/llama-3.3-70b` |
| **Anthropic Caching** | 90% bei wiederholten Prompts | `promptCaching.enabled: true` |
| **Local für Tests** | 100% | `ollama/llama3.1:8b` |

### Thinking-Level (Token-Control)

```json
{
  "agent": {
    "thinkingLevel": "medium"  // off/minimal/low/medium/high/xhigh
  }
}
```

| Level | Verwendung | Token-Faktor |
|-------|------------|--------------|
| `off` | Schnelle Antworten | 1x |
| `minimal` | Fakten | 1.2x |
| `low` | Standard | 1.5x |
| `medium` | Komplexe Tasks | 2x |
| `high` | Debugging, Analysis | 3x |
| `xhigh` | Research, Planning | 5x |

### Usage-Tracking

```bash
# Aktueller Monat
docker exec openclaw openclaw usage --period month

# Pro Session
docker exec openclaw openclaw usage --session claude-ops

# Export CSV
docker exec openclaw openclaw usage --export csv > usage.csv
```

---

## Performance-Vergleich

### Auf Raspberry Pi 4/5

| Provider | Modell | Erste Antwort | Tokens/Sek | RAM-Usage |
|----------|--------|---------------|------------|-----------|
| **Groq** | Llama 3.3 70B | 0.5s | N/A (remote) | ~100 MB |
| **GitHub** | GPT-4.1 | 1-2s | N/A (remote) | ~100 MB |
| **Anthropic** | Claude 3.5 | 2-3s | N/A (remote) | ~100 MB |
| **Local** | Llama 3.1 8B | 3-5s | 25 T/s | 6 GB |
| **Local** | Llama 3.3 70B Q4 | 10-15s | 8 T/s | 8 GB |

---

## Konfigurations-Beispiele

### Budget-Setup (5$/Monat)

```json
{
  "agent": {
    "model": "groq/llama-3.1-8b-instant",
    "fallbackModels": ["github-copilot/gpt-4.1-mini"],
    "thinkingLevel": "low"
  }
}
```

### Premium-Setup (50$/Monat)

```json
{
  "agent": {
    "model": "anthropic/claude-3-5-sonnet-20241022",
    "fallbackModels": [
      "github-copilot/gpt-4.1",
      "groq/llama-3.3-70b-versatile"
    ],
    "promptCaching": {
      "enabled": true
    },
    "thinkingLevel": "medium"
  }
}
```

### Offline-Setup (0$/Monat)

```json
{
  "agent": {
    "model": "ollama/llama3.1:8b",
    "baseUrl": "http://localhost:11434",
    "timeout": 300000,
    "thinkingLevel": "low"
  }
}
```

---

## API-Keys beschaffen

| Provider | URL | Kosten |
|----------|-----|--------|
| **GitHub Copilot** | https://github.com/settings/copilot | $10/Monat |
| **Groq** | https://console.groq.com | Kostenlos bis 20 RPM |
| **Anthropic** | https://console.anthropic.com | $5 Startguthaben |
| **OpenAI** | https://platform.openai.com | Pay-as-you-go |
| **Ollama** | https://ollama.com | Kostenlos |

---

## Troubleshooting Models

### "Model not available"

```bash
# Verfügbare Modelle listen
docker exec openclaw openclaw models list

# Provider-Status prüfen
curl https://api.groq.com/openai/v1/models \
  -H "Authorization: Bearer $GROQ_API_KEY"
```

### "Rate limit exceeded"

```bash
# Zu Groq wechseln (höhere Limits)
docker exec openclaw openclaw agent \
  --message "test" \
  --model groq/llama-3.3-70b-versatile
```

### Langsame Antworten

```bash
# Auf schnelleres Model wechseln
docker exec openclaw openclaw agent \
  --message "test" \
  --model groq/llama-3.1-8b-instant
```
