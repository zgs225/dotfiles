#!/usr/bin/env bash
# automount-daemon.sh -- user-level auto-mount for removable devices.
#
# Replaces the missing udev -> thunar-volman chain.  Listens to kernel block
# device events via ``udevadm monitor`` and mounts newly-inserted removable
# partitions through udisks2 (which places them under /run/media/$USER/<label>).
#
# WHAT COUNTS AS AUTOMOUNTABLE: udisks2's own Drive.Removable logic --
# sysfs /sys/block/<disk>/removable==1 OR the sysfs device path passes
# through a USB host.  (UDISKS_AUTO was dropped by udisks2 2.10+; the rules
# file no longer sets it.  ID_BUS is equally unusable: USB-SATA bridge chips
# make udev report ID_BUS=ata for the SATA disk behind them -- observed on a
# TOSHIBA HDD in a USB enclosure.  The sysfs path never lies: it contains a
# /usbN/ component iff the device is USB-attached.)
#
# EVENT MODEL (critical -- read before changing):
#   We react ONLY to ``add`` events, never ``change``.  A fresh USB insertion
#   creates the partition node -> ``add``.  A mount or unmount only changes the
#   filesystem state of an existing node -> ``change``.  If we reacted to
#   ``change`` we would re-mount a device the user just ejected via the eww
#   storage popup, silently undoing the eject (the original bug).  Reacting to
#   ``add`` only means: insert -> auto-mount; eject -> stays unmounted.
#
#   Devices already present when the daemon starts are handled by the one-shot
#   startup scan below, so nothing is missed on login.
#
# This script does NOT auto-open a file manager -- the eww storage-popup
# provides the "open" button for that.
#
# Lifecycle: started by i3 (exec --no-startup-id); the outer while loop
# restarts udevadm with bounded exponential backoff if it ever exits.

set -uo pipefail

LOG=/tmp/automount-daemon.log
PIDFILE=/tmp/automount-daemon.pid
BACKOFF=2

log() { echo "$(date '+%H:%M:%S') $*" >> "$LOG"; }

# ── Single-instance guard ─────────────────────────────────────────────
# Kill any stale previous instance by PROCESS GROUP (setsid makes the old
# leader's pid == its pgid, so -pid takes udevadm + the read-subshell too).
# We never use pgrep/pkill -f here: matching the command line is what kept
# killing the caller.  The pidfile is the only reliable handle.
if [ -f "$PIDFILE" ]; then
    _old=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$_old" ] && kill -0 "$_old" 2>/dev/null; then
        log "killing stale instance pgid=$_old"
        kill -- -"$_old" 2>/dev/null || kill "$_old" 2>/dev/null
        sleep 0.5
    fi
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

is_mounted() {
    grep -qF " $1 " /proc/mounts 2>/dev/null
}

# True for EFI / boot / recovery partitions we never want to auto-mount or
# surface (matches the collector's display filter).  Arg may be empty.
is_skip_label() {
    local u
    u=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
    case "$u" in
        *EFI* | *BOOT* | *SYSTEM* | *RECOVERY*) return 0 ;;
    esac
    return 1
}

# True when udisks2 would consider the parent drive removable (see header):
# sysfs removable flag OR USB-attached.  Pure sysfs reads, zero forks; used
# by both the startup scan and the live event loop.
is_hotpluggable() {
    local devname="$1"  # e.g. sdb1
    local real disk
    real=$(readlink -f "/sys/class/block/$devname" 2>/dev/null) || return 1
    [ -n "$real" ] || return 1
    disk=$(basename "$(dirname "$real")")
    [ "$(cat "/sys/block/$disk/removable" 2>/dev/null)" = "1" ] && return 0
    case "$real" in
        */usb*) return 0 ;;
    esac
    return 1
}

# Mount-failure notification.  The common NTFS case -- Windows fast startup
# or hibernation leaves the volume dirty and udisks2 refuses to mount --
# gets a targeted hint; anything else surfaces udisks2's own last error line.
notify_mount_failed() {
    local devpath="$1" out="$2"
    local label body
    label=$(lsblk -no LABEL "$devpath" 2>/dev/null)
    [ -n "$label" ] || label="$devpath"
    if printf '%s' "$out" | grep -qiE 'hibernat|unclean|dirty|unsafe'; then
        body="NTFS 卷处于休眠/脏状态：请完全关机 Windows（或关闭快速启动）后重试"
    else
        body=$(printf '%s' "$out" | tail -n 1)
    fi
    dunstify -a "eww" -i "drive-removable-media" -u critical \
        "挂载失败：${label}" "$body" >/dev/null 2>&1 || true
}

try_mount() {
    local devname="$1"
    local devpath="/dev/$devname"

    is_mounted "$devpath" && { log "skip (mounted): $devpath"; return 0; }
    # Callers gate on is_hotpluggable before invoking us.

    # Skip EFI / boot partitions (label known before mounting via lsblk/udev db)
    local label
    label=$(lsblk -no LABEL "$devpath" 2>/dev/null)
    if is_skip_label "$label"; then
        log "skip (efi/boot label '$label'): $devpath"
        return 0
    fi

    log "mounting: $devpath"
    local out
    if out=$(udisksctl mount -b "$devpath" 2>&1); then
        log "mounted OK: $devpath"
    else
        log "mount FAILED: $devpath: $out"
        notify_mount_failed "$devpath" "$out"
    fi
}

log "automount-daemon starting (pid $$)"

# ── Startup scan: mount already-inserted-but-unmounted data partitions ──
# Enumerate every partition that has a filesystem, keep only hotpluggable
# ones (see header).  try_mount handles mounted/label-skip/notify details.
while read -r devpath fstype; do
    [ -n "$devpath" ] && [ -n "$fstype" ] || continue
    is_hotpluggable "$(basename "$devpath")" || continue
    log "startup-mount: $devpath ($fstype)"
    try_mount "$(basename "$devpath")"
done < <(lsblk -pnro NAME,FSTYPE 2>/dev/null)

# ── Live monitor: react to device insertion (add) only ────────────────
while true; do
    udevadm monitor --subsystem-match=block --property --udev 2>/dev/null | {
        devname=""
        devtype=""
        fs_type=""
        action=""

        while IFS= read -r line; do
            if [ -z "$line" ]; then
                # End of one event block.
                if [ "$action" = "add" ] && [ "$devtype" = "partition" ] && [ -n "$devname" ]; then
                    # Probe-time race fallback: processed add usually carries
                    # ID_FS_TYPE, but if udev hasn't finished blkid, ask lsblk.
                    if [ -z "$fs_type" ]; then
                        fs_type=$(lsblk -no FSTYPE "/dev/$devname" 2>/dev/null)
                    fi
                    if [ -n "$fs_type" ]; then
                        if is_hotpluggable "$devname"; then
                            try_mount "$devname"
                        else
                            log "skip (not hotpluggable): /dev/$devname"
                        fi
                    fi
                fi
                devname=""; devtype=""; fs_type=""; action=""
                continue
            fi

            case "$line" in
                DEVNAME=/dev/*)  devname="${line#DEVNAME=/dev/}" ;;
                DEVTYPE=*)       devtype="${line#DEVTYPE=}" ;;
                ID_FS_TYPE=*)    fs_type="${line#ID_FS_TYPE=}" ;;
                ACTION=*)        action="${line#ACTION=}" ;;
            esac
        done
    }

    log "udevadm monitor exited, restarting in ${BACKOFF}s"
    sleep "$BACKOFF"
    BACKOFF=$((BACKOFF * 2))
    [ "$BACKOFF" -gt 30 ] && BACKOFF=30
done
