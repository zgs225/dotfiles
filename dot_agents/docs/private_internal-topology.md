# Internal Topology — LAN, IP plan, device inventory

> **Single source of truth for internal addresses.** Managed by chezmoi with the `private`
> attribute (mode `0600`). Every other doc (`AGENTS.md`, `.agents/docs/*.md`) points here instead of
> repeating IPs — when you need a concrete address, read this file.
>
> Managed as `dot_agents/docs/private_internal-topology.md` in the chezmoi source.

## Network segments

| Segment | CIDR | Bridge / device | Notes |
|---------|------|-----------------|-------|
| LAN | `192.168.2.0/23` (mask `255.255.254.0`) | PVE `vmbr0`, router `br-lan` (eth1 + eth2) | main house network, DHCP + DNS by dnsmasq |
| Internal / virtual | `10.10.1.0/16` | PVE `vmbr1` | second NIC of every LXC/VM, `10.10.1.<last-octet>` of its LAN address |
| WAN | — | router `eth0` | upstream |

- Gateway + DNS: router at `192.168.2.1`; DNS domain `lan`.
- dnsmasq forwards to a local proxy on `127.0.0.1#7874` (`noresolv`, `rebind_protection` off) —
  if that proxy dies, DNS breaks for the whole LAN.
- Subnet is authoritative only from the router: `ssh router uci show network.lan`.
- The `192.168.2.0/23` therefore covers `192.168.2.0` – `192.168.3.255`; the `192.168.3.x` half is
  only used by the MetalLB overflow pool below.

### LoadBalancer pool (MetalLB `metallb-system/default-pool`)

| Range | Use |
|-------|-----|
| `192.168.2.51-192.168.2.69` | Traefik ingress / service VIPs |
| `192.168.3.100-192.168.3.254` | overflow range |

## Hosts

| LAN IP | Internal IP | Name | Type | Notes |
|--------|-------------|------|------|-------|
| `192.168.2.1` | — | router | OpenWrt 23.05.5, Rockchip ARM64 | gateway, DHCP, DNS, firewall |
| `192.168.2.3` | `10.10.1.3` | pihole | LXC 1003 (8 G) | **stopped** |
| `192.168.2.5` | `10.10.1.5` | apache-cassandra | LXC 1005 (4 G) | |
| `192.168.2.6` | `10.10.1.6` | influxdb | LXC 1006 (74 G) | InfluxDB 2.7.12, HTTP `:8086` |
| `192.168.2.7` | `10.10.1.7` | redis | LXC 104 (8 G) | |
| `192.168.2.8` | `10.10.1.8` | mysql | LXC 102 (16 G) | |
| `192.168.2.9` | `10.10.1.9` | postgresql | LXC 1009 (32 G) | |
| `192.168.2.10` | `10.10.1.10` | nginxproxymanager | LXC 1010 (4 G) | reverse proxy; also VIP `192.168.2.100` |
| `192.168.2.14` | `10.10.1.14` | rabbitmq | LXC 1014 (4 G) | |
| `192.168.2.16` | — | clawbuntu | host | `ssh clawbuntu` |
| `192.168.2.21` | — | k3sserver01 | VM (control-plane, etcd) | |
| `192.168.2.31` | — | k3sagent01 | VM (worker, Intel GPU) | |
| `192.168.2.32` | — | k3sagent02 | VM (worker) | |
| `192.168.2.33` | `10.10.1.33` | k3sagent03 | VM (worker) | |
| `192.168.2.34` | — | k3sagent04-2 | VM (worker) | |
| `192.168.2.100` | — | npm-vip | VIP | NPM virtual IP |
| `192.168.2.183` | `10.10.1.1` | dsm | Synology DS3622xs+ (VM 183) | SMB `//192.168.2.183/pve`; NFS `10.10.1.1:/volume2/...` |
| `192.168.2.253` | — | pve-253 | PVE (alternate) | `ssh pve-253` |
| `192.168.2.254` | — | pve | Proxmox VE 9.0.3 | hypervisor, web `:8006` |

## Guest inventory on PVE (VMIDs)

- **LXC**: 102 mysql, 104 redis, 1003 pihole, 1005 apache-cassandra, 1006 influxdb,
  1009 postgresql, 1010 nginxproxymanager, 1014 rabbitmq.
- **VM**: 183 dsm, 2031 k3sagent01, 2033 k3sagent03 (running);
  103 nettool, 106 debian12-tpl, 1012 android, 30003 ENDEAVOUROS (stopped).
- k3sagent02 / k3sagent04-2 are **not** on `pve`.

Disk layout, thin-pool rules and per-guest disk sizes: [proxmox-pve.md](proxmox-pve.md).

## SSH aliases (`~/.ssh/config`)

| Alias | Target |
|-------|--------|
| `router` / `router-proxy` | `192.168.2.1` |
| `pve` | `192.168.2.254` |
| `pve-253` | `192.168.2.253` |
| `dsm` | `192.168.2.183` |
| `pi-hole` | `192.168.2.3` |
| `clawbuntu` | `192.168.2.16` |
| `jp1` | `jp1.yuez.me` (remote) |
| `bj2` | `bj2.yuez.me` (remote) |
| `la1` | `la1.yuez.me` (remote) |
| `github.com` | `ssh.github.com` |

Public services: `ntfy.yuez.me` (alerts), `scrutiny.in.yuez.me` (Traefik → k3s `scrutiny/web`).

## Keeping this current

Change an address → update **this file only**, then `chezmoi re-add ~/.agents/docs/internal-topology.md`.
Do not re-inline IPs into the other docs; add a pointer instead.
