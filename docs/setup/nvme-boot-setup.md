# NVMe Boot Setup Guide (Pi 5)

> Raspberry Pi 5 mit nativem NVMe-Boot  
> Ohne SD-Karte, direkt von M.2 SSD

---

## Überblick

Der **Raspberry Pi 5** unterstützt natives Booten von NVMe über PCIe. Keine SD-Karte mehr nötig!

**Vorteile:**
- ⚡ Deutlich schneller als SD-Karte (10x+)
- 🗄️ 1TB+ Speicher möglich
- 🔧 Haltbarer (TBW: 600 vs SD: 100)
- 🎯 Kein SD-Karten-Verschleiß

**Hardware:**
- Raspberry Pi 5 8GB
- M.2 NVMe SSD (Crucial P3 1TB empfohlen)
- PCIe HAT für Pi 5 (Pineboards, Waveshare, etc.)

---

## Voraussetzungen

### Erforderliche Hardware

| Komponente | Empfehlung | Preis |
|------------|------------|-------|
| Pi 5 | 8GB Variante | €80 |
| NVMe HAT | Pineboards HAT+ | €20 |
| NVMe SSD | Crucial P3 1TB | €60 |
| Netzteil | Offizielles Pi 5 27W | €15 |
| **Gesamt** | | **€175** |

### SSD Kompatibilität

Getestete SSDs:
- ✅ Crucial P3 / P3 Plus (1TB/2TB)
- ✅ Samsung 980 / 990 EVO
- ✅ WD Blue SN570 / SN580
- ✅ Kingston NV2

**Vermeiden:** QLC NAND mit schlechtem Controller (langsame 4K IOPS)

---

## Schritt 1: Hardware-Installation

### PCIe HAT montieren

```
1. Pi 5 ausschalten, vom Strom trennen
2. HAT auf GPIO-Pins aufstecken
3. NVMe SSD in M.2 Slot stecken
4. Schraube festziehen (nicht zu fest!)
5. Optional: HAT mit Spacer/Halterung sichern
6. Strom anschließen
```

**Wichtig:** PCIe HAT muss den **+5V** Pin korrekt versorgen!

---

## Schritt 2: Raspberry Pi Imager

### Image auf NVMe schreiben

**Option A: USB-NVMe Adapter (empfohlen)**

```bash
# 1. NVMe in USB-Adapter stecken
# 2. An PC/Mac anschließen

# Raspberry Pi Imager öffnen
# → OS: Raspberry Pi OS (64-bit)
# → Storage: NVMe SSD (im USB-Adapter)
# → Settings: Hostname, SSH, User konfigurieren
# → Flash!
```

**Option B: SD-Karte → NVMe Kopieren**

```bash
# Auf bereits laufendem Pi:
# 1. Raspberry Pi OS auf SD booten
# 2. NVMe einstecken (über HAT)

# NVMe partitionieren
sudo parted /dev/nvme0n1 --script mklabel gpt
sudo parted /dev/nvme0n1 --script mkpart primary fat32 0% 512MB
sudo parted /dev/nvme0n1 --script mkpart primary ext4 512MB 100%

# Boot-Partition formatieren
sudo mkfs.vfat -F 32 /dev/nvme0n1p1
sudo fatlabel /dev/nvme0n1p1 bootfs

# Root-Partition formatieren
sudo mkfs.ext4 /dev/nvme0n1p2
sudo e2label /dev/nvme0n1p2 rootfs

# Kopieren (SD → NVMe)
sudo dd if=/dev/mmcblk0p1 of=/dev/nvme0n1p1 bs=4M status=progress
sudo dd if=/dev/mmcblk0p2 of=/dev/nvme0n1p2 bs=4M status=progress

# PARTUUID aktualisieren (wichtig!)
sudo mount /dev/nvme0n1p2 /mnt
sudo sed -i 's/PARTUUID=.*-01/PARTUUID='$(lsblk -no PARTUUID /dev/nvme0n1p1)'/g' /mnt/boot/firmware/cmdline.txt
sudo sed -i 's/PARTUUID=.*-02/PARTUUID='$(lsblk -no PARTUUID /dev/nvme0n1p2)'/g' /mnt/etc/fstab
sudo umount /mnt
```

---

## Schritt 3: Boot-Order konfigurieren

### EEPROM Update (optional)

```bash
# Aktuellste Firmware
sudo apt update
sudo apt install rpi-eeprom

# EEPROM konfigurieren
sudo rpi-eeprom-config --edit
```

### Boot-Order setzen

```bash
# Aktuelle Boot-Order prüfen
sudo rpi-eeprom-config | grep BOOT_ORDER

# NVMe-first setzen
# 0x6 = NVMe
# 0x1 = SD-Karte (Fallback)
BOOT_ORDER=0xf461

# Oder nur NVMe (kein Fallback):
BOOT_ORDER=0xf6
```

**Boot-Codes:**
| Code | Medium |
|------|--------|
| 1 | SD-Karte |
| 2 | SSD (USB-MSD) |
| 3 | BCM-USB-MSD |
| 4 | BCM-SD |
| 5 | Netzwerk |
| 6 | NVMe |
| f | Neustart Boot-Sequenz |

