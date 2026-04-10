# Firmware & Boot-Konfiguration

> Raspberry Pi Firmware, Boot-Settings, Device Tree, Kernel-Parameter  
> Stand: April 2026

---

## Übersicht

| Komponente | Pfad | Beschreibung |
|------------|------|--------------|
| **Boot-Firmware** | `/boot/firmware/` | Startcode, GPU-Firmware |
| **Config** | `/boot/firmware/config.txt` | Hardware-Settings |
| **Cmdline** | `/proc/cmdline` | Kernel-Parameter |
| **Device Tree** | `/boot/firmware/bcm2712-rpi-5-b.dtb` | Hardware-Definition |
| **Kernel** | `/boot/firmware/kernel8.img` | 64-bit Kernel |

---

## config.txt

### Aktive Konfiguration

```ini
# /boot/firmware/config.txt

# --- Display ---
hdmi_force_hotplug=1
hdmi_group=2
hdmi_mode=82

# --- Performance ---
arm_freq=2400
over_voltage=2
gpu_mem=128

# --- Storage ---
# Boot von NVMe (nativ, kein Overlay nötig)
# dtoverlay=nvme  # ← Nicht mehr nötig auf Pi 5

# --- USB ---
max_usb_current=1

# --- Audio ---
dtparam=audio=on

# --- Camera ---
start_x=1
gpu_mem=128

# --- I2C ---
dtparam=i2c_arm=on

# --- SPI ---
dtparam=spi=on

# --- Serial ---
enable_uart=1

# --- Bluetooth ---
dtparam=krnbt=on

# --- Warnings ---
avoid_warnings=1
```

### Parameter-Erklärung

| Parameter | Wert | Beschreibung |
|-----------|------|--------------|
| `arm_freq` | 2400 | CPU-Takt (MHz) |
| `over_voltage` | 2 | Spannung erhöht (+0.05V) |
| `gpu_mem` | 128 | GPU-Speicher (MB) |
| `hdmi_force_hotplug` | 1 | HDMI immer aktiv |
| `enable_uart` | 1 | Serial aktiv |
| `dtparam=i2c_arm` | on | I2C-Bus aktiv |
| `dtparam=spi` | on | SPI-Bus aktiv |

---

## Kernel Command Line

### Aktuelle Parameter

```bash
$ cat /proc/cmdline
 coherent_pool=1M 8250.nr_uarts=1 snd_bcm2835.enable_headphones=0 
 snd_bcm2835.enable_headphones=1  snd_bcm2835.enable_hdmi=1 
 snd_bcm2835.enable_hdmi=0  smsc95xx.macaddr=DC:A6:32:00:00:00 
 vc_mem.mem_base=0x3ec00000 vc_mem.mem_size=0x40000000  
 console=ttyS0,115200 console=tty1 root=PARTUUID=a1b2c3d4-02 
 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait
```

### Wichtige Parameter

| Parameter | Bedeutung |
|-----------|-----------|
| `root=PARTUUID=...` | Root-Partition (NVMe) |
| `rootfstype=ext4` | Filesystem |
| `elevator=deadline` | I/O Scheduler |
| `console=ttyS0,115200` | Serial Console |
| `fsck.repair=yes` | Auto-Reparatur |

---

## Device Tree Overlays

### Verfügbare Overlays

```bash
$ ls /boot/firmware/overlays/ | head -20
ads1115.dtbo
adv7282m.dtbo
gpio-fan.dtbo
i2c-gpio.dtbo
nvme.dtbo
pi3-disable-bt.dtbo
spi-gpio.dtbo
vc4-fkms-v3d.dtbo
w1-gpio.dtbo
```

### Aktive Overlays

| Overlay | Zweck |
|---------|-------|
| `nvme` | NVMe-USB-Bridge Support |
| `vc4-fkms-v3d` | GPU-VideoCore |

---

## Boot-Sequenz

```
┌─────────────────────────────────────────┐
│  1. GPU startet (start*.elf)            │
│     → config.txt lesen                  │
├─────────────────────────────────────────┤
│  2. Device Tree laden                   │
│     → bcm2712-rpi-5-b.dtb               │
├─────────────────────────────────────────┤
│  3. Kernel laden                        │
│     → kernel8.img (64-bit)              │
├─────────────────────────────────────────┤
│  4. Kernel startet                      │
│     → cmdline Parameter                 │
├─────────────────────────────────────────┤
│  5. Initramfs (falls vorhanden)         │
├─────────────────────────────────────────┤
│  6. Root-FS mounten                     │
│     → /dev/nvme0n1p1                  │
├─────────────────────────────────────────┤
│  7. systemd init                        │
│     → multi-user.target                 │
└─────────────────────────────────────────┘
```

---

## EEPROM-Firmware

### Version prüfen

