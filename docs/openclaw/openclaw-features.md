# OpenClaw – Features & Capabilities

> Detaillierte Übersicht aller Kernfunktionen  
> Stand: April 2026 · Quelle: [openclaw.ai](https://openclaw.ai/)

---

## Core Features

### 1. Runs on Your Machine

**Lokale Ausführung mit voller Kontrolle:**

| Aspekt | Details |
|--------|---------|
| **Plattformen** | macOS, Windows, Linux |
| **Hardware** | Desktop, Laptop, Raspberry Pi |
| **LLM-Optionen** | Anthropic, OpenAI, oder lokale Modelle |
| **Datenschutz** | Private by default – deine Daten bleiben deine |

→ [Getting Started Guide](https://docs.openclaw.ai/getting-started)

---

### 2. Any Chat App

**Bedienbar über alle gängigen Messaging-Plattformen:**

| Plattform | Unterstützung |
|-----------|---------------|
| **WhatsApp** | ✅ Vollständig |
| **Telegram** | ✅ Vollständig |
| **Discord** | ✅ Vollständig |
| **Slack** | ✅ Vollständig |
| **Signal** | ✅ Vollständig |
| **iMessage** | ✅ Vollständig |

- Funktioniert in **DMs und Gruppenchats**
- Gleiche Funktionalität über alle Kanäle
- Eine Session, multiple Interfaces

→ [Alle 50+ Integrationen](https://openclaw.ai/integrations)

---

### 3. Persistent Memory

**Der Agent wird mit der Zeit zu deinem Agenten:**

- **Erinnert sich an dich** – Präferenzen, Kontext, Vorlieben
- **Wird einzigartig** – Personalisiert durch Nutzung
- **24/7 Kontext** – Unterbrechungsfreie Sitzungen
- **Cross-Session Memory** – Erkenntnis aus vorherigen Chats

→ [Session Dokumentation](https://docs.openclaw.ai/session)

#### Memory-Architektur (3-Schichten)

| Schicht | Speicherort | Zweck |
|---------|-------------|-------|
| **Agent-Workspace** | `agent/MEMORY.md` | Kuratiertes Langzeit-Gedächtnis |
| **Daily Notes** | `agent/memory/YYYY-MM-DD.md` | Rohes Tageslog |
| **Native SQLite** | `memory/main.sqlite` | Durchsuchbar (Vector + Keyword) |

---

### 4. Browser Control

**Autonome Web-Interaktion:**

- **Web browsing** – Surft im Internet für dich
- **Form filling** – Füllt Formulare automatisch aus
- **Data extraction** – Extrahiert Daten von beliebigen Websites
- **Screenshot capabilities** – Visuelle Dokumentation
- **Headless operation** – Läuft im Hintergrund

→ [Browser Dokumentation](https://docs.openclaw.ai/browser)

---

### 5. Full System Access

**Voller Zugriff auf dein System (optional sandboxed):**

| Fähigkeit | Beschreibung |
|-----------|--------------|
| **File I/O** | Lesen und Schreiben von Dateien |
| **Shell commands** | Ausführen von Terminal-Befehlen |
| **Script execution** | Scripts automatisch ausführen |
| **Sandbox mode** | Optional eingeschränkter Zugriff |

→ [Bash/System Dokumentation](https://docs.openclaw.ai/bash)

---

### 6. Skills & Plugins

**Erweiterbar durch Community und dich selbst:**

- **~70 Native Plugins** – Erweiterungen für verschiedene Use-Cases
- **~35 Native Skills** – Fertige Skill-Implementierungen
- **Community Skills** – Von anderen Nutzern geteilt
- **Self-writing** – OpenClaw kann seine eigenen Skills schreiben

→ [Skills Dokumentation](https://docs.openclaw.ai/skills)

#### Skill-Ecosystem (ClawHub)

| Skill | Zweck |
|-------|-------|
| `clawflow` | Multi-step Background-Job-Orchestration |
| `coding-agent` | Delegiert Coding-Tasks an Claude Code, Codex, Pi |
| `skill-creator` | Erstellt und auditiert SKILL.md-Dateien |
| `clawhub` | Skill-Publishing und Installation |
| `healthcheck` | Security & Risk-Assessment |
| `canvas` | Canvas-UI-Interaktion |

---

## Erweiterte Features

### Heartbeat System

**Proaktive Überwachung alle 30 Minuten (konfigurierbar):**

- System-Status-Checks
- Proaktive Aufgaben-Ausführung
- Autonome Überwachung
- Zeitgesteuerte Erinnerungen

### Webhook System

**Externe Trigger für automatisierte Workflows:**

```bash
curl -X POST http://192.168.2.101:18789/hooks/growbox-alert \
  -H "Authorization: Bearer $OPENCLAW_WEBHOOK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Temp kritisch", "entity_id": "sensor.temp"}'
```

### Multi-Agent Support

- Mehrere Agenten mit unterschiedlichen Persönlichkeiten
- Session-Isolation zwischen Nutzern
- Rollenbasierte Zugriffssteuerung

---

## Feature-Kategorien

### Produktivität

- ✉️ E-Mail-Verwaltung
- 📅 Kalender-Management
- ✅ Todo-Integration
- 📝 Notizen & Dokumentation
- 📊 Daten-Analyse

### Entwicklung

- 💻 Code-Generierung
- 🔍 Code-Review
- 🧪 Test-Automatisierung
- 📦 Deployment-Unterstützung
- 🔧 Debugging-Assistenz

### Integration

- 🔗 50+ Drittanbieter-Integrationen
- 📱 Smartphone-Steuerung
- 🌐 Web-Service-APIs
- 📡 IoT-Geräte-Steuerung
- 🗄️ Datenbank-Zugriff

### Automatisierung

- ⏰ Zeitgesteuerte Aufgaben
- 🔄 Workflow-Orchestration
- 📥 Auto-Processing (E-Mails, Dokumente)
- 🚨 Alert-Handling
- 📊 Reporting-Automatisierung

---

## LLM-Integrationen

### Unterstützte Provider

| Provider | Models | Use-Case |
|----------|--------|----------|
| **Anthropic** | Claude 3.5/4 Sonnet, Opus | Premium Reasoning |
| **OpenAI** | GPT-4, GPT-4o, GPT-4.1 | All-purpose |
| **GitHub Copilot** | GPT-4.1 | Coding-Tasks |
| **Groq** | Llama, Mixtral | Speed/Low-cost |
| **Local** | Ollama, LM Studio | Privacy-first |

---

## Speech & Audio

### Voice Capabilities

| Integration | Funktion |
|-------------|----------|
| **Deepgram** | Speech-to-Text |
| **ElevenLabs** | Text-to-Speech mit naturgetreuen Stimmen |

Anwendungsfälle:
- Hands-free Interaktion
- Personalisierte Meditationen mit generiertem Ambient-Audio
- Telefonanrufe mit AI-Generierter Stimme

---

## Canvas UI

**Browser-basierte Interface (Port 8090):**

- Lokale Web-UI für OpenClaw
- Chat-Interface mit History
- Skill-Verwaltung
- System-Status-Übersicht

---

## Skills Showcase: Real-World Beispiele

### Von der Community gebaut

| Nutzer | Use-Case |
|--------|----------|
| @vallver | Stumbleupon für Artikel (Stumblereads.com) |
| @nateliason | Autonomes Testen & Sentry-Integration |
| @antonplex | Luftreiniger-Steuerung mit Biomarker-Optimierung |
| @christinetyip | Second-Brain-Builder in WhatsApp |
| @Infoxicador | Automatische API-Key-Provisionierung |
| @iamjohnellison | Vibe-Coding-Unterricht für Studenten |

→ [Weitere Beispiele im Showcase](https://openclaw.ai/showcase)
