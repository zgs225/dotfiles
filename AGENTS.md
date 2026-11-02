# AGENTS.md — Homelab & Workstation Index

This file is the entry point for managing all infrastructure. Detailed docs in `.agents/docs/`.

## Environment Overview

| System | Type | OS | Access |
|--------|------|----|--------|
| **Workstation** (this host) | EndeavourOS i3wm laptop | Arch-based, kernel 6.x | local |
| **k3s cluster** | 5-node homelab cluster | Debian 12 (bookworm) | `kubectl` (kubeconfig in dotfiles) |
| **Synology NAS** | DS3622xs+ | DSM 7.2.1 (69057) | `ssh dsm` |
| **OpenWrt Router** | Rockchip ARM64 | OpenWrt 23.05.5 | `ssh router` |
| **Proxmox VE** (`pve`) | 单块 NVMe + LVM-thin，跑 8 个 LXC + 7 个 VM | PVE 9.0.3 / kernel 6.17 | `ssh pve` |

Network: `192.168.2.0/23`（掩码 255.255.254.0，以路由器 `uci show network.lan` 为准）— router `.1`, k3s server `.21`, agents `.31-.34`, NAS on LAN, PVE `.254`。

## Configuration Management

Three tools, strict boundaries — do not cross them:

| Tool | Scope | Repo / Path | Doc |
|------|-------|-------------|-----|
| **chezmoi** | User dotfiles (`~/.config/**`, shell, editor, themes) | `~/.local/share/chezmoi` | [dotfiles.md](.agents/docs/dotfiles.md) |
| **eos-bootstrap** | System packages, services, kernel, network | `~/Workspace/Misc/eos-bootstrap` | [eos-bootstrap.md](.agents/docs/eos-bootstrap.md) |
| **k3s-admin** | All k8s workloads (Helm/Kustomize/raw) via ArgoCD | `~/Workspace/Misc/k3s-admin` | [k3s-cluster.md](.agents/docs/k3s-cluster.md) |

Boundary rules:
- Ansible (eos-bootstrap) never writes under `~`.
- chezmoi never installs **system** packages or enables **system** services. User-level actions are fine (e.g. `mise install` for tool versions, `systemctl --user enable` for user timers/services via `.chezmoiscripts/`).
- k3s-admin is GitOps: push to git → ArgoCD syncs. Do not `kubectl apply` manually.
- **Home-directory config edits**: before modifying ANY config file under `~`, check `chezmoi managed <path>` first. If chezmoi-managed, edit via the dotfiles workflow (edit live file, then `chezmoi re-add` to sync the source — never leave drift, or edit the source directly). If NOT chezmoi-managed, ask the user for permission before editing.

## Remote Devices

| Device | Doc | Common tasks |
|--------|-----|-------------|
| Synology NAS (DS3622xs+) | [synology-nas.md](.agents/docs/synology-nas.md) | Docker containers, package mgmt, storage |
| OpenWrt Router | [openwrt-router.md](.agents/docs/openwrt-router.md) | Network config, firewall, packages |
| Proxmox VE (hypervisor) | [proxmox-pve.md](.agents/docs/proxmox-pve.md) | LXC/VM 管理、**thin pool 空间**、fstrim、journald、InfluxDB 容器 |

## Quick Reference

```bash
# Dotfiles
chezmoi update --init          # pull + apply + regenerate chezmoi.toml
chezmoi diff                   # preview changes
chezmoi managed <path>         # is this file chezmoi-managed? (check before editing ~ configs)
chezmoi re-add <path>          # sync edited live file back into source (after manual edits)
chezmoi add --encrypt <file>   # add encrypted secret

# System bootstrap
cd ~/Workspace/Misc/eos-bootstrap && ./bootstrap.sh   # full idempotent bootstrap
ansible-playbook ansible/playbook.yml --ask-become-pass  # ansible only

# k3s cluster
kubectl get nodes -o wide
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
cd ~/Workspace/Misc/k3s-admin && git push  # ArgoCD auto-syncs

# Proxmox VE（thin pool 空间！）
ssh pve
lvs -o lv_name,lv_size,data_percent,metadata_percent pve/data  # pool 用量，>80% 立刻处理
lvs -o lv_name,data_percent          # 单卷：thin% ≫ df% 就是泄漏，不是真满
pct fstrim <ct>                      # 容器回收（thin 泄漏的唯一解法）
qm guest cmd <vmid> fstrim           # VM 回收
systemctl start pct-fstrim.service   # 宿主已有每周定时器（Sun 03:30）

# Synology NAS
ssh dsm
sudo /usr/syno/bin/synopkg status <PkgName>
sudo /var/packages/ContainerManager/target/usr/bin/docker ps -a

# OpenWrt Router
ssh router
uci show <section>             # read config
opkg list-installed            # installed packages
```

## k3s Cluster Topology

```
k3sserver01  192.168.2.21  control-plane/etcd   (Debian 12, kernel 6.1)
k3sagent01   192.168.2.31  worker + Intel GPU    (Debian 12, kernel 6.12)
k3sagent02   192.168.2.32  worker                (Debian 12, kernel 6.1)
k3sagent03   192.168.2.33  worker                (Debian 12, kernel 6.1)
k3sagent04-2 192.168.2.34  worker                (Debian 12, kernel 6.1)
```

Storage: Piraeus/LINSTOR (replicated) + NFS subdir provisioner + local-path
Ingress: Traefik + MetalLB | Monitoring: Prometheus + Grafana + Loki
Backup: Velero + Kopia | GitOps: ArgoCD + argocd-image-updater
Auth: Keycloak + Authelia | DNS/Certs: cert-manager + certimate

## Incident Response Checklist

1. `kubectl get nodes` — all Ready?
2. `kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded` — abnormal pods?
3. `kubectl get events -A --sort-by='.lastTimestamp' | tail -30` — recent warnings?
4. Check ArgoCD: `kubectl get applications -n argocd` — any OutOfSync/Degraded?
5. NAS: `ssh dsm "sudo /usr/syno/bin/synopkg status ContainerManager"`
6. Router: `ssh router "logread | tail -30"`
7. PVE: `ssh pve "lvs -o lv_name,lv_size,data_percent,metadata_percent pve/data"` — thin pool >80%？
   单个 LXC 的 `data_percent` 高但容器内 `df` 正常 → 跑 `pct fstrim <ct>`（见 [proxmox-pve.md](.agents/docs/proxmox-pve.md)）
