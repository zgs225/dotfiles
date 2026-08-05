#!/usr/bin/env bash
# dpms-auto.sh — Per-power-source DPMS timeouts (screen-off delay).
#   AC      → DPMS_AC_SEC  (default 900s = 15 min)
#   battery → DPMS_BAT_SEC (default 300s = 5 min)
#
# Re-applies on every AC transition (udev event) and once on startup.
# Run as systemd user service: dpms-auto.service
set -u

AC_PATH="${DPMS_AUTO_AC_PATH:-/sys/class/power_supply/AC0/online}"
DPMS_AC_SEC="${DPMS_AC_SEC:-900}"
DPMS_BAT_SEC="${DPMS_BAT_SEC:-300}"
DEBOUNCE_SEC=3

on_ac() {
    [ "$(cat "$AC_PATH" 2>/dev/null || echo 0)" = "1" ]
}

apply_for_state() {
    local t
    if on_ac; then t="$DPMS_AC_SEC"; else t="$DPMS_BAT_SEC"; fi
    xset +dpms 2>/dev/null || true
    xset dpms "$t" "$t" "$t" 2>/dev/null || true
}

# ── main ────────────────────────────────────────────────────────────

apply_for_state
last_transition=$(date +%s)

# Two modes (same as brightness-auto.sh):
#   1. Event-driven (default): udevadm monitor — zero CPU when idle.
#   2. Polling fallback: when DPMS_AUTO_POLL_SEC is set (testing / no udev).
POLL_SEC="${DPMS_AUTO_POLL_SEC:-}"

if [ -n "$POLL_SEC" ]; then
    while sleep "$POLL_SEC"; do
        now=$(date +%s)
        (( now - last_transition < DEBOUNCE_SEC )) && continue
        last_transition=$now
        apply_for_state
    done
else
    while read -r line; do
        case "$line" in *power_supply/AC0*) ;; *) continue ;; esac
        now=$(date +%s)
        (( now - last_transition < DEBOUNCE_SEC )) && continue
        last_transition=$now
        apply_for_state
    done < <(udevadm monitor --subsystem-match=power_supply --udev 2>/dev/null)
fi

# Loop exited — let systemd restart us
exit 1
