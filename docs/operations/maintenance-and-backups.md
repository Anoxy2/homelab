# Wartung

## Bereits umgesetzt (Stand 2026-04)

Diese Punkte sind bereits live und gehoeren nicht mehr in den offenen Arbeits-Backlog:

- Skill-Manager Entkopplung: fachliche Skill-Nutzung ueber `~/scripts/skills`, Lifecycle/Governance ueber `~/scripts/skill-forge`
- Coding-Pipeline aktiv: Planner -> Coder -> Reviewer, inkl. `pending-review` bei No-Go
- Semantisches Vetting als Opt-in aktiv: `vet --semantic`
- Canary-Evaluation aktiv: `canary evaluate <slug>` mit Approver-Output und Freeze-Beruecksichtigung
- Canary-Promote-Logging gehaertet: Evaluationsdetails nur bei erfolgreicher Evaluationsantwort im Audit
- Authoring ausgelagert: eigener Authoring-Skill mit Wrapper-Anbindung
- Git Pre-Commit Hook gegen Secret-Commits ist aktiv und dokumentiert
- CHANGELOG-Konvention aktiv
- Update-Flow gehaertet: Re-Vetting vor finaler Aktivierung im Single-Update-Pfad

Details und Bedienlogik:
- `docs/skills/skill-forge-governance.md`
- `agent/skills/skill-forge/SKILL.md`
- `README.md`

## Images updaten

```bash
~/scripts/update-stacks.sh
```

Der Update-Flow validiert zuerst die Compose-Konfiguration, verlangt ein erfolgreiches Backup und bricht bei weniger als 2 GB freiem Speicher vor dem Pull ab. Ein fehlgeschlagener Post-Update-Health-Check fuehrt ebenfalls zu Exit `1`.

Manuell für einen einzelnen Service:
```bash
cd ~
docker compose pull mosquitto
docker compose up -d mosquitto
```

## Backup

```bash
~/scripts/backup.sh
```

Sichert alle `config/`-Ordner als `.tar.gz` nach `~/backups/YYYY-MM-DD/`.

Growbox-Tagebuch und Grow-Daten sind bereits in `~/growbox/` und werden mitgesichert.

## Restore

Restore immer in zwei Schritten: betroffenen Service stoppen, dann Archiv zurueckspielen.

```bash
# 1) Backup-Ordner ansehen
ls -lah ~/backups
ls -lah ~/backups/YYYY-MM-DD

# 2) Betroffenen Service stoppen
cd ~ && docker compose stop pihole

# 3) Zielverzeichnis leeren (optional, wenn kompletter Restore gewuenscht)
rm -rf ~/pihole/config/*

# 4) Archiv zurueckspielen
tar -xzf ~/backups/YYYY-MM-DD/pihole-config.tar.gz -C ~/pihole

# 5) Service starten und pruefen
cd ~ && docker compose up -d pihole
~/scripts/health-check.sh
```

Mappung der Backup-Dateien zu Zielpfaden:
- `pihole-config.tar.gz` -> `~/pihole/config/`
- `homeassistant-config.tar.gz` -> `~/homeassistant/config/`
- `esphome-config.tar.gz` -> `~/esphome/config/`
- `mosquitto-config.tar.gz` -> `~/mosquitto/config/`
- `tailscale-state.tar.gz` -> `~/tailscale/state/`
- `agent-skills.tar.gz` -> `~/agent/skills/`
- `openclaw-rag.tar.gz` -> `~/infra/openclaw-data/rag/`
- `openclaw-ui-state.tar.gz` -> `~/infra/openclaw-data/ui-state/`
- `influxdb-data.tar.gz` -> `~/influxdb/data/`

Wichtig:
- Immer nur den betroffenen Service stoppen, nicht blind alle Container.
- Kein Restore laufender Datenverzeichnisse bei aktivem Service.
- Nach Restore immer Funktionscheck mit `~/scripts/health-check.sh`.

## Restic Offsite-Backup

Offsite-Backups via Restic werden automatisch von `~/scripts/backup.sh` durchgeführt, wenn `RESTIC_REPOSITORY` und `RESTIC_PASSWORD` in `.env` gesetzt sind.

### Konfiguration

1. **Repository-URL wählen:**
   - Backblaze B2: `b2://bucketname:/pilab`
   - SFTP: `sftp://user@host:/pfad/zum/backup`
   - Lokaler Pfad (nicht empfohlen): `/pfad/zum/backup`

