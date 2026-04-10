# OpenClaw – Sicherheit & Datenschutz

> Security-Praktiken, Trust Center & Best Practices  
> Stand: April 2026 · Quelle: [trust.openclaw.ai](https://trust.openclaw.ai/)

---

## Sicherheitsprinzipien

### Private by Default

| Aspekt | Implementation |
|--------|----------------|
| **Datenlokalität** | Alle Daten bleiben auf deinem Gerät |
| **Kein Cloud-Upload** | Keine Daten an OpenClaw-Server |
| **Lokale LLM-Option** | Ollama/LM Studio für vollständige Offline-Nutzung |
| **Self-Hosted** | Du kontrollierst die Infrastruktur |

---

## VirusTotal Partnership

🔒 **Community Skill Security Scanning**

### Was ist das?

OpenClaw hat eine Partnerschaft mit **VirusTotal** für automatisierte Sicherheits-Scans von Community-Skills.

### Funktionsweise

1. **Upload** → Skill wird an VirusTotal gesendet
2. **Scan** → 70+ Antivirus-Engines prüfen den Code
3. **Report** → Ergebnis wird im ClawHub angezeigt
4. **Trust-Score** → Nutzer sehen Sicherheits-Bewertung

### Vorteile

| Feature | Beschreibung |
|---------|--------------|
| **Malware-Erkennung** | Bekannte Bedrohungen werden identifiziert |
| **Community-Vertrauen** | Transparenz über Skill-Sicherheit |
| **Pre-Installation** | Scan-Ergebnis vor dem Installieren sichtbar |
| **Continuous Monitoring** | Regelmäßige Re-Scans |

→ [Blogpost zur Partnerschaft](https://openclaw.ai/blog/virustotal-partnership)

---

## Authentifizierung & Autorisierung

### WebSocket PKI (Gateway)

**Challenge-Response-Authentifizierung:**

```
1. Client verbindet → Server sendet Challenge (Nonce)
2. Client signiert Nonce mit Ed25519 Private Key
3. Server verifiziert mit Public Key
4. Verbindung etabliert
```

### Identitäts-Dateien

| Datei | Inhalt | Sicherheit |
|-------|--------|------------|
| `device.json` | Device-ID, Ed25519 Keypair | 🔴 **Nicht committen!** |
| `device-auth.json` | Operator-Token, Scopes | 🔴 **Nicht committen!** |

### Token-Verwaltung

```bash
# Webhook-Token (für externe Hooks)
OPENCLAW_WEBHOOK_TOKEN=secure-random-string

# Operator-Token (für WebSocket)
tokens.operator.token (in device-auth.json)
```

---

## Secrets Management

### Best Practices

```bash
# ❌ Niemals in Code
const apiKey = "sk-abc123...";

# ✅ Environment oder Config
const apiKey = process.env.ANTHROPIC_API_KEY;

# ✅ 1Password Integration
op read "op://vault/item/field"
```

### Integrierte Secrets-Provider

| Provider | Nutzung |
|----------|---------|
| **1Password** | `op://` URIs in Config |
| **Bitwarden** | BW-CLI Integration |
| **.env Files** | Lokal, nicht committed |

---

## Sandboxing

### Full Access vs. Sandboxed

| Modus | Rechte | Use-Case |
|-------|--------|----------|
| **Full Access** | Alle System-Rechte | Vertrauenswürdige Umgebung |
| **Sandboxed** | Eingeschränkt | Experimente, neue Skills |

### Docker-Isolation

```dockerfile
# Container läuft als non-root
USER node

# Volume-Mounts nur für notwendige Pfade
volumes:
  - ./data:/data:rw
  - ./agent:/agent:ro
```

---

## Netzwerk-Sicherheit

### Gateway-Konfiguration

```json
{
  "gateway": {
    "bind": "127.0.0.1",  // Nur localhost (sicher)
    // ODER
    "bind": "lan"         // LAN-IP (für Remote-Zugriff)
  }
}
```

### Empfohlene Setup

| Szenario | Bind | Firewall |
|----------|------|----------|
| Nur lokal | `127.0.0.1` | Keine Änderung |
| LAN-Zugriff | `lan` | Port 18789 auf LAN beschränken |
| Remote + Cloudflare | `127.0.0.1` | Cloudflare Tunnel |

---

## Webhook-Sicherheit

### Authentifizierung

```bash
# Jeder Webhook erfordert Bearer-Token
curl -X POST http://192.168.2.101:18789/hooks/alert \
  -H "Authorization: Bearer $OPENCLAW_WEBHOOK_TOKEN" \
  -d '{"message": "..."}'
```

### IP-Whitelisting

```json
{
  "hooks": {
    "allowedIPs": ["192.168.2.0/24", "10.0.0.0/8"]
  }
}
```

---

## Audit Logging

### Action Log

```
infra/openclaw-data/action-log.jsonl
```

**Geloggt:**
- Jede Skill-Ausführung
- Jeder API-Call
- Alle Datei-Operationen
- Authentifizierungsversuche

### Format

```json
{
  "timestamp": "2026-04-10T12:00:00Z",
  "action": "skill.execute",
  "actor": "telegram:2011062206",
  "target": "whoop.fetch",
  "result": "success",
  "duration": 1250
}
```

---

## Skill-Sicherheit

### Community Skill Review

| Stufe | Prüfung |
|-------|---------|
| **Automated** | VirusTotal Scan |
| **Static Analysis** | Code-Patterns |
| **Reputation** | Autor-History |
| **Manual** | Community Reports |

### Eigenen Skill sicher bauen

```javascript
// Input-Validierung
function safeExecute(userInput) {
  // ✅ Whitelist statt Blacklist
  const allowed = ['read', 'write', 'list'];
  if (!allowed.includes(userInput.action)) {
    throw new Error('Invalid action');
  }
  
  // ✅ Parameter-Sanitization
  const safePath = path.normalize(userInput.path)
    .replace(/\.\./g, '');
    
  // ✅ Rate-Limiting
  await checkRateLimit(userInput.userId);
}
```

---

## Compliance

### Datenverarbeitung

| Aspekt | Status |
|--------|--------|
| **GDPR** | ✅ Self-hosted = Du bist Controller |
| **DSGVO** | ✅ Keine Drittanbieter ohne Consent |
| **HIPAA** | ⚠️ Je nach Konfiguration möglich |
| **SOC 2** | N/A (Self-hosted) |

---

## Sicherheits-Checkliste

### Setup

- [ ] Ed25519-Keys generiert und sicher gespeichert
- [ ] Webhook-Token: Kryptographisch sicher (>32 chars)
- [ ] API-Keys: In Secrets-Manager, nicht in Git
- [ ] Gateway-Bind: Auf notwendiges Minimum beschränkt

### Betrieb

- [ ] Logs regelmäßig prüfen
- [ ] Updates zeitnah einspielen
- [ ] Community-Skills vor Installation verifizieren
- [ ] Regelmäßige Backups der Konfiguration

### Monitoring

- [ ] Ungewöhnliche Aktivitäten erkennen
- [ ] Failed Auth-Versuche tracken
- [ ] API-Usage überwachen

---

## Trust Center

Offizielle Sicherheits-Informationen:

→ [trust.openclaw.ai](https://trust.openclaw.ai/)

**Ressourcen:**
- Security Policies
- Incident Response Plan
- Security Roadmap
- Bug Bounty Program (geplant)

---

## Report a Vulnerability

Sicherheitslücken melden:

```
security@openclaw.ai
```

PGP-Key: [Download](https://trust.openclaw.ai/pgp-key.asc)

---

## Security-Verantwortlicher

| Kontext | Ansprechpartner |
|---------|-----------------|
| OpenClaw Core | security@openclaw.ai |
| Community Skills | ClawHub Report-Funktion |
| Diese Dokumentation | Claude Code Session |
