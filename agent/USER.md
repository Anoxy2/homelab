---
title: "USER Template"
summary: "User profile record"
read_when:
  - Bootstrapping a workspace manually
last_reviewed: "2026-04-06"
---

# USER.md - About Your Human

_Learn about the person you're helping. Update this as you go._

- **Name:** steges (Tobias)
- **What to call them:** steges
- **Pronouns:** _(nicht angegeben)_
- **Timezone:** Europe/Berlin
- **Language:** Bevorzugt Deutsch, Englisch geht auch
- **Communication style:** Direkte, knappe Antworten – kein Smalltalk, kein Filler. Klarer Fokus auf Ergebnisse.
- **Notes:** Hat den Skill-Manager für den Agenten gebaut (Pfad: /home/steges/agent/skills/skill-forge, CLI: /home/steges/scripts/skill-forge). "Nanobot" ist nur der aktuelle Telegram-Anzeigename; System bleibt OpenClaw.

## Context

Homelab-Admin. Betreibt einen Raspberry Pi 5 (pilab, 192.168.2.101) headless mit Docker.
Hauptprojekte: Pi-hole (DNS/DHCP/Adblocker), Home Assistant (Smart Home), ESPHome (ESP32/ESP8266), Tailscale (VPN), OpenClaw AI Gateway.

Kommuniziert per Telegram + HTTP-Gateway (Port 18789).
Schätzt es wenn Dinge einfach funktionieren und der Agent proaktiv Probleme meldet.

## Beobachtetes Aktivitätsmuster (Stand 2026-04-06)

- Arbeitet aktiv an OpenClaw / Skill-Manager Governance und Pi-Infrastruktur.
- Growbox-Pflege täglich (Diary-Einträge am 05.04 und 06.04.2026 sichtbar).
- Session-Start heute (06.04): umfangreiche Skill-Manager-Improvements und Dokumentation.
- Canvas-UI und CHANGELOG werden activ gepflegt (letzte Änderung: heute).
- Hauptaktivitäten laufen über VS Code SSH → Pi5; Agent-Interaktion via Telegram.
- Telegram-Chat-ID: 2011062206 (konfiguriert, aktiv genutzt).

## Arbeitsweise

- Bevorzugt: erst implementieren, dann validieren, dann dokumentieren.
- Todo-Listen werden als Open-Work-Only geführt (keine `[x]`-Sammlung).
- Wenn ein neues Todo erfasst oder ein Todo geaendert werden soll, immer in `/home/steges/docs/operations/open-work-todo.md` arbeiten.
- Keine neuen Todo-Markdown-Dateien unter `/home/steges/agent/` erstellen.
- Skill-Manager-Änderungen erfordern Lint + Syntax-Check + Smoke vor Todo-Entfernung.
- Bei Unsicherheiten: lieber fragen als raten.
