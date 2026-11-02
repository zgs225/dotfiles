# Proxmox VE — Host & Guests

Access: `ssh pve` | Host: `pve` @ 192.168.2.254
OS: PVE 9.0.3 (`pve-manager/9.0.3`) | Kernel: 6.17.13-2-pve | Ctrl: `pct` (CT) / `qm` (VM)

Storage: **single 1 TB NVMe** (Fanxiang S500Pro, consumer/DRAM-less) → LVM VG `pve` →
thin pool `pve/data` (816 GiB) + `pve/root` (96 G) + swap. Every guest disk is a thin LV.

## Guests

### LXC containers (`pct list`)

| VMID | Hostname | IP | Disk | State | Role |
|------|----------|----|------|-------|------|
| 102 | mysql | 192.168.2.8 | 16 G | running | MySQL |
| 104 | redis | 192.168.2.7 | 8 G | running | Redis |
| 1003 | pihole | 192.168.2.3 | 8 G | stopped | DNS |
| 1005 | apache-cassandra | 192.168.2.5 | 4 G | running | Cassandra |
| 1006 | influxdb | 192.168.2.6 | 74 G | running | InfluxDB 2.7.12 (PVE/Grafana/scrutiny metrics) |
| 1009 | postgresql | 192.168.2.9 | 32 G | running | PostgreSQL |
| 1010 | nginxproxymanager | 192.168.2.10 | 4 G | running | NPM (reverse proxy) |
| 1014 | rabbitmq | 192.168.2.14 | 4 G | running | RabbitMQ |

All containers also have a second NIC on `vmbr1` = 10.10.1.<last-octet>/16.

### VMs (`qm list`)

| VMID | Name | Mem | State | Notes |
|------|------|-----|-------|-------|
| 183 | dsm | 8 G | running | Synology DSM (see [synology-nas.md](synology-nas.md)) |
| 2031 | k3sagent01 | 12 G | running | k3s worker, 3 disks (32 + 128 + 128 G) |
| 2033 | k3sagent03 | 12 G | running | k3s worker, 3 disks (32 + 128 + 128 G) |
| 103 | nettool | 2 G | stopped | |
| 106 | debian12-tpl | 2 G | stopped | template |
| 1012 | android | 4 G | stopped | |
| 30003 | ENDEAVOUROS | 16 G | stopped | |

k3sagent02/04 are **not** on this host.

## Storage model — the thing that breaks everything

- All guest disks are LVM **thin** LVs. Sum of virtual sizes ≈ **1.15 TiB** on an 816 GiB pool
  (≈1.4× over-provisioned). If guests actually fill their virtual disks the pool overflows and
  **every VM and CT on the host dies at once**.
- `lvs -o data_percent <lv>` = how much of that thin LV's *virtual* size has ever been physically
  written. It is **not** free space, and it never shrinks until blocks are discarded.
- `df -h` *inside* the guest = real filesystem usage. This is the number that breaks services.
- Reading rule:

  | Symptom | Meaning | Fix |
  |---------|---------|-----|
  | `data_percent` ≫ `df%` | **orphaned blocks** — deleted inside guest, never TRIMmed | `pct fstrim <ct>` / `qm guest cmd <vm> fstrim` |
  | `df%` ≈ 100% | genuinely full | clean junk, then resize + fstrim |

## fstrim — the silent trap

Blocks freed inside a guest return to the thin pool **only** when the guest issues discard.
Three independent things break that for containers:

1. The host's `fstrim.timer` only trims host-mounted filesystems — never `/var/lib/lxc/*/rootfs`
   (container rootfs is *not* mounted on the host).
2. `fstrim.service` inside a container can never run — it carries
   `ConditionVirtualization=!container`, so `fstrim.timer` sits at
   `start condition failed` from container creation onwards.
3. Container rootfs is not mounted with `discard`, so on-line deletes don't free anything either.

**Mitigation (deployed 2026-11-02):**

| Path | Purpose |
|------|---------|
| `/usr/local/sbin/pct-fstrim-all.sh` | loops `pct fstrim` over every running container |
| `/etc/systemd/system/pct-fstrim.service` | oneshot wrapper (`Nice=19`, idle IO) |
| `/etc/systemd/system/pct-fstrim.timer` | `Sun 03:30`, `RandomizedDelaySec=10m`, `Persistent=true` |

```bash
systemctl list-timers pct-fstrim.timer        # next run
systemctl start pct-fstrim.service            # run now
journalctl -u pct-fstrim.service -n 20        # per-container "N bytes trimmed"
```

VMs: PVE disks are configured `discard=on`, but the **guest** still has to issue fstrim
(`fstrim.timer` works normally in a VM). On demand:
`qm guest cmd <vmid> fstrim` (requires qemu-guest-agent).

## Day-to-day storage commands