2. **.env konfigurieren:**
   ```bash
   # Kopiere .env.example als Vorlage (falls nicht vorhanden)
   cp .env.example .env
   
   # Bearbeite .env mit deinen Werten
   # RESTIC_REPOSITORY=b2://bucketname:/pilab
   # RESTIC_PASSWORD=... (ein sicheres, zufälliges Passwort)
   
   # Optional für B2:
   # B2_ACCOUNT_ID=...
   # B2_ACCOUNT_KEY=...
   
   # .env niemals committen!
   git checkout .env 2>/dev/null || true
   ```

3. **Restic-CLI installieren** (falls noch nicht vorhanden):
   ```bash
   # arm64-Version für Raspberry Pi 5
   sudo apt-get install -y restic
   ```

### Erstes Backup starten

```bash
# Repo initialisieren (nur beim ersten Mal nötig)
cd ~ && RESTIC_REPOSITORY="${RESTIC_REPOSITORY}" RESTIC_PASSWORD="${RESTIC_PASSWORD}" restic init

# Backup manuell ausführen
~/scripts/backup.sh

# Status prüfen
cd ~ && RESTIC_REPOSITORY="${RESTIC_REPOSITORY}" RESTIC_PASSWORD="${RESTIC_PASSWORD}" restic snapshots
```

Das Script lädt `RESTIC_REPOSITORY` und `RESTIC_PASSWORD` automatisch aus `.env`.

### Retention-Policy

Das Script hält standardmäßig:
- **7 tägliche** Snapshots
- **4 wöchentliche** Snapshots
- **3 monatliche** Snapshots

Anpassung falls nötig: `~/scripts/backup.sh` Zeilen ~115-120 bearbeiten.

### Offsite-Backup automatisieren

Das Backup läuft derzeit nur manuell. Für tägliche Automatisierung:

```bash
# Option 1: Systemd Timer erstellen
# (mit sudo)
sudo /home/steges/systemd/install-timer.sh backup

# Option 2: Oder manuell einen Cron-Job hinzufügen
# crontab -e → 0 2 * * * /home/steges/scripts/backup.sh

# Option 3: Heartbeat-Integration
# Der `heartbeat`-Skill könnte Restic-Checks automatisieren
```

### Restore aus Restic

```bash
# Snapshots auflisten
cd ~ && RESTIC_REPOSITORY="${RESTIC_REPOSITORY}" RESTIC_PASSWORD="${RESTIC_PASSWORD}" restic snapshots

# Einzelne Datei oder Ordner wiederherstellen
# ID: z.B. die Snapshot-ID (erste 8 Zeichen)
restic restore <ID> --target /tmp/restore-point

# Spezifischer Path
RESTIC_REPOSITORY="..." RESTIC_PASSWORD="..." restic restore <ID> --path /pihole/config --target ~/pihole-restore
```

### Monitoring

Restic-Fehler werden von `backup.sh` als `log_warn` protokolliert.  
Zum Prüfen:

```bash
# Logs der letzten Backup-Ausführung
tail -50 /var/log/syslog | grep -i restic

# Oder im Docker-Container (wenn backup.sh von cron/systemd dort läuft)
docker compose logs --tail=50 <service>
```

## Auth-Failure Monitor

```bash
# 24h Standardfenster
~/scripts/auth-failure-monitor.sh

# JSON für Automatisierung
~/scripts/auth-failure-monitor.sh --hours 24 --json

# Schwellwert anpassen
~/scripts/auth-failure-monitor.sh --hours 48 --threshold 10
```

## Unbound DNS-Checks

```bash
# Health-Status
cd ~ && docker compose ps unbound pihole

# Direkte Aufloesung ueber Unbound
dig +short @127.0.0.1 -p 5335 example.com

# Aufloesung ueber Pi-hole (nutzt Unbound-Upstream)
dig +short @127.0.0.1 -p 53 example.com
```

## Logs

```bash
# Logs eines Services live
cd ~ && docker compose logs -f pihole

# Mosquitto Logs
docker compose logs -f mosquitto
# oder direkt:
tail -f ~/mosquitto/log/mosquitto.log

# Nur letzte 100 Zeilen
docker compose logs --tail=100 homeassistant

# System-Journal
journalctl -u docker --since "1 hour ago"
```

