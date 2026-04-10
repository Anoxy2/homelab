# Immich Evaluation (Pi 5, arm64)

Datum: 05.04.2026

## Kurzfazit
Immich ist auf diesem Pi prinzipiell lauffaehig, da die relevanten Release-Images arm64-Manifeste bereitstellen.

## Verifikation
Gepruefte Images (via `docker manifest inspect`):
- `ghcr.io/immich-app/immich-server:release` -> arm64 vorhanden
- `ghcr.io/immich-app/immich-machine-learning:release` -> arm64 vorhanden

## Empfehlung fuer dieses Homelab
- Immich als optionalen P2-Ausbau behandeln (kein sofortiger Rollout), weil zusaetzliche Dauerlast auf CPU/RAM/Storage entsteht.
- Erst nach baseline-stabilen P1-Themen aktivieren (OpenClaw/Skill-Manager/Backup-Flow).
- Vor produktivem Rollout minimalen Smoke-Run einplanen:
  - Compose-Start nur mit Immich-Stack
  - Upload eines Testfotos
  - Performance-Check (CPU/RAM) auf dem Pi 5

## Entscheidung
- Todo "Immich evaluieren" ist erledigt (technische Machbarkeit bestaetigt, Rollout weiterhin optional).
