# OpenClaw Canary Run Plan (RAG/UI)

> Canary-Deployment Strategie für OpenClaw Skills  
> Stand: April 2026 · Quelle: [openclaw.ai](https://openclaw.ai/) & [trust.openclaw.ai](https://trust.openclaw.ai/)

---

## Ziel

Ersten kontrollierten Canary-Durchlauf fuer openclaw-rag und openclaw-ui durchfuehren.

## Scope

| Komponente | Version | Dauer |
|------------|---------|-------|
| Skill: openclaw-rag | Latest | 24h Beobachtungsfenster |
| Skill: openclaw-ui | Latest | 24h Beobachtungsfenster |

---

## OpenClaw Context

### Warum Canary bei OpenClaw?

OpenClaw ist ein **lokal laufender AI-Agent** mit folgenden Eigenschaften:
- **Self-hosted** – Nutzer kontrollieren eigene Instanzen
- **Persistent Memory** – Fehler wirken sich auf Langzeit-Kontext aus
- **Multi-Channel** – Telegram, Discord, etc. als kritische Interfaces
- **Proactive** – Agent agiert autonom, nicht nur reaktiv

Daher ist **striktes Canary-Testing** vor Promotion essenziell.

### VirusTotal Integration (Security)

> 🔒 **Neu**: Alle Skills werden vor Deployment auf VirusTotal gescannt.

| Check | Tool | Status |
|-------|------|--------|
| Malware-Scan | VirusTotal API | ✅ Required |
| Static Analysis | `skill-forge policy lint` | ✅ Required |
| Reputation Score | ClawHub | ✅ Required |

---

## Ablauf

## Ablauf
1. Vorbereitungscheck
- `~/scripts/skill-forge policy lint`
- `~/scripts/skill-forge health`
- `~/scripts/backup.sh`

2. Canary starten
- `~/scripts/skill-forge canary start openclaw-rag 24`
- `~/scripts/skill-forge canary start openclaw-ui 24`

3. Beobachtung
- `~/scripts/skill-forge canary status openclaw-rag`
- `~/scripts/skill-forge canary status openclaw-ui`
- RAG-Testfragen aus `agent/skills/openclaw-rag/TEST-QUESTIONS.md`
- `~/agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh --json`
- UI-Smoketest am Canvas

4. Promotion (nur bei stabilen Metriken)
- `~/scripts/skill-forge provenance write openclaw-rag <source> <url> <fingerprint> <score> <tier> <version>`
- `~/scripts/skill-forge provenance write openclaw-ui <source> <url> <fingerprint> <score> <tier> <version>`
- `~/scripts/skill-forge canary promote openclaw-rag`
- `~/scripts/skill-forge canary promote openclaw-ui`

5. Rollback (bei Regression)
- `~/scripts/skill-forge canary fail openclaw-rag`
- `~/scripts/skill-forge canary fail openclaw-ui`
- `~/scripts/skill-forge rollback openclaw-rag`
- `~/scripts/skill-forge rollback openclaw-ui`

## Exit-Kriterien

### RAG-Qualität

| Metrik | Threshold | Messung |
|--------|-----------|---------|
| `precision@5` | >= 0.25 | Relevanz der Top-5 Ergebnisse |
| `recall@5` | >= 0.55 | Abdeckung relevanter Dokumente |
| `p95 Latenz` | <= 200ms | 95. Perzentil Response-Zeit |

### Fehler-Klassen

| Klasse | Beispiel | Aktion |
|--------|----------|--------|
| 🔴 **Kritisch** | Falsche Quellen, Halluzinationen ohne Hinweis | Sofort-Rollback |
| 🟡 **Warnung** | Langsame Queries (>500ms) | Monitoring, ggf. Rollback |
| 🟢 **Akzeptabel** | Kosmetische UI-Issues | Fix im nächsten Patch |

### Security

- [ ] Keine Secrets in Logs
- [ ] Keine PII-Exposure in RAG-Antworten
- [ ] VirusTotal Scan: Clean
- [ ] Keine neuen Netzwerk-Verbindungen zu unbekannten Hosts

### UI

- [ ] Alle Buttons reagieren
- [ ] Fehlerpfade zeigen nachvollziehbare Messages
- [ ] Keine Dead-Ends
- [ ] Mobile Responsive (falls relevant)

---

## Rollback-Entscheidung

### Automatisches Rollback bei:

1. `precision@5 < 0.15` (hard threshold)
2. > 5% Error-Rate in 1h
3. Security Alert (VirusTotal, Secrets-Leak)
4. Memory-Leak (>80% RAM nach 6h)

### Manuelles Rollback bei:

- Nutzer-Feedback: "RAG-Antworten sind schlechter"
- UI-Regressionen
- Performance-Degradation

---

## Post-Canary

### Success

1. Provenance schreiben
2. Promotion durchführen
3. Changelog aktualisieren
4. Community-Update (Discord #releases)

### Failure

1. Incident-Log erstellen
2. Root-Cause-Analysis
3. Fix entwickeln
4. Neuen Canary starten

---

## Links

- [Trust Center](https://trust.openclaw.ai/)
- [VirusTotal Blogpost](https://openclaw.ai/blog/virustotal-partnership)
- [Skill-Entwicklung](https://docs.openclaw.ai/skills)
- [Discord #ops](https://discord.com/invite/clawd)
