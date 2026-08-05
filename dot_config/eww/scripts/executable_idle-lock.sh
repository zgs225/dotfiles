#!/usr/bin/env bash
# idle-lock.sh — Auto-lock on idle via xidlehook, per power source.
#   AC      → lock after LOCK_AC_SEC  (default 900s = 15 min)
#   battery → lock after LOCK_BAT_SEC (default 300s = 5 min)
# 30s after the lock fires, force the display off — matters on AC where
# dpms-auto.sh sets DPMS timeouts to 0 (screen would otherwise stay lit).
#
# The xidlehook child is restarted on AC/battery transitions so the active
# timeout always matches the power state.
# Run as systemd user service: idle-lock.service
set -u

AC_PATH="${IDLE_LOCK_AC_PATH:-/sys/class/power_supply/AC0/online}"
LOCK_AC_SEC="${LOCK_AC_SEC:-900}"
LOCK_BAT_SEC="${LOCK_BAT_SEC:-300}"
DEBOUNCE_SEC=3
LOCK_SCRIPT="$HOME/.config/i3/scripts/lock.sh"

XIDLE_PID=""

on_ac() {
    [ "$(cat "$AC_PATH" 2>/dev/null || echo 0)" = "1" ]
}

start_xidlehook() {
    local t
    if on_ac; then t="$LOCK_AC_SEC"; else t="$LOCK_BAT_SEC"; fi
    xidlehook \
        --timer "$t" "$LOCK_SCRIPT" "" \
        --timer 30 "xset dpms force off" "" \
        --not-when-fullscreen --not-when-audio --detect-sleep &
    XIDLE_PID=$!
}

restart_xidlehook() {
    [ -n "$XIDLE_PID" ] && kill "$XIDLE_PID" 2>/dev/null
    wait "$XIDLE_PID" 2>/dev/null
    start_xidlehook
}

# ── main ────────────────────────────────────────────────────────────

start_xidlehook
last_transition=$(date +%s)

# Two modes (same as brightness-auto.sh / dpms-auto.sh):
#   1. Event-driven (default): udevadm monitor — zero CPU when idle.
#   2. Polling fallback: when IDLE_LOCK_POLL_SEC is set (testing / no udev).
POLL_SEC="${IDLE_LOCK_POLL_SEC:-}"

if [ -n "$POLL_SEC" ]; then
    while sleep "$POLL_SEC"; do
        # Keep the child alive; if xidlehook dies, respawn it.
        if ! kill -0 "$XIDLE_PID" 2>/dev/null; then start_xidlehook; fi
        now=$(date +%s)
        (( now - last_transition < DEBOUNCE_SEC )) && continue
        last_transition=$now
        restart_xidlehook
    done
else
    while read -r line; do
        case "$line" in *power_supply/AC0*) ;; *) continue ;; esac
        now=$(date +%s)
        (( now - last_transition < DEBOUNCE_SEC )) && continue
        last_transition=$now
        restart_xidlehook
    done < <(udevadm monitor --subsystem-match=power_supply --udev 2>/dev/null)
fi

# Loop exited — let systemd restart us
exit 1
