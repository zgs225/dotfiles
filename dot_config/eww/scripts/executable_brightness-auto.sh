#!/usr/bin/env bash
# brightness-auto.sh — Auto-adjust screen brightness on AC/battery switch.
# Remembers user's preferred brightness per power state (macOS-style):
#   on transition, save current brightness for the OLD state,
#   then restore the saved brightness for the NEW state.
#
# Preferences: ~/.cache/eww/brightness-auto/{ac,bat}_level  (0-100)
# Run as systemd user service: brightness-auto.service
set -u

AC_PATH="${BRIGHTNESS_AUTO_AC_PATH:-/sys/class/power_supply/AC0/online}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/eww/brightness-auto"
DEFAULT_AC=80
DEFAULT_BAT=40
DEBOUNCE_SEC=3
OSD_SCRIPT="$HOME/.config/eww/scripts/osd.sh"

mkdir -p "$CACHE_DIR"

# ── helpers ──────────────────────────────────────────────────────────

get_brightness() {
    brightnessctl info 2>/dev/null | grep -oP '(\d+)%' | head -1 | tr -d '%' || echo 0
}

set_brightness() {
    brightnessctl set "$1%" >/dev/null 2>&1 || true
}

on_ac() {
    [ "$(cat "$AC_PATH" 2>/dev/null || echo 0)" = "1" ]
}

save_pref() {  # $1 = ac|bat   $2 = 0-100
    echo "$2" > "$CACHE_DIR/${1}_level"
}

load_pref() {  # $1 = ac|bat → prints saved value or default
    local file="$CACHE_DIR/${1}_level" default
    if [ "$1" = "ac" ]; then default=$DEFAULT_AC; else default=$DEFAULT_BAT; fi
    if [ -f "$file" ]; then cat "$file"; else echo "$default"; fi
}

show_osd() {  # $1 = brightness value
    if [ -x "$OSD_SCRIPT" ]; then
        "$OSD_SCRIPT" brightness-auto "$1" &
        disown
    fi
}

apply_for_state() {  # $1 = ac|bat
    local level
    level=$(load_pref "$1")
    set_brightness "$level"
    show_osd "$level"
}

# ── state transition handler ─────────────────────────────────────────

handle_transition() {
    if on_ac; then new_state="ac"; else new_state="bat"; fi
    [ "$new_state" = "$current_state" ] && return 0

    # Save current brightness for the state we're leaving
    save_pref "$current_state" "$(get_brightness)"

    # Restore brightness for the state we're entering
    apply_for_state "$new_state"
    current_state="$new_state"
}

# ── main ────────────────────────────────────────────────────────────

if on_ac; then current_state="ac"; else current_state="bat"; fi

# Apply saved preference for the current state on startup
apply_for_state "$current_state"

last_transition=$(date +%s)

# Two modes:
#   1. Event-driven (default): udevadm monitor — zero CPU when idle.
#   2. Polling fallback: when BRIGHTNESS_AUTO_POLL_SEC is set (testing / no udev).
POLL_SEC="${BRIGHTNESS_AUTO_POLL_SEC:-}"

if [ -n "$POLL_SEC" ]; then
    while sleep "$POLL_SEC"; do
        now=$(date +%s)
        (( now - last_transition < DEBOUNCE_SEC )) && continue
        last_transition=$now
        handle_transition
    done
else
    while read -r line; do
        case "$line" in *power_supply/AC0*) ;; *) continue ;; esac
        now=$(date +%s)
        (( now - last_transition < DEBOUNCE_SEC )) && continue
        last_transition=$now
        handle_transition
    done < <(udevadm monitor --subsystem-match=power_supply --udev 2>/dev/null)
fi

# Loop exited — let systemd restart us
exit 1