```bash
# Where is the space going?
lvs -o lv_name,lv_size,data_percent,pool_lv              # per-LV thin allocation
lvs -o lv_name,lv_size,data_percent,metadata_percent pve/data   # the pool itself
pvesm status | grep local-lvm

# One-line health sweep: fs% vs thin% for every container
for ct in $(pct list | awk 'NR>1 && $2=="running"{print $1}'); do
  f=$(pct exec $ct -- df --output=pcent / | tail -1 | tr -d ' %')
  d=$(lvs --noheadings -o data_percent pve/vm-${ct}-disk-0 | tr -d ' ')
  echo "$(pct config $ct | awk '/^hostname:/{print $2}')  fs=${f}%  thin=${d}%"
done

# Reclaim
pct fstrim <ct>                 # containers (safe, online)
qm guest cmd <vmid> fstrim      # VMs

# Resize (online for ext4)
pct resize <ct> rootfs +20G
```

Note: `pct fstrim` reports the ext4 free-block count it discarded, which is **much larger** than
what actually returns to the pool — most of those blocks were never allocated in the thin layer.
Trust `data_percent`, not the printed byte count.

## journald policy (containers)

journald defaults to 10 % of the filesystem — on a 4 G container that is 400 M, and mysql had
grown to **1.5 G** of journal before this policy existed.

| Rule | Value |
|------|-------|
| Disk ≤ 8 G | `SystemMaxUse=50M`, `SystemMaxFileSize=10M` |
| Disk ≥ 16 G | `SystemMaxUse=100M`, `SystemMaxFileSize=20M` |

Applied to **all** containers via `/etc/systemd/journald.conf.d/99-size.conf`:

```bash
pct exec <ct> -- sh -c 'mkdir -p /etc/systemd/journald.conf.d && \
  printf "[Journal]\nSystemMaxUse=50M\nSystemMaxFileSize=10M\n" \
  > /etc/systemd/journald.conf.d/99-size.conf'
pct exec <ct> -- systemctl restart systemd-journald   # cap applies immediately
pct exec <ct> -- journalctl --vacuum-size=50M
pct fstrim <ct>                                       # hand the freed blocks back
```

**Stopped containers** cannot be `pct exec`-ed — write through the mounted rootfs instead:

```bash
pct mount 1003
printf '[Journal]\nSystemMaxUse=50M\nSystemMaxFileSize=10M\n' \
  > /var/lib/lxc/1003/rootfs/etc/systemd/journald.conf.d/99-size.conf
pct unmount 1003
```

Current state (2026-11-02): 102=100M, 104=50M, 1003=50M, 1005=50M, 1006=100M, 1009=100M,
1010=50M, 1014=50M. Freed ~2.4 G total and returned it to the pool.

## InfluxDB LXC (1006) — 192.168.2.6

2 vCPU / 2 GB RAM / 74 G. Consumers: **PVE** (`/etc/pve/status.cfg` → bucket `pve`, every ~10 s),
**Grafana** (influxdb datasource, `defaultBucket=pve`), **scrutiny** (k3s, buckets `scrutiny*`).

### Config — flat keys only, sections are ignored

```ini
# /etc/default/influxdb2  (EnvironmentFile of influxdb.service)
INFLUXD_CONFIG_PATH=/etc/influxdb/config.toml
GOMEMLIMIT=1400MiB
```

> **Gotcha:** this build reads **flat, dash-joined keys**. A `[storage]` TOML section is accepted
> and **silently ignored** — influxd starts happily with defaults and `print-config` shows the
> defaults. Verified with test files 2026-11-02.

```toml
# /etc/influxdb/config.toml  — correct form
bolt-path   = "/var/lib/influxdb/influxd.bolt"
engine-path = "/var/lib/influxdb/engine"

storage-cache-max-memory-size              = 268435456   # 256MiB (default 1GiB/shard!)
storage-cache-snapshot-memory-size         = 33554432
storage-cache-snapshot-write-cold-duration = "10m0s"
storage-compact-full-write-cold-duration   = "4h0m0s"
storage-compact-throughput-burst           = 33554432    # 32MiB/s (consumer NVMe throttles)
storage-max-concurrent-compactions         = 1
storage-max-index-log-file-size            = 1048576
storage-retention-check-interval           = "15m0s"
storage-wal-fsync-delay                    = "100ms"
storage-wal-max-write-delay                = "10m0s"
storage-write-timeout                      = "20s"
storage-shard-precreator-advance-period    = "30m0s"
storage-shard-precreator-check-interval    = "10m0s"
```

Verify what actually took effect — `print-config` only reads the file when the env var is set:

```bash
pct exec 1006 -- env INFLUXD_CONFIG_PATH=/etc/influxdb/config.toml \
  influxd print-config | grep -E 'cache-max-memory|wal-fsync|write-timeout'
pct exec 1006 -- systemctl restart influxdb     # Type=forking, blocks until /ready
```

### Buckets / retention (as of 2026-11-02)

| Bucket | Retention | Size | Written by |
|--------|-----------|------|-----------|
| `pve` | 90 d | ~2.0 G | PVE status.cfg |
| `influxdb` | 7 d | empty | nothing (Self scraper **deleted**) |
| `scrutiny` | 15 d | < 10 M | scrutiny collector |
| `scrutiny_weekly` / `_monthly` / `_yearly` | 63 d / 756 d / ∞ | < 10 M | scrutiny |
| `_monitoring` / `_tasks` | 7 d / 3 d | small | influxd internal |