## OpenClaw Config-Write Guard

Zum Schutz vor `openclaw.json` Race-Conditions (EBUSY beim Rename) alle schreibenden OpenClaw-Config-Operationen ueber den Guard ausfuehren:

```bash
# Beliebigen Write-Befehl serialisiert ausfuehren
~/scripts/openclaw-config-guard.sh run -- <kommando> <args...>

# Convenience: Login-Flow unter Lock
~/scripts/openclaw-config-guard.sh login-github-copilot
```

EBUSY-Rate messen/vergleichbar machen:

```bash
# Letzte 30 Tage
~/scripts/openclaw-config-guard.sh ebusy-rate 720

# Baseline 168h vs letzte 24h
~/scripts/openclaw-config-guard.sh compare 168 24
```

Referenzmessung (2026-04-06):
- Baseline (168h): `7/8` EBUSY (`0.875`)
- Recent (24h): `0/0` (`0.0`)
- Delta: `-0.875` (`improved_or_equal=true`)

## Docker aufräumen

```bash
# Ungenutzte Images entfernen (VORSICHT: erst prüfen was läuft)
docker image prune

# Volumes prüfen
docker volume ls

# Disk-Nutzung
docker system df
```

## Docker Memory-Limits verifizieren

Bei ungewoehnlicher Speichernutzung oder nach Compose-Aenderungen Limits aktiv pruefen:

```bash
docker inspect --format '{{.Name}} mem={{.HostConfig.Memory}} reservation={{.HostConfig.MemoryReservation}}' openclaw homeassistant
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}' openclaw homeassistant
```

Referenzbefund (2026-04-04):
- `openclaw` wurde neu erstellt und laeuft seitdem mit `1GiB` Limit und `256MiB` Reservation.
- `homeassistant` laeuft mit `800MiB` Limit und `300MiB` Reservation.

## NVMe-Gesundheit

```bash
sudo smartctl -a /dev/nvme0n1
```

Automatisierung:
- `~/scripts/health-check.sh` prueft den SMART-Health-Status direkt (`PASSED` erwartet, sonst Alert/Exit-Fail).
- `~/scripts/skills heartbeat` fuehrt zusaetzlich einen woechentlichen SMART-Check aus und schreibt eine Kurzzeile in die Telegram-Heartbeat-Zusammenfassung.

## Systemd Timer

Laufende Timer prüfen:
```bash
systemctl list-timers
```

RAG-Automation (neu):

```bash
# Unit-Dateien installieren/aktivieren (einmalig, mit sudo)
sudo cp ~/systemd/rag-reindex-daily.service /etc/systemd/system/
sudo cp ~/systemd/rag-reindex-daily.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now rag-reindex-daily.timer

# Status prüfen
systemctl status rag-reindex-daily.timer
systemctl list-timers | grep rag-reindex-daily
```

Zeitfenster:
- taeglich `04:30 Europe/Berlin`
- zusaetzliche Jitter-Streuung: `RandomizedDelaySec=10min`
- kollisionsarm zu bestehendem `nightly-self-check` (`03:15`) und Heartbeat (`07:00/19:00`)

## Shell-Script-Tests (bats)

Lokal verfuegbare Regression-Tests fuer Wartungsskripte:

```bash
bats ~/scripts/tests/health-check.bats ~/scripts/tests/backup.bats
```

Aktuell enthalten:
- `health-check.bats`: prueft Exit-Code 0 bei healthy Stubs und Exit-Code 1 bei einem Probe-Fehler.
- `backup.bats`: prueft Archiv-Erzeugung auf Mock-Verzeichnissen und Skip-Verhalten bei fehlendem Source-Ordner.

## RAG Retrieval / Reindex (Timeout + Fallback)

Standardisierte RAG-Kommandos ueber den Skills-Wrapper:

```bash
~/scripts/skills rag retrieve "openclaw heartbeat" --limit 5 --timeout-ms 1500 --json
~/scripts/skills rag reindex --changed-only --timeout-seconds 600 --json
```

