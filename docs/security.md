# Sicherheit

## Grundregeln

- Alle Services sind **nur im LAN** erreichbar (192.168.2.0/24)
- Kein Port-Forwarding auf dem Router
- `.env` Dateien niemals committen oder über Samba teilen

## Secret-Management

- Secrets in `.env` Dateien pro Stack
- `.env.example` als Vorlage ohne echte Werte
- Samba blockiert `.env`, `.env.bak`, `secrets.env` per veto files

## SSH

- Key-only Auth empfohlen (`PasswordAuthentication no` in `/etc/ssh/sshd_config`)
- Nur User `steges` hat Zugriff

## Docker

- Container laufen nicht als root (wo möglich PUID/PGID setzen)
- Log-Rotation verhindert Volllaufen der NVMe
- Watchtower updated Images wöchentlich (nicht sofort, um Breaking Changes zu vermeiden)

## Updates

```bash
sudo apt update && sudo apt upgrade
```

Unattended-upgrades ist aktiv für Sicherheits-Patches.
