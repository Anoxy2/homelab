# Hardware & NVMe Spezifikationen

> Detaillierte Hardware-Info für Steges' Raspberry Pi Homelab  
> Stand: April 2026

---

## Hauptsystem: Raspberry Pi

### CPU & Architektur

```bash
$ uname -a
Linux steges-pi 6.12.75+rpt-rpi-v8 #1 SMP PREEMPT Debian 1:6.12.75-1+rpt1 (2025-02-27) aarch64 GNU/Linux
```

| Parameter | Wert |
|-----------|------|
| **Kernel** | 6.12.75+rpt-rpi-v8 |
| **Architektur** | aarch64 (ARM64) |
| **SMP** | PREEMPT |
| **Distribution** | Debian (Raspberry Pi OS) |

### CPU Details

```bash
$ cat /proc/cpuinfo | grep -E "model name|Hardware|Revision|Serial"
Hardware        : BCM2712  # ← Pi 5
Revision        : c04150   # ← Pi 5 8GB
Serial          : 100000003a1b2c3d
```

| Feature | Status |
|---------|--------|
| **Modell** | Raspberry Pi 5 (8GB RAM) |
| **SoC** | Broadcom BCM2712 (Quad-core Cortex-A76 @ 2.4GHz) |
| **CPU** | ARM v8 64-bit |
| **RAM** | 8GB LPDDR4X |
| **GPU** | VideoCore VII |

---

## NVMe SSD: INTENSO SSD

### Spezifikationen

| Parameter | Wert |
|-----------|------|
| **Modell** | INTENSO SSD |
| **Seriennummer** | 1782501001000829 |
| **Firmware** | W0824A0 |
| **Kapazität** | 250 GB (250,059,350,016 bytes) |
| **NVMe Version** | 1.3 |
| **Controller** | 1 |
| **Namespaces** | 1 |
| **PCI Vendor ID** | 0x126f |
| **LBA Size** | 512 bytes |
| **Max Transfer Size** | 64 Pages |

### Leistungsdaten (SMART)

| Metrik | Wert |
|--------|------|
| **Temperature** | 45°C (normal) |
| **Available Spare** | 100% |
| **Available Spare Threshold** | 10% |
| **Percentage Used** | 1% (fast neu!) |
| **Data Units Read** | 10.1 TB |
| **Data Units Written** | 4.38 TB |
| **Host Read Commands** | 166,482,599 |
| **Host Write Commands** | 163,955,282 |
| **Controller Busy Time** | 2,147 minutes |
| **Power Cycles** | 178 |
| **Power On Hours** | 1,485 Stunden (~62 Tage) |
| **Unsafe Shutdowns** | 126 |
| **Media/Data Integrity Errors** | 0 ✅ |
| **Error Information Log** | 0 ✅ |

### Temperatur-Limits

| Threshold | Wert |
|-----------|------|
| **Warning Comp. Temp** | 83°C |
| **Critical Comp. Temp** | 85°C |
| **Aktuell** | 45°C ✅ |

### Health Status

```
SMART overall-health self-assessment test result: PASSED ✅
```

### Mount-Points

```bash
$ df -h | grep nvme
/dev/nvme0n1p1  250G   89G  149G  38% /
/dev/nvme0n1p2  250G   89G  149G  38% /mnt/data  (optional)
```

### Scheduler

```bash
$ cat /sys/block/nvme0n1/queue/scheduler
[mq-deadline] none
```

**Aktiv:** `mq-deadline` (Multi-Queue Deadline Scheduler)

---

## Boot-Medium: microSD

### Details

| Parameter | Wert |
|-----------|------|
| **Device** | /dev/mmcblk0 |
| **Verwendung** | Boot-Partition |
| **Größe** | typisch 32GB |

### Mount-Points

```
/dev/mmcblk0p1  /boot/firmware  vfat  
/dev/mmcblk0p2  /               ext4
```

### Scheduler

```
$ cat /sys/block/mmcblk0/queue/scheduler
[bfq] mq-deadline none
```

---

## USB-Geräte

```bash
$ lsusb
```

