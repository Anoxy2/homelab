---
name: profile
description: Verwaltet das Usage-Keyword-Profil des Systems. Keywords werden vom Scout-Curator genutzt um Discovery zu steuern.
---

# profile

## Zweck

Verwaltet `usage-profile.json` — die Sammlung von Keywords, die beschreiben welche Skill-Themen für diesen Pi relevant sind. Wird vom Scout-Curator gelesen um Discovery zu personalisieren.

## Wann nutzen

```bash
~/scripts/skills profile show
~/scripts/skills profile add <keyword>
~/scripts/skills profile reset
```

## Scope-Grenzen

| Erlaubt | Verboten |
|---------|----------|
| Lesen + Schreiben von usage-profile.json | Lifecycle-Operationen |
| Audit-Log-Einträge schreiben | Andere State-Dateien anfassen |
