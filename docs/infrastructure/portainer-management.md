# Portainer Container Management

> Docker container management UI
> Stacks, volumes, logs, console access

---

## Overview

**Portainer** provides a web UI for managing Docker containers, stacks, volumes, and networks.

| Attribute | Value |
|-----------|-------|
| **Image** | `portainer/portainer-ce:2.21.5` |
| **Container** | portainer |
| **Port** | `192.168.2.101:9000` |
| **LAN URL** | `http://portainer.lan:9000` |
| **Data** | `./portainer/data/` |

---

## Configuration

### Docker Compose

```yaml
services:
  portainer:
    image: portainer/portainer-ce:2.21.5
    container_name: portainer
    ports:
      - "192.168.2.101:9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./portainer/data:/data
    restart: unless-stopped
```

### Caddyfile

```caddyfile
portainer.lan {
    reverse_proxy 192.168.2.101:9000
}
```

---

## First Login

1. Open `http://portainer.lan:9000`
2. Create admin user
3. Select "Local" Docker environment
4. Done

---

## Key Features

### Dashboard

- Container status (running/stopped)
- Resource usage (CPU/memory)
- Image count
- Volume usage

### Containers

| Action | How |
|--------|-----|
| Start/Stop | Click container → Actions |
| View Logs | Container → Logs tab |
| Console | Container → Console button |
| Inspect | Container → Inspect tab |
| Edit | Container → Duplicate/Edit |

### Stacks (Compose)

```
Stacks → Add Stack
Name: homelab
Editor: Paste docker-compose.yml
Deploy Stack
```

**Update Stack:**
```
Stacks → homelab → Editor → Modify → Update Stack
```

### Volumes

```
Volumes → Browse → Select volume → Explore
```

### Networks

```
Networks → Inspect network details
```

### Images

```
Images → Pull/Pull & Replace
Images → Unused → Remove
```

---

## User Management

### Teams

```
Users → Teams
- admin (full access)
- viewer (read-only)
```

### Access Control

```
Endpoints → local → Access
Grant access to specific teams
```

---

## Registry Integration

```
Registries → Add Registry
- Docker Hub (anonymous)
- GHCR (GitHub token)
- Private registry
```

---

## Troubleshooting

### "Unable to connect to Docker"

```bash
# Check socket access
docker exec portainer ls -la /var/run/docker.sock

# Fix permissions
sudo chmod 666 /var/run/docker.sock
# Or add user to docker group
```

### Data loss after recreate

Portainer data is in `./portainer/data/` – included in USB backup.

### High memory usage

```bash
# Check container count
docker ps -q | wc -l

# Prune unused
Settings → Clean up → Prune
```

---

## API

```bash
# Get JWT token
TOKEN=$(curl -s -X POST http://192.168.2.101:9000/api/auth \
  -d '{"Username":"admin","Password":"password"}' | jq -r .jwt)

# List containers
curl -H "Authorization: Bearer $TOKEN" \
  http://192.168.2.101:9000/api/endpoints/1/docker/containers/json

# Container stats
curl -H "Authorization: Bearer $TOKEN" \
  "http://192.168.2.101:9000/api/endpoints/1/docker/containers/CONTAINER_ID/stats?stream=false"
```

---

## Backup

```bash
# Portainer data is in volume
./portainer/data/ → /mnt/usb-backup/backups/YYYYMMDD/portainer/

# Or export settings via UI
Settings → Backup Portainer
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Documentation created, Portainer CE 2.21.5 |
