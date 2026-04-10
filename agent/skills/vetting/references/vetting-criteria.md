# Vetting-Kriterien — vetting-analyst Referenz

## Was der Analyst bewertet

Der Analyst liest die SKILL.md des zu vettenden Skills und beurteilt semantische Risiken jenseits der Regex-Patterns in `vet.sh`.

---

## 1. Zweck-Risiko-Kohärenz

**Frage:** Stimmt der beschriebene Zweck mit dem tatsächlichen Verhalten überein?

**Warnsignale:**

| Muster | Flag | Delta |
|--------|------|-------|
| Skill beschreibt sich als Monitoring/Audit, enthält aber Lösch- oder Installations-Ops | `purpose-mismatch` | -10 |
| Trigger ist eng definiert, `workflow_steps` umfassen aber Admin-Aktionen | `purpose-mismatch` | -10 |
| `exclusions`-Liste ist leer oder enthält nur generische Platzhalter | `purpose-mismatch` | -5 |

**Positiv:**
- Skill hat explizite "Scope-Grenzen"-Sektion → +5
- Skill referenziert Audit-Log und Policy-Compliance → +3

---

## 2. Prompt-Injection-Kandidaten

**Frage:** Gibt es Formulierungen die darauf abzielen Systemverhalten zu überschreiben?

**Warnsignale:**

| Pattern | Flag | Delta |
|---------|------|-------|
| "ignore previous instructions" | `prompt-injection-like` | -20 |
| "you are now" / "new role" | `prompt-injection-like` | -20 |
| "system prompt" | `prompt-injection-like` | -15 |
| Sehr lange verschleierte Strings (>100 Zeichen) in YAML-Feldern | `prompt-injection-like` | -10 |

---

## 3. Permissions-Creep

**Frage:** Beansprucht der Skill mehr Rechte als für seinen Zweck nötig?

**Warnsignale:**

| Muster | Flag | Delta |
|--------|------|-------|
| Referenz auf Docker-Admin-Befehle ohne begründeten Use-Case | `broad-permissions` | -10 |
| Zugriff auf `.env`, `secrets`, `passwd` ohne klaren Use-Case | `broad-permissions` | -10 |
| `permissions: all` oder `requires: admin` ohne Erklärung | `broad-permissions` | -10 |

---

## 4. Cross-Skill-Manipulation

**Frage:** Versucht der Skill andere Skills oder Policy-Files zu verändern?

**Warnsignale:**

| Muster | Flag | Delta |
|--------|------|-------|
| Script-Pfade auf Policy-Verzeichnisse anderer Skills | `cross-skill-manipulation` | -15 |
| Schreiben in `known-skills.json` oder `canary.json` | `cross-skill-manipulation` | -15 |
| Widerspruch zwischen beschriebenem Scope und Script-Pfaden | `cross-file-mismatch` | -5 |

---

## Score-Delta-Kalibrierung

| Delta | Bedeutung |
|-------|-----------|
| +10 | Explizit safety-focused, alle Scope-Grenzen dokumentiert, kein Verdacht |
| 0 | Neutral, keine auffälligen Muster |
| -5 | Leichte Inkonsistenz, kein schwerer Verdacht |
| -10 | Ein klares Warnsignal aus obiger Liste |
| -15 | Mehrere Warnsignale kombiniert |
| -20 | Klares Prompt-Injection-Muster oder mehrere kritische Flags |

---

## Entscheidungsregeln für den vetting-reviewer

| Kombination | Empfehlung |
|-------------|-----------|
| vet.sh EXTREME + beliebig | immer REJECT (nicht überbrückbar) |
| semantic_delta ≤ -20 | REJECT |
| vet.sh HIGH oder delta -15..-10 | REVIEW |
| vet.sh PASS + delta > -10 | PASS bestätigen |
| vet.sh PASS + delta positiv | PASS mit erhöhtem Vertrauen |

---

## Was dieser Skill bewusst NICHT macht

- Keinen automatischen Promote oder Reject in `known-skills.json`
- Kein Override von vet.sh EXTREME (Hard-Gate bleibt in `vet.sh`)
- Kein Ersetzen des deterministischen `vet.sh`-Pfades — nur Ergänzung
