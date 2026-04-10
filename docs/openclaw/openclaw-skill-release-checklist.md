# OpenClaw Skill Release Checklist (RAG/UI)

> Release-Prozess für OpenClaw Skills mit Security-Checks  
> Stand: April 2026 · Quelle: [openclaw.ai](https://openclaw.ai/) & [trust.openclaw.ai](https://trust.openclaw.ai/)

---

## 0. Security Pre-Flight (VirusTotal)

> 🔒 **Neu ab 2026**: Alle Skills müssen VirusTotal-Scan bestehen

- [ ] Skill-Code auf Secrets/Keys gescannt (`grep -r "sk-" .`)
- [ ] `~/scripts/skill-forge security scan <slug>` ausgeführt
- [ ] VirusTotal-Upload: [clawhub.ai](https://clawhub.ai) oder API
- [ ] Scan-Result: **0/70+ Detections** ✅
- [ ] Static Analysis: Keine suspicious patterns
- [ ] Dependencies geprüft (`npm audit` / `pip audit`)

---

## 1. Vorbereitung

- [ ] `~/scripts/skill-forge policy lint` ✅ passed
- [ ] `~/scripts/skill-forge health` ✅ all green
- [ ] `~/scripts/skill-forge budget` ✅ Kosten-Limit OK
- [ ] `~/scripts/backup.sh` ✅ Backup erstellt
- [ ] Git-Status: Alle Änderungen committed

---

## 2. Lifecycle Gates

- [ ] Skill authored/updated via skill-forge workflow
- [ ] Dokumentation aktualisiert (README.md, SKILL.md)
- [ ] Unit-Tests laufen durch (`npm test` / `pytest`)
- [ ] Canary gestartet: `~/scripts/skill-forge canary start <slug> 24`
- [ ] 24h Beobachtungsfenster abgewartet
- [ ] Canary-Status geprüft: `~/scripts/skill-forge canary status <slug>`
- [ ] Exit-Kriterien erfüllt (siehe [canary-run-plan](openclaw-canary-run-plan.md))
- [ ] Provenance geschrieben: `~/scripts/skill-forge provenance write <slug> ...`
- [ ] Promotion nur bei stabilen Metriken ✅

---

## 3. Pre-Promotion Validierung

### RAG-Skills
- [ ] `rag-canary-smoke.sh` ✅ (`precision@5 >= 0.25`, `recall@5 >= 0.55`)
- [ ] Testfragen gegen Expected Evidence geprüft
- [ ] Keine Halluzinationen ohne Source-Annotation
- [ ] Latenz-Test: p95 <= 200ms

### UI-Skills
- [ ] UI-Smoketest (Buttons, Status, Fehlerpfade) durchgeführt
- [ ] Mobile-Responsive Check (falls relevant)
- [ ] Accessibility-Test (Keyboard-Navigation)
- [ ] Keine Console-Errors im Browser

### Security
- [ ] Keine Secrets in Logs oder Output
- [ ] Keine PII-Exposure in Antworten
- [ ] Keine neuen unerwarteten Netzwerk-Verbindungen
- [ ] Rate-Limiting funktioniert

---

## 4. Promotion

- [ ] `~/scripts/skill-forge canary promote <slug>`
- [ ] Verifikation: `~/scripts/skill-forge status`
- [ ] Smoke-Test in Production durchgeführt
- [ ] Community-Update vorbereitet (Discord #releases)

---

## 5. Rollback (falls notwendig)

- [ ] `~/scripts/skill-forge canary fail <slug>`
- [ ] `~/scripts/skill-forge rollback <slug>`
- [ ] Canary fail setzen, wenn Regression bestätigt
- [ ] Incident freeze aktivieren, wenn mehrfach fehlschlagend
- [ ] Root-Cause-Analysis dokumentiert

---

## 6. Nachbereitung (Success)

- [ ] Changelog gepflegt ([openclaw.ai/blog](https://openclaw.ai/blog))
- [ ] Git-Tag erstellt: `git tag -a v1.x.x -m "Release notes"`
- [ ] Release auf GitHub erstellt
- [ ] Skill auf [clawhub.ai](https://clawhub.ai) veröffentlicht
- [ ] VirusTotal-Report verlinkt
- [ ] Ergebnis im Tageskontext dokumentiert
- [ ] Offene Risiken als neue Todo-Einträge aufgenommen
- [ ] Discord #releases: Community-Update gepostet

---

## VirusTotal Integration Details

### Workflow

```bash
# 1. Skill-Paket erstellen
tar czf skill-package.tar.gz ./skill/

# 2. VirusTotal-Upload
curl -X POST https://www.virustotal.com/api/v3/files \
  -H "x-apikey: $VT_API_KEY" \
  -F "file=@skill-package.tar.gz"

# 3. Report abrufen (warte 2-5 min)
curl -X GET "https://www.virustotal.com/api/v3/analyses/{id}" \
  -H "x-apikey: $VT_API_KEY"

# 4. In openclaw.json verlinken
{
  "security": {
    "virustotal": {
      "scanId": "...",
      "permalink": "https://www.virustotal.com/gui/file/...",
      "detections": 0,
      "scannedAt": "2026-04-10T12:00:00Z"
    }
  }
}
```

### Akzeptanzkriterien

| Engine | Max Detections | Action |
|--------|---------------|--------|
| Any | 0 | ✅ Release |
| 1-2 | False Positives | 🔍 Manuelle Review |
| 3+ | Potentielle Bedrohung | ❌ Block Release |

---

## Links

- [Canary Run Plan](openclaw-canary-run-plan.md)
- [Trust Center](https://trust.openclaw.ai/)
- [VirusTotal API Docs](https://developers.virustotal.com/)
- [ClawHub](https://clawhub.ai/)
- [Discord #releases](https://discord.com/invite/clawd)