Hinweise:
- `retrieve` faellt von FTS auf LIKE zurueck und nutzt bei Bedarf den neuesten Snapshot-Index.
- `reindex` ist per Lock serialisiert, hat ein Timeout und kann bei Index-Integritaetsfehler auf Snapshot zurueckfallen.
- Nach erfolgreichem Ingest + `quick_check` laeuft verpflichtend ein Post-Reindex-Canary-Gate; nur bei `passed=true` gilt der Lauf als erfolgreich.
- Bei Gate-Fehler wird automatisch auf den letzten Snapshot zurueckgerollt (falls vorhanden).
- Deutsche Query-Rewrites sind im Retriever hinterlegt (z. B. `ausfall -> down|stoerung|recovery`, `wiederherstellung -> recovery|restore|rollback`).
- Neue Growbox-Diary-Eintraege werden im Reranking zusaetzlich nach Aktualitaet bevorzugt (`heute > gestern > letzte 3 Tage > letzte 7 Tage`).

Vertiefter RAG-Health-Check (`~/scripts/health-check.sh`):
- Reindex-State aus `infra/openclaw-data/rag/.reindex.status` (FAIL bei `state=failed`)
- Chunk/FTS-Drift (`chunks` vs `chunks_fts`) mit klaren FAIL-Schwellen
- Sanity-Query gegen `retrieve.py` (mindestens ein Treffer, `search_mode != none`)

Gold-Set / Qualitaetsmessung:

```bash
python3 ~/agent/skills/openclaw-rag/scripts/evaluate-goldset.py --limit 5 --timeout-ms 1500
```

Referenzmessung (2026-04-06):
- Gold-Set Fragen: `20`
- avg Precision@5: `0.32`
- avg Recall@5: `0.625`
- p95-Latenz: `70.28ms`

RAG Ingest Backpressure / Resume:

```bash
python3 ~/agent/skills/openclaw-rag/scripts/ingest.py --changed-only --max-chunks-per-run 10 --json
python3 ~/agent/skills/openclaw-rag/scripts/ingest.py --changed-only --resume --max-chunks-per-run 10 --json
cat ~/infra/openclaw-data/rag/ingest-state.json
```

- `--max-chunks-per-run` begrenzt den Lauf hart auf ein Chunk-Budget.
- Bei Ueberlauf speichert `ingest.py` `current_source`, `next_chunk_offset` und `remaining_sources` in `infra/openclaw-data/rag/ingest-state.json`.
- `--resume` setzt exakt an diesem Chunk-Offset fort.

RAG Canary Smoke:

```bash
~/agent/skills/openclaw-rag/scripts/rag-canary-smoke.sh --json
```

- Nutzt das Gold-Set als Canary-Gate fuer Retrieval-Aenderungen.
- Default-Gates: `precision@5 >= 0.25`, `recall@5 >= 0.55`, `p95 <= 200ms`.

## Kernel Tuning (VM)

Swappiness ist auf `10` gesetzt, damit der Pi bei Server-Workload weniger aggressiv auf Swap ausweicht:

```bash
sysctl vm.swappiness
```

Konfiguration liegt in `/etc/sysctl.conf` (`vm.swappiness=10`).

## Mosquitto Passwort-Verwaltung

```bash
# Neuen User anlegen
docker exec mosquitto mosquitto_passwd /mosquitto/config/passwd neueruser

# Passwort ändern
docker exec mosquitto mosquitto_passwd /mosquitto/config/passwd iot

# User löschen
docker exec mosquitto mosquitto_passwd -D /mosquitto/config/passwd iot
```

## ESP32 / Growbox

```bash
# Flash über ESPHome UI
# http://192.168.2.101:6052 → growbox_wlan → Install

# OTA-Update (nach erstem USB-Flash)
# Automatisch über ESPHome UI oder:
esphome run ~/esphome/config/growbox_wlan.yaml
```

Growbox-Status prüfen:
```bash
# HA API (HA_TOKEN aus .env)
curl -s -H "Authorization: Bearer $HA_TOKEN" \
  http://192.168.2.101:8123/api/states/sensor.growbox_temperatur | python3 -m json.tool
```

## ESPHome secrets.yaml Rotation

Bei Passwort-Änderung (OTA, MQTT, WiFi) in `~/esphome/config/secrets.yaml` anpassen,
dann ESP32 neu flashen. Datei ist nicht per Samba sichtbar (liegt auf Pi).

## Skill-Manager Wartung

### Daily Check (empfohlen morgens)

```bash
~/scripts/skill-forge policy lint
~/scripts/skills heartbeat
~/scripts/skill-forge status
```

### Nightly Self-Check (read-only)

