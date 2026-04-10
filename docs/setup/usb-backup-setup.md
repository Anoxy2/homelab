# USB Backup Setup Guide

> Einrichtung des USB-Backups für den backup-automation Skill  
> Formatieren, Mounten, fstab-Konfiguration

---

## Überblick

Der USB-Stick dient als lokales Backup-Ziel für:
- SQLite Datenbanken (OpenClaw Memory)
- Secrets und SSH Keys
- Docker Volumes (nicht im Git)
- Full System State

**Empfohlene Spezifikation:**
- Mindestens 128GB (für Pi-Backups ausreichend)
- USB 3.0+ für akzeptable Geschwindigkeit
- Qualitätshersteller (Samsung, SanDisk, Kingston)

---

## Schritt 1: USB-Stick vorbereiten

### Stick identifizieren

**VORHER:** Nichts einstecken!

```bash
# Aktuelle Devices auflisten
lsblk
```

**Stick einstecken** und nochmal prüfen:

```bash
# Neu erschienenes Device finden
lsblk

# Oder via dmesg
dmesg | tail -20

# Sollte anzeigen:
# sda           8:0    1 238.5G  0 disk
# └─sda1        8:1    1 238.5G  0 part
```

**Wichtig:** Korrektes Device finden (meist `/dev/sda` oder `/dev/sdb`)

---

## Schritt 2: Partitionieren

### Option A: Einzelne Partition (empfohlen)

```bash
# Partitionstabelle erstellen (GPT)
sudo parted /dev/sda --script mklabel gpt

# Partition erstellen
sudo parted /dev/sda --script mkpart primary ext4 0% 100%

# Prüfen
sudo parted /dev/sda print
```

### Option B: Mehrere Partitionen

```bash
# Backup + ZFS Test
sudo parted /dev/sda --script mklabel gpt
sudo parted /dev/sda --script mkpart primary ext4 0% 80%
sudo parted /dev/sda --script mkpart primary zfs 80% 100%
```

---

## Schritt 3: Formatieren

### ext4 (Standard)

```bash
# Formatieren
sudo mkfs.ext4 -L usb-backup /dev/sda1

# Label prüfen
sudo e2label /dev/sda1
```

### Mit Label

Das Label ermöglicht fstab-Mounting unabhängig vom Device:

```bash
# Label setzen
sudo tune2fs -L usb-backup /dev/sda1
```

---

## Schritt 4: Mount-Point erstellen

```bash
# Verzeichnis erstellen
sudo mkdir -p /mnt/usb-backup

# Permissions (steges kann schreiben)
sudo chown steges:steges /mnt/usb-backup
sudo chmod 755 /mnt/usb-backup

# Unterverzeichnisse
mkdir -p /mnt/usb-backup/backups
mkdir -p /mnt/usb-backup/.state
```

---

## Schritt 5: fstab konfigurieren

### Option A: By Label (empfohlen)

```bash
# UUID oder Label finden
lsblk -o NAME,LABEL,UUID

# Eintrag erstellen
echo 'LABEL=usb-backup /mnt/usb-backup ext4 defaults,noatime,nofail,x-systemd.device-timeout=30 0 2' | \
    sudo tee -a /etc/fstab
```

### Option B: By UUID

```bash
# UUID ermitteln
UUID=$(lsblk -no UUID /dev/sda1)
echo "UUID=$UUID /mnt/usb-backup ext4 defaults,noatime,nofail 0 2" | \
    sudo tee -a /etc/fstab
```

### fstab Optionen erklärt

| Option | Bedeutung |
|--------|-----------|
| `defaults` | Standard-Optionen (rw, suid, dev, exec, auto, nouser, async) |
| `noatime` | Keine Access-Time Updates (weniger Writes) |
| `nofail` | Boot nicht blockieren wenn USB fehlt |
| `x-systemd.device-timeout=30` | 30s Timeout für systemd |

---

## Schritt 6: Test-Mount

```bash
# Unmount falls bereits gemountet
sudo umount /dev/sda1 2>/dev/null || true

# Mount aus fstab testen
sudo mount -a

# Prüfen
mount | grep usb-backup
# Output: /dev/sda1 on /mnt/usb-backup type ext4 ...

# Schreib-Test
touch /mnt/usb-backup/test-file && rm /mnt/usb-backup/test-file
echo "✅ USB-Backup erfolgreich gemountet"
```