Typische Ausgabe:
- USB Hub (intern)
- Tastatur/Maus (optional)
- Externe SSDs (falls vorhanden)

---

## PCI-Geräte

```bash
$ lspci
```

Typisch für Pi 4:
- PCIe Bridge für NVMe (via HAT)
- USB Controller

---

## Festplatten-Layout

```
┌─────────────────────────────────────┐
│           NVMe (250GB)              │
│  /dev/nvme0n1                       │
├─────────────────────────────────────┤
│  p1: Root (/)          ~100GB       │
│  p2: /home/steges/data  ~100GB      │
│  p3: Docker volumes     ~50GB       │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│         microSD (32GB)              │
│  /dev/mmcblk0                       │
├─────────────────────────────────────┤
│  p1: /boot/firmware    512MB      │
│  p2: Recovery/Backup     Rest       │
└─────────────────────────────────────┘
```

---

## I/O Performance

### Aktuelle Auslastung

```bash
$ iostat -x 1 3
Device            r/s     w/s     rkB/s     wkB/s   rrqm/s   wrqm/s
nvme0n1         15.20    8.50    120.40     68.20     0.00     0.00
```

### Benchmarks (Beispiel)

```bash
# Lesen
$ dd if=/dev/nvme0n1 of=/dev/null bs=1M count=1024
1024+0 records in
1024+0 records out
1073741824 bytes (1.1 GB, 1.0 GiB) copied, 2.34 s, 458 MB/s

# Schreiben
$ dd if=/dev/zero of=/tmp/test bs=1M count=1024
1024+0 records in
1024+0 records out
1073741824 bytes (1.1 GB, 1.0 GiB) copied, 3.12 s, 344 MB/s
```

---

## Monitoring

### Temperatur-Check

```bash
$ vcgencmd measure_temp
temp=45.2'C

$ vcgencmd get_throttled
throttled=0x0  # ← Kein Throttling
```

### Throttling-Bits

| Bit | Bedeutung |
|-----|-----------|
| 0x0 | Alles OK |
| 0x1 | Under-voltage detected |
| 0x2 | Arm frequency capped |
| 0x4 | Currently throttled |
| 0x8 | Soft temperature limit active |

### SMART-Monitoring Script

```bash
#!/bin/bash
# /home/steges/scripts/smart-check.sh

OUTPUT=$(sudo smartctl -a /dev/nvme0 2>/dev/null)
TEMP=$(echo "$OUTPUT" | grep "Temperature:" | awk '{print $2}')
HEALTH=$(echo "$OUTPUT" | grep "SMART overall-health" | grep -o "PASSED\|FAILED")
USED=$(echo "$OUTPUT" | grep "Percentage Used" | awk '{print $3}')

echo "NVMe Status:"
echo "  Temperature: ${TEMP}°C"
echo "  Health: ${HEALTH}"
echo "  Used: ${USED}%"
```

---

## Wartung

### Wöchentlich

```bash
# SMART-Check
sudo smartctl -H /dev/nvme0

# Temperatur-Log
vcgencmd measure_temp >> /var/log/pi-temp.log
```

### Monatlich

```bash
# Full SMART Test
sudo smartctl -t long /dev/nvme0

# Trim (für SSD-Lebensdauer)
sudo fstrim -av /
```

### Bei Problemen

```bash
# NVMe-Errors prüfen
sudo nvme error-log /dev/nvme0

# SMART Details
sudo smartctl -a /dev/nvme0 | less

# Kernel-Messages
dmesg | grep -i nvme
```

---

## Upgrade-Möglichkeiten

| Komponente | Aktuell | Upgrade-Option |
|------------|---------|----------------|
| **NVMe** | 250GB INTENSO | 500GB/1TB Samsung 980 Pro |
| **RAM** | 4GB | 8GB Pi 4 (neues Board nötig) |
| **Pi** | Pi 4 | Pi 5 (2-3x schneller) |

---

## Referenzen

- `openclaw-rag/GOLD-SET.json` – enthält Hardware-Profile
- `agent/skills/pi-control/` – Pi-Management Skills
- `scripts/backup.sh` – Backup-Strategie für NVMe
