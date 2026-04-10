# Shell-Safety-Referenz — coding skill

## Pflicht-Preamble für alle Shell-Scripts

Jedes generierte `.sh`-Script beginnt mit:

```bash
#!/bin/bash
set -euo pipefail
```

| Option | Bedeutung |
|--------|-----------|
| `-e` | Script bricht bei erstem Fehler ab (exit code != 0) |
| `-u` | Ungesetzte Variablen sind ein Fehler |
| `-o pipefail` | Pipeline schlägt fehl wenn irgendein Befehl darin fehlschlägt |

Ohne dieses Preamble können Fehler unbemerkt durchlaufen — kritisch auf einem 24/7-Pi.

## Forbidden Patterns

| Pattern | Kategorie | Grund |
|---------|-----------|-------|
| `rm -rf /` | Destructive FS | Löscht gesamtes Root-Filesystem |
| `rm -rf ~` | Destructive FS | Löscht gesamtes Home-Verzeichnis |
| `rm -rf /home` | Destructive FS | Löscht alle User-Daten |
| `rm -f` ohne expliziten, engen Pfad | Destructive FS | Zu breite Lösch-Scope |
| `reboot` | Host-Disruption | Pi ist 24/7 — unerwarteter Neustart bricht alle Dienste |
| `shutdown` | Host-Disruption | Wie reboot |
| `systemctl poweroff` | Host-Disruption | Wie reboot |
| `docker system prune -a` | Docker-Purge | Löscht auch Images laufender Dienste |
| `docker system prune` ohne `-f` Guard | Docker-Purge | Interaktive Bestätigung umgehbar |
| `curl <url> \| bash` | Remote Code Exec | Ungeprüften Fremdcode direkt ausführen |
| `wget <url> \| sh` | Remote Code Exec | Wie curl pipe |
| `eval $(<cmd>)` | Code Injection | Dynamische Ausführung ohne Validierung |
| `eval "<string>"` | Code Injection | String-basierte Ausführung |
| `PASSWORD=<literal>` | Hardcoded Credential | Klartext-Credential im Script |
| `TOKEN=<literal>` | Hardcoded Credential | Wie PASSWORD |
| `API_KEY=<literal>` | Hardcoded Credential | Wie PASSWORD |
| `SECRET=<literal>` | Hardcoded Credential | Wie PASSWORD |
| `> .env` | Credential-Write | Überschreibt Secrets-File |
| `>> .env` | Credential-Write | Appended an Secrets-File |
| `tee .env` | Credential-Write | Wie > .env |
| `npm install -g` | System-Install | System-weites Package ohne explizite Erlaubnis |
| `pip install` (ohne `--user` oder venv) | System-Install | Wie npm -g |
| `apt install` ohne Script-Kontext | System-Install | Nur im Installations-Script erlaubt |

## Pi-spezifische Regeln (aarch64)

- Alle Docker-Images müssen `arm64` supporten — kein implizites `amd64`
- `vcgencmd measure_temp` ist nur auf dem Pi verfügbar — Script muss mit `command -v vcgencmd` prüfen
- Keine x86-only Binaries (z.B. `i386`-Pakete)
- `DOCKER_DEFAULT_PLATFORM` niemals auf `linux/amd64` setzen

## Credential-Referenz (sicher)

Credentials werden aus Umgebungsvariablen oder `.env` gelesen, niemals hardcoded:

```bash
# Richtig:
HA_TOKEN="${HA_TOKEN:?HA_TOKEN not set}"
MQTT_PASS="${MQTT_PASS:?MQTT_PASS not set}"

# Falsch:
HA_TOKEN="abc123xyz"
```

## Bekannte sichere Pfade auf diesem Pi

```
/home/steges/               # Arbeitsverzeichnis
/home/steges/scripts/       # Utility-Scripts
/home/steges/agent/         # Agent-Workspace
/home/steges/growbox/       # Growbox-Daten (read-only für generierte Scripts)
```

Schreiben außerhalb von `/home/steges/` erfordert immer explizite Begründung.
