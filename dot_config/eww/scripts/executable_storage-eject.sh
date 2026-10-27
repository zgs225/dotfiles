#!/bin/bash
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
# Before unmounting, processes holding the filesystem open are classified:
#
#   * non-whitelisted  -> abort the eject and tell the user to close them
#   * whitelisted AND holding a write-mode fd on the mount -> DO NOT KILL.
#       A file-manager copy in progress IS a write session: killing it
#       mid-flight truncates the file / loses remaining queue items.
#       Reproduced 2026-09-16: a 2GB copy from a comm=Thunar process was
#       killed by this script's old whitelist logic at 1.28GB -- data loss.
#       Instead we now WAIT (up to 60s) for the write to finish, then eject.
#   * whitelisted, read-only (browsing / gvfs monitors / indexers) -> killed
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

# ── eww client wrapper ────────────────────────────────────────────────
# --no-daemonize is load-bearing: `eww` client that cannot reach a wedged
# daemon must never auto-spawn a fake daemon over the real socket.
# 9>&- : never inherit the popup worker's flock fd (if launched from there).
ewwc() { timeout 4 eww "$@" --no-daemonize 9>&- 2>/dev/null; }

# ── Whitelist: processes that merely have the directory open ──────────
# These MAY browse / index / monitor / copy user data.  The whitelist only
# means "may be killed when it holds no write-mode fd"; see classify below.
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

MAX_WAIT=60   # seconds to wait for in-flight writes before giving up

# ── Notifications ─────────────────────────────────────────────────────
# $1=summary $2=body $3=icon $4=urgency(low|normal|critical)
_notify() {
    dunstify -a "eww" -i "$3" -u "$4" "$1" "$2" >/dev/null 2>&1 || true
}

# Popup-internal busy notice (visible while the popup is open).  Auto-clears.
# $1=message $2=clear-after seconds (default 4)
_set_busy() {
    ewwc update "storage_busy=$1" || true
    ( sleep "${2:-4}"; ewwc update "storage_busy=" || true ) &
    disown
}

# ── Write-fd detection ────────────────────────────────────────────────
# True when $1 has any fd open on $MOUNTPOINT with write access.
# fdinfo flags are octal; access mode is the low 2 bits:
#   0 = O_RDONLY, 1 = O_WRONLY, 2 = O_RDWR.  (O_PATH/O_DIRECTORY dirs are 0.)
has_write_fd() {
    local pid=$1 fdpath link flags
    for fdpath in "/proc/$pid/fd/"*; do
        [ -e "$fdpath" ] || continue
        link=$(readlink "$fdpath" 2>/dev/null) || continue
        case "$link" in
            "$MOUNTPOINT"|"$MOUNTPOINT"/*) ;;
            *) continue ;;
        esac
        flags=$(awk '/^flags:/ {print $2; exit}' \
            "/proc/$pid/fdinfo/${fdpath##*/}" 2>/dev/null) || continue
        [ -n "$flags" ] || continue
        if (( (8#$flags) & 3 )); then
            return 0
        fi
    done
    return 1
}

# ── 1. Classify occupying PIDs (re-runnable for the writer wait loop) ──
# Fills: BLOCKERS (csv) / WRITERS (csv "comm(pid)") / KILL_PIDS (array)
BLOCKERS=""
WRITERS=""
KILL_PIDS=()
classify_mount_users() {
    local pid comm whitelisted w
    BLOCKERS=""
    WRITERS=""
    KILL_PIDS=()

    mapfile -t PIDS < <(fuser -m "$MOUNTPOINT" 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+$' || true)

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

        if ! $whitelisted; then
            BLOCKERS="${BLOCKERS:+$BLOCKERS、}$comm"
        elif has_write_fd "$pid"; then
            WRITERS="${WRITERS:+$WRITERS、}${comm}(${pid})"
        else
            KILL_PIDS+=("$pid")
        fi
    done
}

classify_mount_users

# ── 2. Non-whitelisted processes -> abort ─────────────────────────────
if [ -n "$BLOCKERS" ]; then
    _set_busy "⚠ ${BLOCKERS} 正在使用设备"
    _notify "无法弹出 ${LABEL}" "${BLOCKERS} 正在使用设备，请先关闭" "dialog-warning" "normal"
    exit 1
fi

# ── 3. Whitelisted WRITERS -> wait for the copy to finish, never kill ──
if [ -n "$WRITERS" ]; then
    _set_busy "⏳ ${WRITERS} 正在写入，等待完成后弹出…" "$((MAX_WAIT + 8))"
    _notify "正在写入 ${LABEL}" "${WRITERS} 正在写入设备，将等待写入完成后弹出" "dialog-information" "normal"

    WAITED=0
    while (( WAITED < MAX_WAIT )); do
        sleep 2
        WAITED=$((WAITED + 2))
        classify_mount_users
        # A non-whitelisted holder appeared meanwhile -> normal busy abort.
        if [ -n "$BLOCKERS" ]; then
            _set_busy "⚠ ${BLOCKERS} 正在使用设备"
            _notify "无法弹出 ${LABEL}" "${BLOCKERS} 正在使用设备，请先关闭" "dialog-warning" "normal"
            exit 1
        fi
        [ -z "$WRITERS" ] && break
    done

    if [ -n "$WRITERS" ]; then
        _set_busy "⚠ ${WRITERS} 仍在写入"
        _notify "无法弹出 ${LABEL}" "${WRITERS} 仍在写入设备，请等待写入完成后再弹出" "dialog-warning" "normal"
        exit 1
    fi
fi

# ── 4. Kill read-only whitelisted processes ───────────────────────────
for pid in "${KILL_PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
done
[ ${#KILL_PIDS[@]} -gt 0 ] && sleep 1

# ── 5. Flush + unmount (small retry: freshly killed procs close async) ─
sync -f "$MOUNTPOINT" 2>/dev/null || true

UMOUNT_OK=0
for _ in 1 2 3; do
    if udisksctl unmount -b "$DEVICE" >/dev/null 2>&1; then
        UMOUNT_OK=1
        break
    fi
    sleep 1
done
if [ "$UMOUNT_OK" -ne 1 ]; then
    _set_busy "⚠ 卸载失败，设备可能仍在使用"
    _notify "弹出失败" "${LABEL} 卸载失败，请稍后重试" "dialog-error" "critical"
    exit 1
fi

# ── 6. Power off the parent drive ────────────────────────────────────
PKNAME=$(lsblk -no PKNAME "$DEVICE" 2>/dev/null | head -1)
if [ -n "$PKNAME" ]; then
    udisksctl power-off -b "/dev/$PKNAME" >/dev/null 2>&1 || true
fi

# ── 7. Success notification + optimistic UI update ───────────────────
_notify "已安全弹出" "${LABEL} 现在可以拔出了" "drive-removable-media" "low"
ewwc update "storage_busy=" || true

# Auto-close the popup if no removable mounts remain.  The automount daemon
# only reacts to device *add* events, so it will NOT re-mount what we just
# unmounted -- the count genuinely drops to zero here.
sleep 0.3
REMAINING=$(grep -c "/run/media/${USER}/" /proc/mounts 2>/dev/null || echo 0)
if [ "$REMAINING" -eq 0 ]; then
    CURRENT=$(ewwc get popup_open || echo "none")
    if [ "$CURRENT" = "storage-popup" ]; then
        ~/.config/eww/scripts/open-popup.sh close
    fi
fi

exit 0
