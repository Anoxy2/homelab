# Skill-Ideen & Backlog

> Neue Skills und Verbesserungen für OpenClaw  
> Priorisiert nach Impact und Aufwand

---

## 🎯 Priorisierung

| Prio | Bedeutung |
|------|-----------|
| 🔴 Kritisch | Blockiert andere Arbeit, sofort angehen |
| 🟡 Hoch | Wichtig für nächste Meilensteine |
| 🟢 Mittel | Nice-to-have, wenn Zeit |
| ⚪ Niedrig | Idee für später |

---

## 🔴 Kritisch (Next)

### ups-monitor

**Zweck:** APC UPS Status, graceful shutdown bei Stromausfall

**Tools:**
- `ups.status` – Batterie-Level, Status
- `ups.shutdown` – Geplantes Herunterfahren
- `ups.alert` – Niedriger Batterie-Alarm

**Technologie:** apcupsd oder NUT (Network UPS Tools)

**Aufwand:** 2-3h

**Impact:** ⭐⭐⭐⭐⭐ (Verhindert Datenkorruption)

---

## 🟡 Hoch (Q2 2026)

### zfs-admin

**Zweck:** ZFS Pool Management, Snapshots, Scrub

**Tools:**
- `zfs.status` – Pool Health
- `zfs.snapshot` – Snapshot erstellen
- `zfs.rollback` – Zu Snapshot zurück
- `zfs.scrub` – Integrity Check

**Abhängigkeit:** ZFS Experiment muss erfolgreich sein

**Aufwand:** 4-6h

---

### cloud-sync

**Zweck:** Offsite Backup zu S3/Backblaze/Storj

**Tools:**
- `cloud.sync` – Rclone Sync
- `cloud.status` – Sync-Status
- `cloud.verify` – Remote-Backup Check

**Technologie:** rclone

**Aufwand:** 4h

---

### smart-monitor

**Zweck:** NVMe/SATA SMART Health Monitoring

**Tools:**
- `smart.nvme` – NVMe Health
- `smart.temperature` – Temperatur-Tracking
- `smart.alert` – Wearout Warning

**Technologie:** smartmontools

**Aufwand:** 3h

---

## 🟢 Mittel (Q3 2026)

### docker-gc

**Zweck:** Automated Docker Cleanup

**Tools:**
- `docker.prune` – Images, Volumes, Networks
- `docker.stats` – Ressourcen-Nutzung
- `docker.health` – Container Health Check

**Aufwand:** 2h

---

### network-scan

**Zweck:** Nmap Integration, Geräte Discovery

**Tools:**
- `net.discover` – LAN Scan
- `net.device` – Gerätedetails
- `net.portscan` – Port-Scan

**Aufwand:** 3h

---

### cert-manager

**Zweck:** Let's Certificate Monitoring

**Tools:**
- `cert.status` – Alle Zertifikate
- `cert.expiry` – Ablaufdaten
- `cert.renew` – Manuelles Renewal

**Aufwand:** 2h

---

## ⚪ Niedrig (Backlog)

### weather-local

**Zweck:** Lokale Wetterstation (BME280 Sensor)

**Tools:**
- `weather.now` – Aktuelle Werte
- `weather.history` – Historische Daten
- `weather.alert` – Temperatur-Alerts

---

### power-monitor

**Zweck:** Stromverbrauch messen (Shelly Plug)

**Tools:**
- `power.now` – Aktueller Verbrauch
- `power.daily` – Tagesverbrauch
- `power.cost` – Kostenschätzung

---

### printer-admin

**Zweck:** Drucker Management (CUPS)

**Tools:**
- `printer.status` – Status aller Drucker
- `printer.queue` – Print Queue
- `printer.cancel` – Job abbrechen

---

## 🔧 Skill-Verbesserungen (Existing)

### backup-automation v2

**Verbesserungen:**
- [ ] ZFS Snapshot Support
- [ ] Cloud-Tier (S3/Backblaze)
- [ ] Backup-Retention Policies
- [ ] Backup-Encryption

**Status:** 🟡 Geplant

---

### github-automation v2

**Verbesserungen:**
- [ ] PR Management (list, create, merge)
- [ ] GitHub Actions Trigger
- [ ] Release Management
- [ ] Branch Protection Checks

**Status:** ⚪ Backlog

---

### health v2

**Verbesserungen:**
- [ ] SMART-Daten für NVMe
- [ ] Temperatur-Tracking über Zeit
- [ ] Load-Average History
- [ ] Network Throughput

**Status:** 🟡 Geplant

---

## 📝 Skill-Request Template

Neue Skill-Idee eintragen:

```markdown
### skill-name

**Zweck:** Ein Satz was der Skill macht

**Tools:**
- `tool.action` – Beschreibung

**Technologie:** Welche Tools/Libs

**Abhängigkeiten:** Andere Skills?

**Aufwand:** Stunden-Schätzung

**Impact:** ⭐⭐⭐ (1-5)
```

---

## 📊 Skill-Statistik

| Kategorie | Anzahl |
|-----------|--------|
| Core-Skills | 5 |
| Infrastructure | 4 |
| Automation | 3 |
| Monitoring | 4 |
| Integration | 5 |
| **Gesamt** | **21** |

**Ziel für 2026:** 30 Skills

---

## 🔗 Verweise

- `docs/skills/skill-build-plan.md` – Aktueller Build-Plan
- `docs/skills/skill-forge-governance.md` – Skill-Entwicklung
- `agent/skills/` – Skill-Verzeichnis
