#!/usr/bin/env bash
# automount-daemon.sh -- user-level auto-mount for removable devices.
#
# Replaces the missing udev -> thunar-volman chain.  Listens to kernel block
# device events via ``udevadm monitor`` and mounts newly-inserted removable
# partitions through udisks2 (which places them under /run/media/$USER/<label>).
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

is_removable() {
    local devname="$1"  # e.g. sda1
    local disk
    disk=$(basename "$(dirname "$(readlink -f "/sys/class/block/$devname" 2>/dev/null)" 2>/dev/null)" 2>/dev/null)
    [ -n "$disk" ] || return 1
    [ "$(cat "/sys/block/$disk/removable" 2>/dev/null)" = "1" ]
}

try_mount() {
    local devname="$1"
    local devpath="/dev/$devname"

    is_mounted "$devpath" && { log "skip (mounted): $devpath"; return 0; }
    is_removable "$devname" || return 0

    # Skip EFI / boot partitions (label known before mounting via lsblk/udev db)
    local label
    label=$(lsblk -no LABEL "$devpath" 2>/dev/null)
    if is_skip_label "$label"; then
        log "skip (efi/boot label '$label'): $devpath"
        return 0
    fi

    log "mounting: $devpath"
    if udisksctl mount -b "$devpath" >> "$LOG" 2>&1; then
        log "mounted OK: $devpath"
    else
        log "mount FAILED: $devpath"
    fi
}

log "automount-daemon starting (pid $$)"

# ── Startup scan: mount already-inserted-but-unmounted data partitions ──
for syspath in /sys/block/sd*/removable; do
    [ -f "$syspath" ] || continue
    [ "$(cat "$syspath" 2>/dev/null)" = "1" ] || continue
    disk=$(basename "$(dirname "$syspath")")
    for part in /sys/block/${disk}/${disk}*; do
        [ -d "$part" ] || continue
        pname=$(basename "$part")
        [ "$pname" = "$disk" ] && continue
        _fst=$(lsblk -no FSTYPE "/dev/$pname" 2>/dev/null)
        [ -n "$_fst" ] || continue
        _lbl=$(lsblk -no LABEL "/dev/$pname" 2>/dev/null)
        is_skip_label "$_lbl" && { log "startup-skip (efi/boot): /dev/$pname"; continue; }
        if ! is_mounted "/dev/$pname"; then
            log "startup-mount: /dev/$pname ($_fst)"
            udisksctl mount -b "/dev/$pname" >> "$LOG" 2>&1 || true
        fi
    done
done

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
                    [ -n "$fs_type" ] && try_mount "$devname"
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