```bash
~/scripts/nightly-check.sh
```

Prueft non-destruktiv:
- `policy lint`
- `health-check.sh`
- stale canaries (`status=running` laenger als 72h)
- `pending-review` Backlog in `known-skills.json`

Bei Problemen endet das Skript mit Exit `1` und sendet optional eine Telegram-Zusammenfassung, wenn `TELEGRAM_BOT_TOKEN` und `TELEGRAM_CHAT_ID` gesetzt sind.

Systemd-Vorlagen fuer den Nachtlauf liegen in:
- `systemd/nightly-self-check.service`
- `systemd/nightly-self-check.timer`

Validierung lokal:

```bash
bats ~/scripts/tests/nightly-check.bats
systemd-analyze verify ~/systemd/nightly-self-check.service ~/systemd/nightly-self-check.timer
```

Optionaler Weekly-Runbook-Check:

```bash
~/scripts/skills runbook-maintenance weekly-check
```

### Security Check

```bash
~/scripts/skill-forge audit --rejected
~/scripts/skill-forge blacklist promote
```

### Incident Handling

```bash
~/scripts/skill-forge incident freeze on
~/scripts/skill-forge status
~/scripts/skill-forge audit --rejected
# Nach manueller Prüfung:
~/scripts/skill-forge incident freeze off
```

Passende Basis-Runbooks fuer Stoerungen:
- `docs/runbooks/pihole-dns-ausfall.md`
- `docs/runbooks/openclaw-nicht-erreichbar.md`
- `docs/runbooks/esp32-offline.md`

### Skill Lifecycle Operations

```bash
~/scripts/skill-forge install <slug> <source> <version> <score>
~/scripts/skill-forge update --all
~/scripts/skill-forge rollback <slug>
~/scripts/skill-forge canary status <slug>
```

## RAG Operations

Index und Retrieval laufen lokal auf SQLite.

```bash
# Voller Neuaufbau des RAG-Index
python3 ~/agent/skills/openclaw-rag/scripts/ingest.py --json

# Inkrementeller Reindex geaenderter Quellen
~/agent/skills/openclaw-rag/scripts/reindex.sh

# Ad-hoc Abfrage gegen den Index
python3 ~/agent/skills/openclaw-rag/scripts/retrieve.py "Welche Zielwerte gelten fuer die Growbox-Luftfeuchtigkeit?"

# Schneller DB-Check mit sqlite3
sqlite3 ~/infra/openclaw-data/rag/index.db 'select count(*) as chunks, count(distinct source) as quellen from chunks;'
```

Hilfreiche Referenzen:
- `~/agent/skills/openclaw-rag/ARCHITECTURE.md`
- `~/agent/skills/openclaw-rag/RAG-SOURCES.md`
- `~/agent/skills/openclaw-rag/TEST-QUESTIONS.md`
- `docs/operations/canvas-smoke-checklist.md`
- `docs/runbooks/rag-qualitaetsreport-samstag.md`
- `docs/runbooks/rag-reindex-failure-recovery.md`

### RAG Betriebs-Metriken

Fuer den laufenden Betrieb werden diese Metriken verwendet:
- Precision@5
- Recall@5
- p95-Latenz
- Index-Freshness (Alter der `index.db` in Stunden)

Hinweis:
- `~/scripts/health-check.sh` enthaelt einen Freshness-Alert, wenn `index.db` aelter als 48h ist.
- `~/agent/skills/openclaw-rag/scripts/reindex.sh` erstellt vor Reindex taeglich einen Snapshot unter `~/infra/openclaw-data/rag/snapshots/index.db.YYYY-MM-DD` und behaelt die letzten 7.
- Nach jedem Reindex schreibt das Script eine Action-Log-Zeile mit `index_checksum` nach `~/infra/openclaw-data/action-log.jsonl`.
- `~/scripts/backup.sh` packt den Snapshot-Ordner als eigenes Archiv (`openclaw-rag-snapshots.tar.gz`).
- Growbox-Diary-Dateien unter `~/growbox/diary/*.md` werden durch die bestehende Growbox-Source automatisch mit indexiert.

## Growbox Diary Automation

