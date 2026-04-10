# Experimente & PoCs

> Laufende und abgeschlossene Experimente  
> Was funktioniert, was nicht, Lessons Learned

---

## ✅ Abgeschlossene Experimente

### [2026-04-10] Backup-Automation mit skill-forge

**Hypothese:** Skill-Forge Template ermöglicht saubere Skill-Struktur mit Abhängigkeiten

**Setup:**
- github-automation Skill (basierend auf steipete/github)
- backup-automation Skill (nutzt github-automation)
- USB + GitHub Dual-Backup Strategie

**Ergebnis:** ✅ **Erfolgreich**

```bash
# Funktioniert:
backup-full.sh → ruft github-automation/scripts/*.sh auf
```

**Learnings:**
- Skill-Dependencies funktionieren über relative Pfade
- Separieren von GitHub- und USB-Logik ist sauber
- systemd Integration mit Timern ist robust

**Dokumentation:** `docs/infrastructure/backup-automation-skill.md`

---

### [2026-04-01] Pi 5 NVMe Boot Migration

**Hypothese:** Pi 5 kann nativ von NVMe booten ohne SD-Karte

**Setup:**
- Pi 5 8GB + Crucial P3 1TB NVMe
- PCIe HAT für M.2
- Raspberry Pi Imager für NVMe

**Ergebnis:** ✅ **Erfolgreich**

**Learnings:**
- Boot-Order in EEPROM: NVMe before USB
- `nvme_boot` Device Tree Overlay
- Deutlich schneller als SD-Karte

**Dokumentation:** `docs/infrastructure/firmware-boot.md`

---

### [2026-03-15] OpenClaw RAG Gold-Set

**Hypothese:** Self-referential RAG verbessert Skill-Qualität

**Setup:**
- openclaw-rag Skill scannt eigene docs
- GOLD-SET.json definiert kanonische Dokumente
- Chunk-basierte Embedding-Suche

**Ergebnis:** ✅ **Erfolgreich**

**Learnings:**
- Dokumentation muss strukturiert sein (YAML Frontmatter)
- GOLD-SET.json zentrale Wahrheitsquelle
- Reindex nach jeder Doc-Änderung nötig

**Dokumentation:** `docs/openclaw/openclaw-architecture.md`

---

## 🔄 Laufende Experimente

### [2026-04-10] USB-ZFS Evaluation

**Hypothese:** ZFS auf USB-Stick bietet bessere Datenintegrität als ext4

**Status:** 🟡 **Geplant**

**Setup:**
```bash
# Geplant:
sudo apt install zfsutils-linux
sudo zpool create usb-backup /dev/sda
sudo zfs set compression=lz4 usb-backup
sudo zfs set atime=off usb-backup
```

**Offene Fragen:**
- USB-Stick Performance mit ZFS?
- Snapshot-Retention vs. rsync-hartlinks?
- Boot-zeit ZFS-Import?

---

### [2026-04-01] n8n vs. Custom Scripts

**Hypothese:** Custom Scripts sind wartbarer als n8n Workflows

**Status:** ✅ **Entscheidung getroffen**

**Ergebnis:** ❌ **n8n verworfen**, Custom Scripts bevorzugt

**Gründe:**
- Bash/Scripts versionierbar in Git
- Keine GUI-Abhängigkeit
- Einfacher zu debuggen
- Weniger Ressourcenverbrauch

**Dokumentation:** `docs/decisions/automation-decision-n8n.md`

---

## ❌ Gescheiterte Experimente

### [2026-03-01] Unbound als DNS-Resolver

**Hypothese:** Unbound ersetzt Pi-hole für DNS

**Setup:**
- Unbound Container
- Root-Hints für rekursive Queries
- Pi-hole als Forwarder testweise deaktiviert

**Ergebnis:** ❌ **Abgebrochen**

**Probleme:**
- Komplexere Blocklist-Verwaltung
- Kein schönes Dashboard wie Pi-hole
- Mehr Wartung für gleichen Nutzen

**Entscheidung:** Pi-hole bleibt primärer DNS

**Dokumentation:** `docs/decisions/unbound-evaluation.md`

---

### [2026-02-15] Immich statt Synology Photos

**Hypothese:** Immich kann Synology Photos ersetzen

**Status:** 🟡 **Evaluierung pausiert**

**Probleme:**
- Hoher RAM-Verbrauch (4GB+)
- Pi 5 zu schwach für ML-Features
- Face Recognition braucht GPU

**Entscheidung:** Warten auf bessere Hardware oder leichtere Alternative

**Dokumentation:** `docs/decisions/immich-evaluation.md`

---

## 📝 Lessons Learned

### Was immer funktioniert

1. **Bash Scripts** – Einfach, debuggbar, versionierbar
2. **systemd Timers** – Zuverlässiger als Cron
3. **JSON Output** – Maschinenlesbar für weitere Verarbeitung
4. **Docker Compose** – Ein Stack-File, alle Services

### Was oft scheitert

1. **Über-Engineering** – KISS Prinzip vergessen
2. **Zu viele neue Tools** – Jeden Monat ein neues Buzzword-Tool
3. **Perfect is enemy of good** – Iterativ verbessern, nicht perfektionieren
4. **Keine Dokumentation** – 3 Wochen später vergessen

### Goldene Regeln

```
1. Wenn es läuft, rühr es nicht an
2. Änderungen dokumentieren VOR dem Experiment
3. Rollback-Plan immer parat
4. Ein Experiment = eine Variable ändern
```

---

## 🔮 Nächste Experimente

| Experiment | Status | Ziel-Datum |
|------------|--------|------------|
| ZFS on USB | 🟡 Geplant | April 2026 |
| UPS graceful shutdown | 🟡 Geplant | Mai 2026 |
| Kanidm SSO | 🔵 Idee | Q3 2026 |
| K3s statt Docker | 🔵 Idee | Q4 2026 |
| NixOS Evaluation | 🔵 Idee | 2027 |

---

## 🔗 Verweise

- `docs/decisions/` – Architektur-Entscheidungen
- `docs/Ideen/future-projects.md` – Projekt-Roadmap