---

## Schritt 7: Automount testen

```bash
# Unmount
sudo umount /mnt/usb-backup

# Ausstecken
# Warten...

# Wiedereinstecken
# Sollte automatisch mounten (bei fstab + modernem System)

# Prüfen
ls /mnt/usb-backup
```

**Falls nicht automatisch:**
```bash
# Manuelles Mount
sudo mount /mnt/usb-backup
```

---

## Schritt 8: Backup-Skill Test

```bash
# USB-Status prüfen
/home/steges/agent/skills/backup-automation/scripts/backup-status.sh

# Sollte zeigen:
# USB: OK (device: /dev/sda1, ...)

# USB-Backup testen
/home/steges/agent/skills/backup-automation/scripts/backup-usb.sh

# Verifikation
/home/steges/agent/skills/backup-automation/scripts/backup-verify.sh
```

---

## Troubleshooting

### Problem: "Device busy" beim Unmount

```bash
# Prozesse finden
sudo lsof /mnt/usb-backup
sudo fuser -m /mnt/usb-backup

# Killen oder warten
sudo fuser -km /mnt/usb-backup
```

### Problem: "wrong fs type"

```bash
# ext4 Treiber fehlt?
sudo apt install e2fsprogs

# Oder falsches Dateisystem
sudo fsck /dev/sda1
```

### Problem: USB wird nicht erkannt

```bash
# USB Ports prüfen
lsusb

# Kernel Logs
dmesg | grep -i usb

# Power-Problem? (Pi USB hat begrenzte Power)
# → Aktiver USB-Hub oder powered Hub verwenden
```

### Problem: Langsame Übertragung

```bash
# Speed test
sudo hdparm -tT /dev/sda

# USB 2.0 wäre ~20-30 MB/s
# USB 3.0 sollte >100 MB/s

# Falls langsam:
# - USB 3.0 Port verwenden (blau)
# - Gutes Kabel verwenden
# - USB-Controller prüfen: lsusb -t
```

---

## Advanced: ZFS (Experimentell)

Falls du ZFS ausprobieren willst:

```bash
# ZFS installieren
sudo apt install zfsutils-linux

# Pool erstellen
sudo zpool create usb-pool /dev/sda1

# Dataset erstellen
sudo zfs create usb-pool/backups

# Properties setzen
sudo zfs set compression=lz4 usb-pool
sudo zfs set atime=off usb-pool

# Mount
sudo zfs set mountpoint=/mnt/usb-backup usb-pool/backups
```

**Achtung:** ZFS auf USB-Stick kann problematisch sein wegen Wear-Leveling!

---

## Backup-Retention

Der backup-automation Skill löscht automatisch:
- Backups älter als 14 Tage
- Leere Backup-Verzeichnisse
- Temporäre Dateien

**Manuell bereinigen:**
```bash
# Alte Backups löschen (>14 Tage)
find /mnt/usb-backup/backups -maxdepth 1 -type d -mtime +14 -exec rm -rf {} +

# Platz anzeigen
df -h /mnt/usb-backup
```

---

## Sicherheit

### USB-Stick verschlüsseln (Optional)

```bash
# LUKS Verschlüsselung
sudo cryptsetup luksFormat /dev/sda1
sudo cryptsetup luksOpen /dev/sda1 usb-encrypted
sudo mkfs.ext4 /dev/mapper/usb-encrypted

# Mount
echo 'usb-encrypted /dev/sda1 none luks' | sudo tee -a /etc/crypttab
echo '/dev/mapper/usb-encrypted /mnt/usb-backup ext4 defaults,noatime 0 2' | sudo tee -a /etc/fstab
```

---

## Monitoring

```bash
# In HEARTBEAT.md oder Monitoring:

# USB Space
/usr/local/bin/check-usb-space.sh

# USB Mount Status
systemctl status mnt-usb\x2dbackup.mount
```

---

## Weiterführend

- `docs/infrastructure/backup-strategy.md` – Backup-Konzept
- `docs/infrastructure/backup-automation-skill.md` – Skill-Doku
- `docs/runbooks/usb-restore-procedure.md` – Restore-Guide
