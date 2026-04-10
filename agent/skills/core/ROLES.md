# Core — Role Glossary

Kurze Definitionen aller Rollen im Skill-Manager. Kanon für Namensgebung und Beschreibungstexte.

---

| Rolle | Kurzform | Definition |
|-------|----------|------------|
| **orchestrator** | ORC | Steuert den Gesamt-Loop: Scouting → Vetting → Install → Canary → Promote. Delegiert an andere Skills, trifft keine semantischen Urteile selbst. |
| **scout** | SCT | Findet neue Skill-Kandidaten aus externen Quellen. Output: slug + source + version. Schreibt nie aktiv in known-skills. |
| **vetter** | VET | Berechnet deterministischen Vetting-Score (input, static, reputation). Keine semantische Analyse. |
| **vetting-analyst** | VAN | Erweitert deterministischen Vetting-Score um semantisches Delta nach Lesen der SKILL.md. Soft-Binding an Policy. |
| **vetting-reviewer** | VRV | Trifft PASS/REVIEW/REJECT auf Basis von vet.sh-Score + Analyst-Delta. Kein State-Write. |
| **author** | AUT | Erstellt neue Skill-Gerüste aus natürlichsprachigem Request. Output landet in author-queue. |
| **planner** | PLN | Dekomponiert Coding-Task in strukturierten Plan (artifact_type, filename, constraints). |
| **coder** | COD | Generiert das eigentliche Artefakt nach Planner-Vorgabe. Hält Shell-Safety-Referenz ein. |
| **reviewer** | REV | Prüft Coder-Ausgabe auf Security, Policy, Vollständigkeit. Go → completed, No-Go → pending-review. |
| **canary-evaluator** | CEV | Liest Canary-Zustand + Audit-Log. Gibt Empfehlung promote/extend/fail + Confidence. ReadOnly. |
| **canary-approver** | CAP | Übersetzt Evaluator-Empfehlung in Go/No-Go/Extend-Verdict. Kein State-Write. |
| **doc.keeper** | DOC | Hält Dokumentation (*.md) synchron mit aktuellem Systemzustand. Schreibt nur docs/-Dateien. |
| **writer** | WRT | Thin-Wrapper für code-dispatch.sh. Entry-Point für `writer code|test|config|docs`-Kommandos. |
| **ha.control** | HAC | Liest/steuert Home Assistant Entities via REST-API. |
| **pi.control** | PIC | Führt Pi-Betriebskommandos aus (docker compose, disk, metrics, backup). |
| **rag.retrieve** | RAG | Semantische Suche über RAG-Index. Output: relevante Chunks. |
| **rag.reindex** | RIX | Baut RAG-Index aus Quelldateien neu auf. |

---

## Naming Conventions

- Rollen-IDs sind kebab-case: `canary-evaluator`, `vetting-analyst`
- Pipeline-Präfixe gruppieren zusammengehörige Rollen: `vetting-*`, `canary-*`
- Interne Dispatch-Skripte heißen: `<skill>-dispatch.sh`
- Schema-Dateien heißen: `<agent-name>.output.schema.json`

---

## Abgrenzung: Agent vs. Script vs. Skill

| Begriff | Definition |
|---------|-----------|
| **Skill** | Fachdomäne + zugehörige Dateien (SKILL.md, agents/, scripts/, contracts/) |
| **Agent** | Semantische Rolle innerhalb eines Skills; beschrieben in `agents/*.md` |
| **Script** | Deterministisches Shell/Python-Script; kein LLM-Aufruf nötig |
| **Dispatcher** | Script, das Agents koordiniert; validiert Schema-Outputs |
