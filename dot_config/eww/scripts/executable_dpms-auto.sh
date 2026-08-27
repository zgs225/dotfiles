#!/usr/bin/env bash
# dpms-auto.sh — Per-power-source DPMS timeouts (screen-off delay).
#   AC      → DPMS_AC_SEC  (default 0 = never; idle-lock.sh handles locking)
#   battery → DPMS_BAT_SEC (default 300s = 5 min)
#
# Debounce design (aligned with brightness-auto): events within DEBOUNCE_SEC
# are ignored but never lost — a periodic re-check re-compares sysfs against
# current_state, so charger flapping can no longer desync DPMS timeouts.
#
# Run as systemd user service: dpms-auto.service
set -u

AC_PATH="${DPMS_AUTO_AC_PATH:-/sys/class/power_supply/AC0/online}"
DPMS_AC_SEC="${DPMS_AC_SEC:-0}"
DPMS_BAT_SEC="${DPMS_BAT_SEC:-300}"
DEBOUNCE_SEC=3
RECHECK_SEC="${DPMS_AUTO_RECHECK_SEC:-30}"
# udev filter tag, derived from AC_PATH (e.g. /sys/.../AC0/online → AC0)
AC_TAG="$(basename "$(dirname "$AC_PATH")")"

DISPLAY="${DISPLAY:-:0}"
XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
export DISPLAY XAUTHORITY

current_state=""

on_ac() {
    [ "$(cat "$AC_PATH" 2>/dev/null || echo 0)" = "1" ]
}

wait_for_x() {
    local i
    for i in $(seq 1 60); do
        xset q >/dev/null 2>&1 && return 0
        sleep 1
    done
    echo "dpms-auto: X display $DISPLAY not ready after 60s" >&2
    return 1
}

apply_for_state() {  # $1 = ac|bat
    local t
    if [ "$1" = "ac" ]; then t="$DPMS_AC_SEC"; else t="$DPMS_BAT_SEC"; fi
    xset +dpms 2>/dev/null || true
    xset dpms "$t" "$t" "$t" 2>/dev/null || true
    current_state="$1"
    echo "dpms-auto: state=$1 timeout=${t}s" >&2
}

# Returns 0 if a real transition was processed, 1 if state unchanged.
handle_transition() {
    local new_state
    if on_ac; then new_state="ac"; else new_state="bat"; fi
    [ "$new_state" = "$current_state" ] && return 1
    apply_for_state "$new_state"
    return 0
}

# Debounced state check. Safe on every event and every re-check: re-reads
# sysfs, so a swallowed flap self-heals on the next call.
check_state() {
    local now
    now=$(date +%s)
    (( now - last_transition < DEBOUNCE_SEC )) && return 0
    if handle_transition; then
        last_transition=$now
    fi
    return 0
}

# ── main ────────────────────────────────────────────────────────────

wait_for_x || exit 1

if on_ac; then current_state="ac"; else current_state="bat"; fi
apply_for_state "$current_state"

# Start at 0 so the very first real event is never swallowed by debounce.
last_transition=0

# Two modes (same as brightness-auto.sh):
#   1. Event-driven (default): udevadm monitor + read -t timeout re-check
#      every $RECHECK_SEC — zero CPU when idle, self-heals after any
#      swallowed/flapped event.
#   2. Polling fallback: when DPMS_AUTO_POLL_SEC is set (testing / no udev).
POLL_SEC="${DPMS_AUTO_POLL_SEC:-}"

if [ -n "$POLL_SEC" ]; then
    while sleep "$POLL_SEC"; do
        check_state
    done
else
    while true; do
        line=""
        read -r -t "$RECHECK_SEC" line
        rc=$?
        if (( rc > 128 )); then
            # Timeout — periodic self-heal re-check
            check_state
            continue
        fi
        if (( rc != 0 )) && [ -z "$line" ]; then
            # EOF/error — udevadm died; let systemd restart us
            break
        fi
        case "$line" in *"$AC_TAG"*) ;; *) continue ;; esac
        check_state
        (( rc != 0 )) && break   # EOF after processing the final line
    done < <(udevadm monitor --subsystem-match=power_supply --udev 2>/dev/null)
fi

# Loop exited — let systemd restart us
exit 1
