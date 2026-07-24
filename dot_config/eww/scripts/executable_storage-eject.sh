#!/usr/bin/env bash
# storage-eject.sh -- safe unmount + power-off for removable devices.
#
# Usage: storage-eject.sh <mountpoint> <device>
#   e.g. storage-eject.sh "/run/media/yuez/Ventoy" /dev/sda1
#
# IMPORTANT -- eww onclick 200ms kill:
#   eww SIGKILLs any :onclick command still running after 200ms (crates/eww/
#   src/widgets/mod.rs).  This script does fuser + udisksctl D-Bus round-trips
#   (~250ms+), so it MUST detach immediately and do the real work in a
#   disconnected process, exactly like open-popup.sh.  Without the guard below
#   the button click appears to "do nothing" because eww kills us mid-run.
#
# Before unmounting, checks for processes holding the filesystem open.
# Whitelisted processes (file managers, GVFS daemons, indexers) are killed
# gracefully; anything else blocks the eject and the user is told (both in the
# popup via storage_busy and as a dunst notification) which processes to close.
#
# A dunst notification is emitted on every outcome (success / busy / failure).

set -euo pipefail

# ── Detach guard (see header) ─────────────────────────────────────────
if [ -z "${EWW_EJECT_DETACHED:-}" ]; then
    EWW_EJECT_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi

MOUNTPOINT="${1:?usage: storage-eject.sh <mountpoint> <device>}"
DEVICE="${2:?usage: storage-eject.sh <mountpoint> <device>}"
LABEL="$(basename "$MOUNTPOINT")"

# ── Whitelist: processes that merely have the directory open ──────────
# These browse / index / monitor but do NOT write user data.
WHITELIST=(
    Thunar thunar
    gvfsd gvfsd-fuse gvfsd-trash gvfsd-metadata
    gvfs-udisks2-volume-monitor
    gvfs-mtp-volume-monitor
    gvfs-afc-volume-monitor
    gvfs-gphoto2-volume-monitor
    tracker-miner-fs-3 tracker-miner-fs tracker-miner
    baloo_file baloo_file_extractor
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-gnome
    at-spi2-core
)

# ── Notifications ─────────────────────────────────────────────────────
# $1=summary $2=body $3=icon $4=urgency(low|normal|critical)
_notify() {
    dunstify -a "eww" -i "$3" -u "$4" "$1" "$2" >/dev/null 2>&1 || true
}

# Popup-internal busy notice (visible while the popup is open).  Auto-clears.
_set_busy() {
    eww update storage_busy="$1" 2>/dev/null || true
    ( sleep 4; eww update storage_busy="" 2>/dev/null || true ) &
    disown
}

# ── 1. Collect occupying PIDs ────────────────────────────────────────
mapfile -t PIDS < <(fuser -m "$MOUNTPOINT" 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+$' || true)

BLOCKERS=""
KILL_PIDS=()

for pid in "${PIDS[@]}"; do
    [ "$pid" = "$$" ] && continue
    comm=$(cat "/proc/$pid/comm" 2>/dev/null) || continue

    whitelisted=false
    for w in "${WHITELIST[@]}"; do
        if [[ "$comm" == "$w" ]]; then
            whitelisted=true
            break
        fi
    done

    if $whitelisted; then
        KILL_PIDS+=("$pid")
    else
        BLOCKERS="${BLOCKERS:+$BLOCKERS、}$comm"
    fi
done

# ── 2. Non-whitelisted processes -> abort ─────────────────────────────
if [ -n "$BLOCKERS" ]; then
    _set_busy "⚠ ${BLOCKERS} 正在使用设备"
    _notify "无法弹出 ${LABEL}" "${BLOCKERS} 正在使用设备，请先关闭" "dialog-warning" "normal"
    exit 1
fi

# ── 3. Kill whitelisted processes ────────────────────────────────────
for pid in "${KILL_PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
done
[ ${#KILL_PIDS[@]} -gt 0 ] && sleep 1

# ── 4. Unmount ───────────────────────────────────────────────────────
if ! udisksctl unmount -b "$DEVICE" >/dev/null 2>&1; then
    _set_busy "⚠ 卸载失败，设备可能仍在使用"
    _notify "弹出失败" "${LABEL} 卸载失败，请稍后重试" "dialog-error" "critical"
    exit 1
fi

# ── 5. Power off the parent drive ────────────────────────────────────
PKNAME=$(lsblk -no PKNAME "$DEVICE" 2>/dev/null | head -1)
if [ -n "$PKNAME" ]; then
    udisksctl power-off -b "/dev/$PKNAME" >/dev/null 2>&1 || true
fi

# ── 6. Success notification + optimistic UI update ───────────────────
_notify "已安全弹出" "${LABEL} 现在可以拔出了" "drive-removable-media" "low"
eww update storage_busy="" 2>/dev/null || true

# Auto-close the popup if no removable mounts remain.  The automount daemon
# only reacts to device *add* events, so it will NOT re-mount what we just
# unmounted -- the count genuinely drops to zero here.
sleep 0.3
REMAINING=$(grep -c "/run/media/${USER}/" /proc/mounts 2>/dev/null || echo 0)
if [ "$REMAINING" -eq 0 ]; then
    CURRENT=$(eww get popup_open 2>/dev/null || echo "none")
    if [ "$CURRENT" = "storage-popup" ]; then
        ~/.config/eww/scripts/open-popup.sh close
    fi
fi

exit 0