### EEPROM flashen

```bash
# Neue Konfiguration schreiben
sudo rpi-eeprom-update -a

# Neustart für Update
sudo reboot
```

---

## Schritt 4: NVMe Boot testen

### SD-Karte entfernen

```
1. Pi herunterfahren: sudo shutdown now
2. Strom trennen
3. SD-Karte entfernen (falls vorhanden)
4. Strom anschließen
5. Pi sollte von NVMe booten
```

### Verifizierung

```bash
# Boot-Medium prüfen
lsblk

# Sollte zeigen:
# nvme0n1     259:0    0 931.5G  0 disk
# ├─nvme0n1p1 259:1    0   512M  0 part /boot/firmware
# └─nvme0n1p2 259:2    0   931G  0 part /

# Performance-Test
sudo hdparm -tT /dev/nvme0n1
# Timing cached reads:   2100 MB/s
# Timing buffered disk reads: 1500 MB/s
```

---

## Schritt 5: Performance-Optimierung

### fstab Optimierung

```bash
# /etc/fstab anpassen
PARTUUID=xxxx-xx / ext4 defaults,noatime,commit=60 0 1
```

| Option | Effekt |
|--------|--------|
| `noatime` | Keine Access-Time Updates |
| `commit=60` | Max 60s zwischen Writes |

### TRIM aktivieren

```bash
# TRIM für NVMe
sudo systemctl enable fstrim.timer
sudo fstrim -av /

# Verify
systemctl status fstrim.timer
```

### I/O Scheduler

```bash
# Für NVMe: none oder mq-deadline
cat /sys/block/nvme0n1/queue/scheduler
# [none] mq-deadline

# Setzen (in /etc/udev/rules.d/60-ioscheduler.rules)
echo 'ACTION=="add|change", KERNEL=="nvme0n1*", ATTR{queue/scheduler}="none"' | \
    sudo tee /etc/udev/rules.d/60-ioscheduler.rules
```

---

## Troubleshooting

### Problem: Pi bootet nicht von NVMe

```bash
# 1. LED-Codes beachten
# 4x lang, 4x kurz = Boot-Device nicht gefunden

# 2. EEPROM Boot-Order prüfen
sudo rpi-eeprom-config | grep BOOT_ORDER

# 3. NVMe erkannt?
sudo lspci | grep -i nvme
# 0000:01:00.0 Non-Volatile memory controller: ...

# 4. Firmware aktuell?
sudo rpi-eeprom-update
```

### Problem: Langsame NVMe-Performance

```bash
# PCIe Link Speed prüfen
sudo lspci -vv -s 01:00.0 | grep -i speed
# LnkCap: Port #0, Speed 16GT/s, Width x4

# Sollte zeigen: Speed 8GT/s oder 16GT/s
# Falls nur 2.5GT/s: PCIe HAT-Problem
```

### Problem: NVMe wird heiß

```bash
# Temperatur prüfen
sudo nvme smart-log /dev/nvme0n1 | grep temperature

# Ab 70°C: Kühlung verbessern
# - Kühlkörper auf SSD montieren
# - Gehäuse mit Lüfter
# - Thermal-Pads prüfen
```

---

## Advanced: Dual-Boot (NVMe + SD)

### Boot von SD, Root auf NVMe

```bash
# /boot/firmware/cmdline.txt editieren:
# PARTUUID der NVMe root-Partition
console=serial0,115200 console=tty1 root=PARTUUID=xxxxx-xx rootfstype=ext4 fsck.repair=yes rootwait
```

### Boot-Menü (Taster)

Manche PCIe HATs haben einen Boot-Taster:
- **Taster gedrückt halten beim Boot** → SD bevorzugt
- **Normal booten** → NVMe

---

## Monitoring

### NVMe Health

```bash
# SMART-Daten
sudo nvme smart-log /dev/nvme0n1

# Media Wearout Indicator beachten!
# 0-100%, ab 10% Ersatz planen

# Health-Check Script
/home/steges/agent/skills/health/scripts/nvme-health.sh
```

### Grafana Dashboard

```yaml
# Node Exporter zeigt NVMe-Stats
# Dashboard ID: 11074 (Node Exporter Full)
```

---

## Migration von SD zu NVMe

### Live-Migration

```bash
# 1. NVMe vorbereiten (siehe Schritt 2)

# 2. Daten synchronisieren (außer /boot)
sudo rsync -aHx --exclude=/boot --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run --exclude=/mnt / /mnt/nvme-root/

# 3. Boot-Dateien kopieren
sudo rsync -a /boot/firmware/ /mnt/nvme-boot/

# 4. PARTUUID anpassen
# 5. Reboot, SD entfernen
```

---

## Weiterführend

- `docs/infrastructure/hardware-nvme.md` – Hardware-Details
- `docs/infrastructure/firmware-boot.md` – Boot-Sequenz
- `docs/Ideen/hardware-upgrades.md` – Upgrade-Planung
