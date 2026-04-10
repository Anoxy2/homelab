# Docker Socket Proxy Security

> Secure access to Docker socket
> Filters requests, prevents container escapes

---

## Overview

**Docker Socket Proxy** provides filtered access to Docker socket for services that need limited Docker API access.

| Attribute | Value |
|-----------|-------|
| **Image** | `ghcr.io/tecnativa/docker-socket-proxy:0.2.0` |
| **Container** | docker-socket-proxy |
| **Port** | `2375` (internal only) |
| **Access** | Internal network only |

---

## Architecture

```
Without Proxy (insecure):
Homepage ──→ /var/run/docker.sock (full access)

With Proxy (secure):
Homepage ──→ Socket Proxy (:2375) ──→ /var/run/docker.sock
            (read-only, filtered)
```

---

## Configuration

### Docker Compose

```yaml
services:
  docker-socket-proxy:
    image: ghcr.io/tecnativa/docker-socket-proxy:0.2.0
    container_name: docker-socket-proxy
    environment:
      # Enable read-only operations only
      CONTAINERS: 1      # Container list, inspect
      SERVICES: 1        # Service list
      TASKS: 1           # Task list
      NODES: 0           # No node operations
      NETWORKS: 0        # No network operations
      IMAGES: 0          # No image operations
      VOLUMES: 0         # No volume operations
      BUILD: 0           # No build operations
      EXEC: 0            # No exec (critical!)
      POST: 0            # No POST (write)
      DELETE: 0          # No DELETE
      PUT: 0             # No PUT
      PATCH: 0           # No PATCH
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - socket-proxy
    restart: unless-stopped

  # Services using proxy
  homepage:
    image: ghcr.io/gethomepage/homepage:v1.12.3
    environment:
      DOCKER_HOST: tcp://docker-socket-proxy:2375
    networks:
      - socket-proxy
      - default
    depends_on:
      - docker-socket-proxy

networks:
  socket-proxy:
    internal: true  # No external access
```

---

## Permission Matrix

| Endpoint | CONTAINERS | SERVICES | IMAGES | Allowed? |
|----------|------------|----------|--------|----------|
| `GET /containers/json` | 1 | - | - | ✅ Yes |
| `GET /containers/ID` | 1 | - | - | ✅ Yes |
| `POST /containers/ID/exec` | - | - | - | ❌ No (EXEC: 0) |
| `DELETE /containers/ID` | 1 | - | - | ❌ No (DELETE: 0) |
| `POST /images/create` | - | - | 1 | ❌ No (POST: 0) |
| `GET /services` | - | 1 | - | ✅ Yes |

---

## Why This Matters

### Without Proxy

```bash
# Any compromised container can:
docker exec root_container sh -c "docker run --rm -v /:/host alpine chroot /host sh"
# → Full host access!
```

### With Proxy

```bash
# Same container can only:
curl http://docker-socket-proxy:2375/containers/json
# → List containers only, no exec, no mounts
```

---

## Monitoring

### Check Logs

```bash
docker logs docker-socket-proxy -f
```

### Verify Filtering

```bash
# Should work (read)
docker exec homepage curl -s http://docker-socket-proxy:2375/containers/json | head

# Should fail (write)
docker exec homepage curl -X DELETE http://docker-socket-proxy:2375/containers/abc123
# → 403 Forbidden
```

---

## Services Using Proxy

| Service | Needs | Proxy Config |
|---------|-------|--------------|
| Homepage | Container status | `CONTAINERS: 1` |
| Traefik | Container discovery | `CONTAINERS: 1` |
| Portainer | Full access | Direct socket (admin only) |
| Prometheus | Container metrics | `CONTAINERS: 1` |

---

## Troubleshooting

### "Cannot connect to Docker"

```bash
# Check proxy is running
docker ps | grep docker-socket-proxy

# Check network
docker network ls | grep socket-proxy

# Test from container
docker exec homepage nslookup docker-socket-proxy
```

### Services show "Docker error"

```bash
# Verify permissions
docker exec docker-socket-proxy env | grep -E '^(CONTAINERS|EXEC|POST)'

# Increase logging
docker logs docker-socket-proxy --tail 50
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-10 | Documentation created |
