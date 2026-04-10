# Hardware-Upgrades & Planung

> Geplante Hardware-Änderungen für das Homelab  
> Budget, Prioritäten, Zeitplan

---

## 🏠 Aktuelle Hardware

### Raspberry Pi 5 (Primary)

| Komponente | Spec | Status |
|------------|------|--------|
| Pi 5 | 8GB RAM | ✅ Produktion |
| NVMe | Crucial P3 1TB | ✅ Produktion |
| USB Backup | 256GB Stick | ✅ Produktion |

### Netzwerk

| Komponente | Spec | Status |
|------------|------|--------|
| Router | Unifi Dream Machine | ✅ Produktion |
| Switch | Unifi Switch 8 | ✅ Produktion |
| AP | Unifi AP 6 Lite | ✅ Produktion |

---

## 💰 Budget 2026

**Verfügbar:** €500

| Priorität | Item | Kosten | Quartal |
|-----------|------|--------|---------|
| 🔴 1 | UPS APC Back-UPS 650 | €80 | Q2 |
| 🔴 2 | Second Pi 5 8GB | €80 | Q2 |
| 🟡 3 | 2TB NVMe (2x) | €200 | Q3 |
| 🟡 4 | 1TB USB-C SSD | €100 | Q3 |
| 🟢 5 | PoE Hat Pi 5 | €30 | Q4 |
| 🟢 6 | Gehäuse (2x) | €40 | Q4 |

**Gesamt:** €530 (+€30 über Budget)

---

## 🛒 Einkaufsliste

### Sofort (Q2 2026)

#### APC Back-UPS 650VA

**Warum:**
- Pi 5 ~8W Verbrauch
- UPS hält ~30 Minuten
- Graceful Shutdown Script

**Specs:**
- 650VA / 400W
- 4x Schuko Outlets
- USB Monitoring
- €80

**Alternativen:**
- CyberPower CP650E (€70)
- Eaton 3S 550 (€90)

---

#### Second Raspberry Pi 5 8GB

**Warum:**
- Hot-Standby für HA
- Backup-Testumgebung
- Load-Balancing möglich

**Setup-Plan:**
1. Identisches Setup wie Primary
2. Docker-Swarm oder K3s
3. Keepalived für IP-Failover

---

### Mittelfristig (Q3 2026)

#### 2TB NVMe (2 Stück)

**Warum:**
- ZFS Mirror auf Second Pi
- Mehr Speicher für Daten
- Aktuell 1TB wird knapp

**Optionen:**
| Modell | Preis | TBW | Wahl |
|--------|-------|-----|------|
| Crucial P3 Plus 2TB | €100 | 800 | 🟡 |
| Samsung 980 2TB | €140 | 1200 | 🟢 |
| WD Blue SN570 2TB | €120 | 900 | 🟡 |

**Empfehlung:** Samsung 980 für bessere TBW

---

#### 1TB USB-C SSD

**Warum:**
- USB-Stick langsam für große Backups
- SSD zuverlässiger
- Extern für Offsite

**Option:** Samsung T7 Shield 1TB (€100)

---

### Langfristig (Q4 2026)

#### PoE HAT für Pi 5

**Warum:**
- Weniger Kabel
- Zentrale Power über Switch
- Sauberer Aufbau

**Option:** Official Raspberry Pi PoE+ HAT (€30)

---

#### Gehäuse (2 Stück)

**Option:** Argon NEO 5 M.2 NVMe Case (€20 x2)

---

## 📐 Rack/Setup Planung

### Aktueller Stand

```
[Router] -- [Switch] -- [Pi 5] -- [USB-Stick]
                |
            [AP]
```

### Geplant (2x Pi Setup)

```
[Router] -- [Switch] -- [Pi 5 Primary] -- [USB-SSD]
                |           |
            [AP]      [Pi 5 Secondary]
                          |
                     [USB-SSD Backup]
```

### Stromversorgung mit UPS

```
[Wall] -- [UPS] -- [Pi 5 Primary]
              |-- [Pi 5 Secondary]  (wenn vorhanden)
              |-- [Switch]
              |-- [Router]
```

---

## 🔄 Upgrade-Pfade

### Path A: HA-Cluster (Empfohlen)

1. **Q2:** UPS + Second Pi 5
2. **Q3:** Docker Swarm oder K3s
3. **Q4:** Keepalived + Load Balancer
4. **2027:** Offsite Backup Pi bei Freund/Familie

**Vorteile:**
- ✅ Keine Single Point of Failure
- ✅ Rolling Updates möglich
- ✅ Backup-Test auf Secondary

**Kosten:** €160 (Q2)

---

### Path B: Big Storage

1. **Q2:** 2TB NVMe
2. **Q3:** USB-C SSD für Backup
3. **Q4:** NAS (Synology oder DIY)

**Vorteile:**
- ✅ Mehr Speicher
- ✅ NAS für File-Sharing

**Nachteile:**
- ❌ Mehr Stromverbrauch
- ❌ Komplexer

---

### Path C: Mini-Itx x86

**Idee:** Intel NUC oder ähnliches statt Pi

**Vorteile:**
- ✅ x86 Kompatibilität
- ✅ Mehr RAM (32GB+)
- ✅ Bessere I/O

**Nachteile:**
- ❌ 15-25W Stromverbrauch
- ❌ Lauter (Lüfter)
- ❌ Teurer

**Entscheidung:** ❌ Nicht geplant (Pi bleibt)

---

## 📝 Alternativen Evaluation

### Statt Second Pi 5: Pi 4?

| Aspekt | Pi 4 8GB | Pi 5 8GB |
|--------|----------|----------|
| Preis | €75 | €80 |
| CPU | Cortex-A72 | Cortex-A76 |
| Speed | ~1.5x | ~2.5x |
| PCIe | USB Bridge | Native |
| NVMe | Langsamer | Schnell |
| **Fazit** | ❌ | ✅ |

**Empfehlung:** Pi 5 für identisches Setup

---

## 🗓️ Zeitplan

```
April 2026
└── Budget freigeben

Mai 2026
├── UPS bestellen & installieren
└── UPS-Monitor Skill entwickeln

Juni 2026
└── Second Pi 5 bestellen

Juli 2026
└── Second Pi Setup, HA-Test

August 2026
└── Entscheidung: HA-Cluster oder nicht

September 2026
└── 2TB NVMe wenn Budget da
```

---

## 🔗 Verweise

- `docs/infrastructure/hardware-nvme.md` – Aktuelle Hardware
- `docs/Ideen/future-projects.md` – Projekt-Roadmap
- `docs/decisions/` – Hardware-Entscheidungen
