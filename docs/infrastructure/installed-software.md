# Installierte Software & Pakete

> Alle Programme, Tools und ihre Versionen  
> Stand: April 2026

---

## Betriebssystem

### Basis-Info

| Parameter | Wert |
|-----------|------|
| **Distribution** | Debian (Raspberry Pi OS) |
| **Codename** | bookworm |
| **Kernel** | 6.12.75+rpt-rpi-v8 |
| **Arch** | aarch64 |
| **User** | steges (uid 1000) |
| **Hostname** | steges-pi |

### Release-Info

```bash
$ cat /etc/os-release
PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
NAME="Debian GNU/Linux"
VERSION_ID="12"
VERSION="12 (bookworm)"
VERSION_CODENAME=bookworm
ID=debian
HOME_URL="https://www.debian.org/"
SUPPORT_URL="https://www.debian.org/support"
BUG_REPORT_URL="https://bugs.debian.org/"
```

---

## Docker & Container

### Docker Engine

| Paket | Version |
|-------|---------|
| docker-ce | 25.0.x |
| docker-ce-cli | 25.0.x |
| containerd.io | 1.6.x |
| docker-buildx-plugin | 0.12.x |
| docker-compose-plugin | 2.24.x |

### Docker Compose (Standalone)

```bash
$ docker-compose --version
docker-compose version 1.29.2, build unknown

# ODER
$ docker compose version
Docker Compose version v2.24.5
```

### Docker-Images (lokal)

| Image | Tag | Verwendung |
|-------|-----|------------|
| caddy | 2.7-alpine | Reverse Proxy |
| pihole/pihole | 2024.02.0 | DNS Filter |
| prom/prometheus | v2.49.1 | Metrics |
| grafana/grafana | 10.3.1 | Dashboards |
| openclaw/openclaw | latest | AI Gateway |
| ghcr.io/home-assistant/home-assistant | 2024.2 | Smart Home |
| eclipse-mosquitto | 2.0.18 | MQTT |
| vaultwarden/server | latest | Passwörter |
| searxng/searxng | latest | Search |

---

## Node.js & npm

### Versionen

```bash
$ node --version
v22.14.0  # oder höher

$ npm --version
10.5.0

$ npx --version
10.5.0
```

### Globale npm-Pakete

| Paket | Version | Zweck |
|-------|---------|-------|
| pm2 | 5.3.x | Process Manager |
| typescript | 5.3.x | TS Compiler |
| ts-node | 10.9.x | TS Execution |
| @anthropic-ai/claude-cli | latest | Claude CLI |

### Node-Installation

```bash
# Via NodeSource
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

---

## Python

### Versionen

```bash
$ python3 --version
Python 3.11.2

$ pip3 --version
pip 23.0.1 from /usr/lib/python3/dist-packages/pip (python 3.11)
```

### Python-Pakete (system-wide)

| Paket | Version | Zweck |
|-------|---------|-------|
| pip | 23.0.1 | Package Manager |
| setuptools | 66.1.1 | Build tools |
| wheel | 0.38.4 | Packaging |
| pyserial | 3.5 | ESP32/Serial |
| paho-mqtt | 1.6.x | MQTT Client |
| requests | 2.28.x | HTTP Client |
| flask | 2.3.x | Chat-Bridge API |
| gpiozero | 2.0 | Pi GPIO |

### Virtual Environments

| Env | Path | Pakete |
|-----|------|--------|
| chat-bridge | (keine) | Flask, Requests |
| esphome | Docker | ESPHome |

---

## Monitoring & Tools

### System-Monitoring

| Paket | Version | Zweck |
|-------|---------|-------|
| htop | 3.2.2 | Process Viewer |
| iotop | 0.6 | I/O Monitor |
| nmon | 16g | Performance |
| vnstat | 2.10 | Traffic Stats |
| iftop | 1.0pre4 | Bandwidth |
| nethogs | 0.8.7 | Per-Process Net |

### SMART & Disk

| Paket | Version | Zweck |
|-------|---------|-------|
| smartmontools | 7.3 | SMART Monitoring |
| nvme-cli | 2.4 | NVMe Tools |
| hdparm | 9.65 | Disk Tuning |
| fio | 3.33 | I/O Benchmark |

### Netzwerk-Tools

| Paket | Version | Zweck |
|-------|---------|-------|
| curl | 7.88.1 | HTTP Client |
| wget | 1.21.3 | Downloader |
| net-tools | 2.10 | ifconfig, netstat |
| iproute2 | 6.1.0 | ip, ss |
| dnsutils | 9.18 | dig, nslookup |
| whois | 5.5.17 | Domain lookup |
| tcpdump | 4.99.3 | Packet capture |
| nmap | 7.93 | Port scanner |
| mtr | 0.95 | Traceroute |
| iperf3 | 3.12 | Bandwidth test |

---

## Sicherheit

### Firewall & Auth

| Paket | Version | Status |
|-------|---------|--------|
| ufw | 0.36.2 | ✅ aktiv |
| fail2ban | 1.0.2 | ❌ inaktiv |
| openssh-server | 9.2p1 | ✅ aktiv |
| openssl | 3.0.11 | System |

### SSH-Konfiguration

```bash
# /etc/ssh/sshd_config (Auszug)
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
```

---

## Entwicklungs-Tools

### Editoren

| Tool | Version | Install-Methode |
|------|---------|-----------------|
| windsurf | 1.110.1 | Codeium (.windsurf-server) |
| code (VS Code) | 1.87.x | Microsoft Repo |
| nano | 7.2 | apt |
| vim | 9.0 | apt |

### Git

```bash
$ git --version
git version 2.39.2