- `~/agent/skills/skill-forge/scripts/growbox-diary.sh` erstellt taeglich genau einen Eintrag unter `~/growbox/diary/DD.MM.YYYY.md`, wenn noch kein Tagesfile vorhanden ist.
- Trigger kommt aus `skills heartbeat`; der Heartbeat schreibt dazu Audit- und Action-Log-Eintraege (`daily_diary_entry`).
- Woechentliche Fotoablage liegt unter `~/growbox/diary/photos/` im Schema `DD.MM.YYYY.jpg` (siehe `~/growbox/diary/photos/README.md`).
- `growbox-daily-report.sh` enthaelt einen Hinweis, wenn seit mehr als 7 Tagen kein neues Foto vorhanden ist.

### ARM64 RAG Gotchas (Pi 5)

- `rag-embed` wird lokal gebaut (kein vorgebautes Image im Compose), daher kann der erste Build auf ARM64 deutlich laenger dauern.
- Der Build benoetigt Python-Build-Tooling (`build-essential`) und installiert `torch` plus `sentence-transformers`; ohne stabile Internetverbindung schlagen `pip`-Schritte oft spaet fehl.
- Nach Dependency-Updates immer den Container explizit neu bauen/starten:
  ```bash
  cd ~
  docker compose build rag-embed
  docker compose up -d rag-embed
  ```
- Health-Check fuer `rag-embed` pruefen:
  ```bash
  docker compose ps rag-embed
  curl -sf http://192.168.2.101:18790/health
  ```
- Bei OOM-/Performance-Problemen zuerst parallel laufende schwere Tasks vermeiden (z. B. grosse Updates + Reindex gleichzeitig), da das Embedding-Setup auf ARM64 RAM-intensiv sein kann.

## OpenClaw Update Playbook (RAG/UI Skills)

Pre-Update:
```bash
~/scripts/skill-forge policy lint
~/scripts/skill-forge health
~/scripts/skill-forge budget
~/scripts/backup.sh
```

Update:
```bash
# OpenClaw Stack aktualisieren (compose oder bestehender Update-Flow)
cd ~ && docker compose pull openclaw
cd ~ && docker compose up -d openclaw
```

Post-Update:
```bash
~/scripts/skill-forge status
~/scripts/skill-forge canary status openclaw-rag
~/scripts/skill-forge canary status openclaw-ui
```

Danach:
- RAG-Testfragen aus `agent/skills/openclaw-rag/TEST-QUESTIONS.md` gegen Quellen verifizieren.
- UI-Smoketest fuer Canvas (Status, Action-Feedback, Fehlerpfade) durchfuehren.
- Bei Regression: gezielter Rollback je Skill und optional `incident freeze on`.

Siehe auch: `docs/openclaw/openclaw-skill-release-checklist.md`

## OpenClaw Autostart beim Pi-Boot

Systemd Unit (im Repo): `systemd/openclaw-compose.service`

Installer ausfuehren:
```bash
cd ~
./scripts/install-openclaw-autostart.sh
```

Manuelle Befehle:
```bash
sudo systemctl daemon-reload
sudo systemctl enable openclaw-compose.service
sudo systemctl start openclaw-compose.service
sudo systemctl status openclaw-compose.service
```

Pruefen nach Reboot:
```bash
docker ps | grep openclaw
sudo systemctl is-enabled openclaw-compose.service
```

## Git Pre-Commit Hook

Lokaler Schutz gegen versehentlich gestagte Secret-Dateien:

```bash
git diff --cached --name-only | grep -E '(^|/)\.env$|(^|/)secrets\.yaml$|(^|/)passwd$'
```

Der Hook liegt in `.git/hooks/pre-commit` und blockiert Commits, wenn eine der folgenden Dateien im Index liegt:
- `.env`
- `secrets.yaml`
- `passwd`

Wenn der Hook anschlaegt:
```bash
git restore --staged <pfad>
```

## Changelog-Konvention

Root-Datei: `CHANGELOG.md`

Format:
```md
## YYYY-MM-DD
- kurze, konkrete Aenderung
- kurze, konkrete Aenderung
```

Vor jedem bewussten Git-Commit einen kurzen Eintrag ergaenzen. Ziel ist ein knapper Verlauf von manuellen und autonomen Aenderungen.

### Writer Operations

```bash
~/scripts/skill-forge writer docs "Runbook ..."
~/scripts/skill-forge writer code "helper ..."
~/scripts/skill-forge writer config "compose tweak ..."
~/scripts/skill-forge writer test "smoke test ..."
```
