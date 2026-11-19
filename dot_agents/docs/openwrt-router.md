# OpenWrt Router

Access: `ssh router` | LAN IP: see [internal-topology.md](internal-topology.md)
OS: OpenWrt 23.05.5 (r24106) | Arch: aarch64 (Rockchip ARMv8) | Kernel: 6.6.54
Installed packages: ~717

## Network Layout

| Interface | Device | Config |
|-----------|--------|--------|
| LAN | `br-lan` (bridge: eth1 + eth2) | static `<lan-ip>`/23 (see [internal-topology.md](internal-topology.md)) |
| WAN | eth0 | DHCP from the Huawei CPE (bridge mode), carrier CGNAT `10.x/8` |

- Subnet: see [internal-topology.md](internal-topology.md) — must match `uci show network.lan`
- WAN is a **Huawei H153-381 「5G CPE 5s」** (China Unicom) in bridge mode; management UI `192.168.8.1`.
  Raw link ≈ 50 Mbit down / 11 Mbit up, idle RTT ≈ 30 ms. See "QoS / SQM" below.
- DNS: dnsmasq → forwards to `127.0.0.1#7874` (local proxy), `noresolv`, `rebind_protection` off
- Domain: `lan`
- DHCP: dnsmasq on LAN

## QoS / SQM (bufferbloat)

The cellular WAN has heavy bufferbloat without shaping (loaded-vs-idle RTT +100…300 ms).
`sqm-scripts` + `cake` runs permanently on `eth0`, **upload only** — the download peak is
deliberately left unshaped (user decision):

| Setting | Value |
|---------|-------|
| `sqm.wan.interface` | `eth0` (WAN) |
| `sqm.wan.download` | `0` → no downstream shaping (`ifb4eth0` stays DOWN) |
| `sqm.wan.upload` | `9500` kbit (≈ 85 % of the ~11 Mbit uplink) |
| `sqm.wan.qdisc` / `script` | `cake` / `piece_of_cake.qos` |

- **`firewall.@defaults[0].flow_offloading` must stay `0`** — flow offload bypasses the qdisc
  and SQM becomes a no-op (it only matters for forwarded LAN traffic; router-local traffic was
  never offloaded). `fullcone='1'` is compatible and stays on.
- `sqm.eth1` (LAN port, disabled) is a leftover section — leave it disabled / ignore it.
- Measured, saturated download from the router: no shaping at all → avg 120–170 ms (max 330);
  download shaped to 36 Mbit → 35–50 ms typical but peak throughput capped at ~36 Mbit; with
  `download=0` (current) → average throughput uncapped, loaded RTT back to 90–170 ms.
  Spike behaviour is dominated by cellular-side capacity dips, not by the router.
- Raising `sqm.wan.download` above 0 re-enables ingress shaping (creates `ifb4eth0`).
- Tuning: change `sqm.wan.download`/`upload`, `uci commit sqm`, `/etc/init.d/sqm restart`.
- Config backups: `/root/sqm.bak.*`, `/root/firewall.bak.*`.

> **CPU note**: all traffic (LAN + router) goes through the OpenClash TUN, so ~30 Mbit costs
> roughly 50 % of each of the 4 A55 cores. A single TCP stream tops out around 35 Mbit because
> it is pinned to one softirq/Clash thread — multi-stream spreads across cores and reaches the
> link limit. Disabling the TUN is the only way around that, not more QoS tuning.

### CPE (192.168.8.1, Huawei HiLink API)

- Login: `POST /api/user/login` with `password_type=4`, where `Password =
  b64_nopad(sha256hex("admin" + b64(sha256hex(pw)) + TokInfo))`; needs the `SessionID` cookie
  and `__RequestVerificationToken` header from `/api/webserver/SesTokInfo` (XML-unescape the
  token first, and refresh it from the response header after every call).
- Working endpoints: `/api/monitoring/status`, `/api/monitoring/traffic-statistics`,
  `/api/net/current-plmn`, `/api/device/basic_information`.
- RSRP/SINR endpoints (`/api/device/signal`, `/api/net/cell-info`, `/api/device/seccellinfo`)
  return `100003` until the CPE's first-run setup is completed in the web UI.

## Key Config Files (UCI)

| File | Section | Purpose |
|------|---------|---------|
| `/etc/config/network` | interfaces, devices, routes | Network topology |
| `/etc/config/firewall` | zones, rules, forwards | Firewall (~104 rules/zones/forwards) |
| `/etc/config/dhcp` | dnsmasq, dhcp pools | DNS + DHCP |
| `/etc/config/wireless` | wifi-iface, wifi-device | WiFi (if applicable) |
| `/etc/config/system` | system, ntp, led | Hostname, timezone, LEDs |
| `/etc/config/sqm` | `wan` | cake shaping on `eth0` (see above) |

## Common Commands

```bash
# Read config
uci show network
uci show firewall
uci get network.lan.ipaddr

# Modify config (always commit + apply)
uci set network.lan.ipaddr='<lan-ip>'    # see internal-topology.md
uci commit network
/etc/init.d/network restart

# Services
/etc/init.d/<service> status|start|stop|restart
# Key services: network, firewall, dnsmasq, dropbear, uhttpd

# Firewall
fw4 print              # dump active ruleset (nftables)
/etc/init.d/firewall restart

# Packages
opkg update
opkg list-installed
opkg install <pkg>
opkg remove <pkg>

# Logs
logread | tail -50
logread -f             # follow

# Diagnostics
ping <host>
traceroute <host>
netstat -tlnp
ss -tlnp
```

## Gotchas

- **Always `uci commit` before restarting services** — uncommitted changes are lost on service restart.
- Use `uci changes` to review pending uncommitted modifications.
- `fw4` (nftables) replaces the old `iptables`-based `fw3`. Don't mix them.
- DNS is routed through a local proxy on port 7874 — if that proxy is down, DNS breaks for the whole LAN.
- `rebind_protection` is disabled — needed for local DNS rebinding (e.g., split-horizon DNS).
- Config backup: `sysupgrade -b /tmp/backup.tar.gz` (backs up `/etc/config/` and key files).
- Factory reset: `firstboot -y && reboot`.
- After power loss, check `logread` for filesystem errors (overlay fs on flash).