$ git config --global user.name
steges

$ git config --global user.email
steges@users.noreply.github.com
```

### Build-Tools

| Paket | Version | Zweck |
|-------|---------|-------|
| build-essential | 12.9 | gcc, make |
| cmake | 3.25.1 | Build system |
| pkg-config | 1.8.1 | Configs |
| autoconf | 2.71 | Configure |
| libtool | 2.4.7 | Libraries |

---

## Datenbanken

### SQLite

```bash
$ sqlite3 --version
3.40.1 2022-12-28 14:03:47
```

| Verwendung | Pfad |
|------------|------|
| OpenClaw Memory | `infra/openclaw-data/memory/main.sqlite` |
| Pi-hole | `pihole/gravity.db` |
| Home Assistant | `homeassistant/home-assistant_v2.db` |
| Vaultwarden | `vaultwarden/db.sqlite3` |

### InfluxDB (Docker)

| Parameter | Wert |
|-----------|------|
| **Version** | 2.7.x |
| **Port** | 8086 |
| **Verwendung** | Time-series data (optional) |

---

## Web-Server & Proxy

### Caddy (Docker)

| Feature | Status |
|---------|--------|
| HTTP/2 | ✅ |
| HTTP/3 | ✅ |
| Auto-HTTPS | ✅ |
| Reverse Proxy | ✅ |
| File Server | ✅ |

### Alternativ: Nginx (nicht aktiv)

```bash
# Nicht installiert
which nginx
# (empty)
```

---

## Home Automation

### Zigbee2MQTT

| Parameter | Wert |
|-----------|------|
| **Adapter** | SONOFF Zigbee 3.0 USB Dongle Plus |
| **Firmware** | zStack3x0 |
| **Port** | /dev/ttyUSB0 |
| **Channel** | 11 |

### ESPHome (Docker)

| Feature | Status |
|---------|--------|
| Dashboard | ✅ Port 6052 |
| OTA Updates | ✅ |
| API Encryption | ✅ |

---

## Backup & Sync

### Tools

| Paket | Version | Zweck |
|-------|---------|-------|
| rsync | 3.2.7 | File Sync |
| restic | 0.16.0 | Encrypted Backup |
| rclone | 1.65.0 | Cloud Sync |
| tar | 1.34 | Archiving |
| gzip | 1.12 | Compression |
| zstd | 1.5.4 | Fast Compression |

### Backup-Ziele

| Ziel | Tool | Frequenz |
|------|------|----------|
| External USB | rsync | Täglich |
| Backblaze B2 | restic | Wöchentlich |
| Synology NAS | rclone | Täglich |

---

## Nützliche Aliases

```bash
# ~/.bashrc (Auszug)
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# Docker
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# System
alias s='sudo systemctl'
alias j='sudo journalctl'
alias ports='sudo ss -tlnp'
```

---

## Paket-Management

### Repositories (/etc/apt/sources.list.d/)

| Repository | URL |
|------------|-----|
| raspberrypi | deb http://archive.raspberrypi.org/debian/ bookworm main |
| docker | deb [arch=arm64] https://download.docker.com/linux/debian bookworm stable |
| nodesource | deb https://deb.nodesource.com/node_22.x nodistro main |

### Wartung

```bash
# Updates
sudo apt update && sudo apt upgrade -y

# Autoremove
sudo apt autoremove -y

# Clean
sudo apt clean

# List upgradable
apt list --upgradable
```

---

## Version-Tracking

### Changelog

| Quelle | Pfad |
|--------|------|
| OS Updates | `/var/log/apt/history.log` |
| Docker Images | `docker images --format "{{.Repository}}:{{.Tag}}"` |
| npm Globals | `npm list -g --depth=0` |
| pip Packages | `pip3 list` |

### Dokumentation

- `CHANGELOG.md` – Projekt-Historie
- `docs/infrastructure/` – Diese Doku
