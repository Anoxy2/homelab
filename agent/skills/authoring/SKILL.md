---
name: authoring
description: Skill fuer Draft-Erzeugung neuer Skills. Kapselt Mode-Detection, Queue-Eintrag und Dateigenerierung; aufgerufen ueber den skill-forge Wrapper.
---

# authoring

## Zweck

Dieser Skill kapselt die eigentliche Authoring-Logik fuer neue Skill-Entwuerfe.
Der Skill-Manager bleibt Wrapper/Entry-Point, die Draft-Implementierung lebt hier.

## Trigger

```bash
~/scripts/skill-forge author skill <name> [--mode auto|template|from-tested|scratch] [--reason <text>]
~/scripts/skills authoring <name> [--mode auto|template|from-tested|scratch] [--reason <text>]
```

## Pipeline

- `author-skill.sh` (Skill-Manager-Wrapper)
- `~/scripts/skills authoring ...` (Standalone-Wrapper)
- `authoring-dispatch.sh` (Skill-Implementierung)

## Scope

Erlaubt:
- Lesen/Schreiben von `author-queue.json`
- Lesen/Schreiben von `known-skills.json`
- Slug-Normalisierung und Kollisionspruefung vor dem Anlegen (`Sample Skill` -> `sample-skill`)
- Anlegen von Skill-Draft-Dateien unter `~/agent/skills/<slug>/`
- Erzeugen eines Minimal-Skeletons: `SKILL.md`, `agents/`, `scripts/`, `contracts/default.output.schema.json`, `references/AUTHORING.md`
- Ablegen von `quality_score` / `quality_tier` in Queue und `known-skills.json`

Nicht erlaubt:
- Aktivierung auf `active` ohne Vetting/Canary
- Modifikation von Secrets oder Policy-Dateien
