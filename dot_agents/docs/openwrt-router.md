# OpenWrt Router

Access: `ssh router` | LAN IP: see [internal-topology.md](internal-topology.md)
OS: OpenWrt 23.05.5 (r24106) | Arch: aarch64 (Rockchip ARMv8) | Kernel: 6.6.54
Installed packages: ~717

## Network Layout

| Interface | Device | Config |
|-----------|--------|--------|
| LAN | `br-lan` (bridge: eth1 + eth2) | static `<lan-ip>`/23 (see [internal-topology.md](internal-topology.md)) |
| WAN | eth0 | (upstream) |

- Subnet: see [internal-topology.md](internal-topology.md) — must match `uci show network.lan`
- DNS: dnsmasq → forwards to `127.0.0.1#7874` (local proxy), `noresolv`, `rebind_protection` off
- Domain: `lan`
- DHCP: dnsmasq on LAN

## Key Config Files (UCI)

| File | Section | Purpose |
|------|---------|---------|
| `/etc/config/network` | interfaces, devices, routes | Network topology |
| `/etc/config/firewall` | zones, rules, forwards | Firewall (~104 rules/zones/forwards) |
| `/etc/config/dhcp` | dnsmasq, dhcp pools | DNS + DHCP |
| `/etc/config/wireless` | wifi-iface, wifi-device | WiFi (if applicable) |
| `/etc/config/system` | system, ntp, led | Hostname, timezone, LEDs |

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
