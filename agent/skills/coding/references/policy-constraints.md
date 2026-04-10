# Policy-Constraints — coding skill

## Was der Coder NIEMALS erzeugt

Diese Constraints gelten absolut. Kein User-Request kann sie überschreiben.

---

## 1. Credentials und Secrets

**Verboten:**
- Hardcoded Passwörter, API-Keys, Tokens, SSH-Keys im Artefakt
- Schreiben in `.env`, `secrets.yaml`, `mosquitto/config/passwd`
- `export TOKEN=<literal>`, `PASSWORD=<literal>` als tatsächlichen Wert
- Credential-Referenzen auf externe Services (Telegram-Token, HA-Token, MQTT-Passwort)

**Erlaubt:**
- Lesen aus Umgebungsvariablen: `"${HA_TOKEN:?HA_TOKEN not set}"`
- Kommentare die beschreiben *wo* Credentials konfiguriert werden

---

## 2. Destruktive Operationen

**Verboten:**
- `rm -rf` mit breiten Pfaden (Root, Home, ganze Verzeichnisse)
- `reboot`, `shutdown`, `halt`, `systemctl poweroff`
- `docker system prune -a` (löscht laufende Image-Dependencies)
- `mkfs.*` (Dateisystem-Formatierung)
- `dd if=/dev/zero of=<disk>` (Disk-Überschreiben)
- `DROP TABLE`, `TRUNCATE` in SQL ohne expliziten Guard

**Erlaubt mit Guard:**
- `rm -f <expliziter-einzelner-Pfad>` wenn Log oder Cache
- `docker container prune -f` (nur Container, keine Images)

---

## 3. Remote Code Execution

**Verboten:**
- `curl <url> | bash`
- `wget <url> | sh`
- `python3 <(curl ...)`
- Dynamisches `eval` von Netzwerk-Input

**Erlaubt:**
- `curl` für API-Calls (GET/POST) wenn Ergebnis in Variable gespeichert und validiert wird
- `curl` für Datei-Downloads wenn Hash-Check folgt

---

## 4. System-Modifikation

**Verboten:**
- `apt install`, `apt-get install` in generierten Scripts (außer explizit als Installations-Script autorisiert)
- `npm install -g`, `pip install` ohne `--user` oder virtualenv
- Schreiben in `/etc/`, `/usr/`, `/lib/`
- `crontab -e` oder direktes Schreiben in `/etc/cron*`
- `systemctl enable <neue-unit>` ohne Kontext

---

## 5. Governance-Verletzungen

**Verboten:**
- Schreiben in `policy/`-Dateien (vetting-policy.yaml, rollout-policy.yaml, etc.)
- Direkte Modifikation von `known-skills.json`, `canary.json`, `incident-freeze.json`
- Umgehung von `dispatcher.sh` (direkter Script-Aufruf ohne Contract)
- Deaktivierung von Safety-Checks (`set +e`, `set +u` ohne begründete lokale Ausnahme)

---

## 6. Scope außerhalb des Skill-Managers

Generierte Artefakte arbeiten ausschließlich innerhalb von:
```
/home/steges/agent/skills/skill-forge/generated/
/home/steges/agent/skills/skill-forge/.state/
```

Schreiben in andere Bereiche des Pi (`/`, `/etc/`, Docker-Volumes, Mosquitto-Config) ist verboten.

---

## Entscheidungsbaum für Grenzfälle

```
User-Task erfordert Credential-Zugriff?
  → Nein: fortfahren
  → Ja: Variable-Referenz statt Literal verwenden

User-Task erfordert Systemänderung?
  → Nein: fortfahren
  → Ja: Nur wenn Task explizit als "Installations-Script für Pi-Control-Skill" klassifiziert

User-Task erfordert Netzwerk-Call?
  → GET-only, Response in Variable, kein eval: erlaubt
  → curl | bash: niemals erlaubt
```