**Never re-enable the built-in `Self` scraper at 10 s × 90 d** — 11 141 series × 8 640 pts/day
grew to **41 GB** (85 % of the whole container). If self-monitoring is ever wanted: separate bucket,
7-day retention, longer scrape interval.

Admin token lives in the k3s repo: `~/Workspace/Misc/k3s-admin/scrutiny/kustomization.yaml`
(rewritten as the `scrutiny-web` secret; it is the org "admin's Token", so it can also manage
buckets/scrapers).

```bash
T=$(curl ... )   # or: kubectl -n scrutiny get secret -o jsonpath=... | base64 -d
curl -s -H "Authorization: Token $T" http://192.168.2.6:8086/api/v2/buckets   | jq
curl -s -H "Authorization: Token $T" http://192.168.2.6:8086/api/v2/scrapers  | jq
curl -s http://192.168.2.6:8086/health
```

## Runbook: storage incident

1. **`pct list` / `df` inside the guest** — is it real (`df%`≈100) or thin-level (`data%`) only?
2. If `data%`≫`df%` → `pct fstrim <ct>` / `qm guest cmd <vm> fstrim`. Done.
3. If genuinely full → `du -x -sh /* | sort -h` inside, plus `journalctl --disk-usage`,
   `du -sh /var/cache/apt/archives`, then clean → `pct resize` → `pct fstrim`.
4. Check the pool: `lvs -o data_percent,metadata_percent pve/data`. Above ~80 % stop and free space
   from the biggest LVs — a full thin pool takes down all guests.
5. Check for a hung influxd before blaming the k8s side (see below).

### Symptom → cause map (2026-11-02 incident)

| Symptom | Cause |
|---------|-------|
| k8s `scrutiny` web `CrashLoopBackOff`, exit code 2 after ~30 s | influxd unreachable at startup |
| `curl 192.168.2.6:8086/health` times out | influxd HTTP accept queue full (`ss -ltn` → `Recv-Q 4097/4096`) |
| influxd log `no space left on device` + `Error compacting TSM files` | thin LV at 100 %, no temp space for compaction |
| systemd `Failed with result 'oom-kill'`, `oom_memcg=/lxc/1006` | 2 GB cgroup + 1 GiB/shard write cache + compaction retry storm |
| `retention_check_duration_count = 0` | retention service never completes while the engine is stalled |

Fix order that worked: delete/free space **first** (bucket deletion frees shard files instantly;
`influx delete` does not — tombstones need space to compact), then tighten config, then
`systemctl restart influxdb`, then `pct fstrim 1006`.

## Known issues / watch list

- **`vm-2033-disk-2`** (k3sagent03, 128 G): `data_percent` **97.7 %** while the guest's LINSTOR
  `thin_pool` is only **13.9 %** (~18 G). ≈107 G of orphaned blocks: each new PVC triggers a full
  DRBD resync (writes the whole volume), and deletes never reach `/dev/sdc` because **DRBD does not
  pass discards through**. `qm guest cmd 2033 fstrim` runs but changes nothing. Reclaiming requires
  recreating the disk (drain node → detach → `lvremove` → recreate → restore). Not urgent — the pool
  has ~490 G free — but it is pure waste.
- **NVMe thermals**: `smartctl -a /dev/nvme0n1` → `Warning Comp. Temperature Time` ≈ 249 h,
  `Critical Comp. Temperature Time` ≈ 22 h, 545 758 thermal transitions, 45 °C idle. This is what
  turned a compaction into a **9-minute stall** (`op_elapsed=546136ms`). Needs a heatsink / airflow,
  not just tuning. Health otherwise fine (`Percentage Used 8 %`).
- **Thin pool over-provisioning**: lvm warns
  `Sum of all thin volume sizes (1.15 TiB) exceeds the size of thin pool pve/data (<952 GiB)`.
  Also `thin_pool_autoextend_threshold` is unset — set it (e.g. 80) if the pool should auto-grow.
- `issue_discards` is **not** set in the host `/etc/lvm/lvm.conf`, so fstrim only frees thin-pool
  chunks; discards never reach the SSD's FTL. Cosmetic for capacity, relevant for SSD GC.
- `dsm` storage is a CIFS mount at `/mnt/pve/dsm` and is 83 % full (2.9 T / 3.5 T).

## Misc

- `tune2fs -m 1 /dev/pve/vm-1006-disk-0` is **refused** while the LV is active: the ext4 is created
  with the `mmp` feature (`MMP: device currently active`). The 4 % root-reserved blocks (~3 G on
  74 G) are left in place on purpose — they act as a buffer the (non-root) database cannot eat.
- `pvesm status` "Available" for `local-lvm` is thin-pool free space, not VG free space
  (`pvs` showed PFree = 16 G while the pool had ~460 G). Don't confuse them.