```bash
$ vcgencmd version
Jan  5 2024 13:54:06 
Copyright (c) 2012 Broadcom
version 30f9dafb (release) (embedded)
```

### Update

```bash
# Aktuelles EEPROM laden
sudo rpi-eeprom-update

# Update durchführen
sudo rpi-eeprom-update -a

# Neustart
sudo reboot
```

### EEPROM-Config

```bash
# /etc/default/rpi-eeprom-update
FIRMWARE_RELEASE_STATUS="stable"
```

| Status | Bedeutung |
|--------|-----------|
| `critical` | Nur Bugfixes |
| `stable` | Empfohlen (default) |
| `beta` | Neue Features |

---

## NVMe-Boot (USB-MS)

### Konfiguration

Der Pi 5 bootet nativ von NVMe (PCIe):

```
┌─────────────┐     ┌─────────────┐
│   Pi 5      │PCIe │  INTENSO    │
│   (M.2)     │────→│  SSD 250GB  │
│  NVMe Slot  │     │             │
└─────────────┘     └─────────────┘
```

### Vorteile

- ✅ Schneller als SD-Karte
- ✅ Langlebiger (TBW)
- ✅ Größere Kapazität
- ✅ Besser für Docker

### Boot-Reihenfolge

```bash
$ vcgencmd bootloader_config
BOOT_ORDER=0xf41
```

| Wert | Bedeutung |
|------|-----------|
| `0xf41` | SD → NVMe/USB → Netzwerk |
| `0xf14` | NVMe/USB → SD → Netzwerk |

---

## Kernel-Module

### Automatisch geladen

```bash
$ lsmod | head -20
Module                  Size  Used by
nvme                   49152  2
nvme_core             126976  3 nvme
ext4                  733184  1
```

### Wichtige Module

| Modul | Zweck |
|-------|-------|
| `nvme` | NVMe-Treiber |
| `nvme_core` | NVMe Core |
| `ext4` | Root-Filesystem |
| `bcm2835_dma` | DMA Engine |
| `bcm2835_wdt` | Watchdog |

### Manuelles Laden

```bash
# Modul laden
sudo modprobe gpio-fan

# Dauerhaft (/etc/modules-load.d/)
echo "gpio-fan" | sudo tee /etc/modules-load.d/fan.conf
```

---

## Boot-Partitionen

### Layout

```
/dev/mmcblk0 (microSD, 32GB)
├── p1: boot (/boot/firmware, vfat, 512MB)
└── p2: root (ext4, Rest)

/dev/nvme0n1 (NVMe, 250GB) ← Bootet von hier
├── p1: root (/ ext4, ~100GB)
└── p2: data (ext4, ~150GB)
```

### Mount-Status

```bash
$ findmnt -n -o SOURCE,TARGET,FSTYPE,OPTIONS /boot/firmware
/dev/mmcblk0p1 /boot/firmware vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro
```

---

## Watchdog

### Hardware Watchdog

```bash
# Status
$ wdctl
Device:        /dev/watchdog
Identity:      bcm2835_wdt [watchdog0]
Timeout:       10 seconds
```

### Konfiguration (/etc/watchdog.conf)

```ini
watchdog-device = /dev/watchdog
max-load-1 = 24
min-memory = 1
```

### Systemd-Watchdog

```ini
# /etc/systemd/system.conf
RuntimeWatchdogSec=10
ShutdownWatchdogSec=10min
```

---

## Troubleshooting

### Boot-Probleme

```bash
# Boot-Logs
sudo vcdbg log msg

# HDMI-Output erzwingen
hdmi_safe=1  # in config.txt

# Serial-Debug
enable_uart=1
```

### Kernel-Panic

```bash
# Emergency shell
init=/bin/bash

# Filesystem-Check
tsck.repair=yes

# Single-user
systemd.unit=rescue.target
```

### Recovery

```bash
# Von SD booten, NVMe reparieren
sudo fsck -y /dev/nvme0n1p1

# CHROOT
sudo mount /dev/nvme0n1p1 /mnt
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo chroot /mnt
```

---

## Optimierungen

### I/O-Scheduler

```bash
# Für NVMe
echo 'mq-deadline' > /sys/block/nvme0n1/queue/scheduler

# Für SD
echo 'bfq' > /sys/block/mmcblk0/queue/scheduler
```

### Kernel-Tuning (/etc/sysctl.conf)

```ini
vm.swappiness=10
vm.vfs_cache_pressure=50
net.core.rmem_max=134217728
net.core.wmem_max=134217728
```

---

## Referenzen

- `/boot/firmware/config.txt` – Haupt-Config
- `/boot/firmware/cmdline.txt` – Kernel-Parameter (legacy)
- [Raspberry Pi Documentation](https://www.raspberrypi.com/documentation/computers/config_txt.html)
