# Hardware Watchdog Setup (BCM2835)

Der Raspberry Pi 5 hat einen Hardware-Watchdog (bcm2835_wdt), der bei System-Hängern automatisch einen Reboot durchführt.

## Status

- **Treiber**: Builtin-Kernel (bereits aktiv)
- **Device**: `/dev/watchdog` existiert
- **Daemon**: Muss installiert und konfiguriert werden

## Installation

```bash
# watchdog Daemon installieren
sudo apt update
sudo apt install -y watchdog

# Konfiguration kopieren
sudo cp /home/steges/docs/infrastructure/watchdog.conf /etc/watchdog.conf

# Service aktivieren
sudo systemctl enable watchdog.service
sudo systemctl start watchdog.service

# Status prüfen
sudo systemctl status watchdog
```

## Funktionsweise

Der Watchdog erwartet alle `interval` Sekunden ein "Lebenszeichen" (heartbeat). Wenn das System hängt (Kernel-Panic, Hardware-Freeze), wird das Lebenszeichen nicht gesendet und der Watchdog rebootet nach `watchdog-timeout` Sekunden.

## Konfiguration

- **watchdog-device**: `/dev/watchdog`
- **interval**: 15 Sekunden (Heartbeat-Frequenz)
- **watchdog-timeout**: 15 Sekunden (max. Zeit ohne Heartbeat)
- **max-load-1**: 24 (Reboot wenn Load > 24 für 1 Minute)
- **min-memory**: 1 (Reboot wenn < 1 Seite freier Speicher)
- **temperature-sensor**: `/sys/class/thermal/thermal_zone0/temp`
- **max-temperature**: 85°C (Reboot bei Überhitzung)

## Monitoring

```bash
# Watchdog Status
sudo wdctl

# Kernel Messages
sudo dmesg | grep -i watchdog

# Service Logs
sudo journalctl -u watchdog -f
```

## Deaktivierung (falls nötig)

```bash
sudo systemctl stop watchdog
sudo systemctl disable watchdog
```

## Risiken

- Bei falscher Konfiguration: unnötige Reboots
- Bei zu kurzem Timeout: Reboots unter Last
- Der Watchdog sollte nur bei kritischen Hängern greifen, nicht bei normaler Last
