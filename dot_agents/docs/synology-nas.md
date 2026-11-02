# Synology NAS — DS3622xs+

Access: `ssh dsm` | Host: HomeDSM | LAN IP: see [internal-topology.md](internal-topology.md)
OS: DSM 7.2.1-69057 (Update 4) | Arch: x86_64 (Broadwell) | Kernel: 4.4.302+

## Key Paths

| Path | Purpose |
|------|---------|
| `/var/packages/ContainerManager/` | Container Manager package root |
| `/var/packages/ContainerManager/target/usr/bin/docker` | Docker CLI (not in default PATH) |
| `/var/packages/ContainerManager/etc/dockerd.json` | Docker daemon config |
| `/var/packages/ContainerManager/etc/*.config` | Per-container configs (DSM managed) |
| `/var/packages/ContainerManager/etc/projects/` | Docker Compose project dirs |
| `/var/log/packages/ContainerManager.log` | Container Manager log |
| `/var/log/synopkg.log` | Package manager log |
| `/var/log/synopkgmgr.log` | Package manager daemon log |
| `/volume2/@appstore/ContainerManager/` | Package binaries (symlink target) |

## Docker Setup

- Storage driver: **btrfs**
- Data root: `/var/packages/ContainerManager/var/docker`
- Log driver: `db` (Synology proprietary)
- Registry mirrors: multiple CN mirrors configured
- Docker version: 24.0.2 | Compose: v2.20.1

## Running Containers

| Container | Image | Ports |
|-----------|-------|-------|
| emby | linuxserver/emby | 8096 |
| bitwarden-app-1 | vaultwarden/server | 8081→80, 3012 |
| nas-tools | hsuyelin/nas-tools | 3000 |
| chinesesubfinder | allanpk716/chinesesubfinder | 19035, 19037 |
| stiring-pdf | frooodle/s-pdf | 8099→8080 |
| flaresolverr | flaresolverr | 8191 |
| clash-exporter | zzde/clash-exporter | 2112 |
| atrust | hagb/docker-atrust | 8812→8080, 1081→1080 |
| easyconnect-vpn-1 | hagb/docker-easyconnect:7.6.7 | 8811→8080, 1080 |
| wallabag | wallabag/wallabag | 21080→80 |

Stopped: rmfakecloud, gotenberg, photoprism, qbittorrent, prowlarr, sabnzbd, lidarr

## Common Commands

```bash
# Docker (full path required)
sudo /var/packages/ContainerManager/target/usr/bin/docker ps -a
sudo /var/packages/ContainerManager/target/usr/bin/docker logs <container>
sudo /var/packages/ContainerManager/target/usr/bin/docker restart <container>
sudo /var/packages/ContainerManager/target/usr/bin/docker compose -f <path> up -d

# Package management
sudo /usr/syno/bin/synopkg status ContainerManager
sudo /usr/syno/bin/synopkg start ContainerManager
sudo /usr/syno/bin/synopkg restart ContainerManager
sudo /usr/syno/bin/synopkg list | grep -i <name>

# Service management
sudo systemctl status pkg-ContainerManager-dockerd
sudo systemctl status pkg-ContainerManager-termd
sudo systemctl status pkg-ContainerManager-event-watcherd

# Logs
sudo journalctl -u pkg-ContainerManager-dockerd --no-pager -n 50
sudo tail -50 /var/log/packages/ContainerManager.log
sudo grep -i 'ContainerManager' /var/log/synopkgmgr.log | tail -20
```

## Architecture Notes

- DSM package lifecycle: `synopkgctl start` → `start-stop-status start` → systemd services
- `start-stop-status status` checks dockerd via `synosystemctl get-active-status`
- Package status codes: 1=stopped, 273=stopped(systemd), 311=starting, 255=not installed
- Working states: `repairing`, `starting`, `installing`
- DSM auto-repairs packages after crash/power-loss (downloads + reinstalls same version)
- Container start configs are regenerated on package start from `etc/*.config` files

## Gotchas

- `docker` / `synopkg` are NOT in sudo's default PATH — use full paths.
- After power loss, DSM may trigger auto-repair; dockerd startup takes ~4 min with many containers.
- `synopkg status` may report "stop" even when services are running (status script PATH issue with `synosystemctl`).
- Docker networks are recreated on restart; containers referencing deleted networks fail with `network not found`.
- The `pkgindexer_add` (Synology search indexer) can hang during package start, blocking the entire startup chain.
- Compose projects managed via DSM UI store configs in `etc/projects/`; CLI changes may be overwritten by UI.
