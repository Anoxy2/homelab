# Wartung

## Images updaten

```bash
~/scripts/update-stacks.sh
```

Manuell für einen Stack:
```bash
cd ~/pihole
docker compose pull
docker compose up -d
```

## Backup

```bash
~/scripts/backup.sh
```

Sichert alle `config/`-Ordner als `.tar.gz` nach `~/backups/YYYY-MM-DD/`.

## Logs

```bash
# Alle Logs eines Stacks
cd ~/pihole && docker compose logs -f

# Nur letzte 100 Zeilen
docker compose logs --tail=100 pihole

# System-Journal
journalctl -u docker --since "1 hour ago"
```

## Docker aufräumen

```bash
# Ungenutzte Images entfernen (VORSICHT: erst prüfen was läuft)
docker image prune

# Volumes prüfen
docker volume ls

# Disk-Nutzung
docker system df
```

## NVMe-Gesundheit

```bash
sudo smartctl -a /dev/nvme0n1
```

## Systemd Timer

Laufende Timer prüfen:
```bash
systemctl list-timers
```
