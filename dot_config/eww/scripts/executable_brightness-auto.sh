#!/usr/bin/env bash
# brightness-auto.sh — Auto-adjust screen brightness on AC/battery switch.
# Remembers user's preferred brightness per power state (macOS-style):
#   on transition, save current brightness for the OLD state,
#   then restore the saved brightness for the NEW state.
#
# Preferences: ~/.cache/eww/brightness-auto/{ac,bat}_level  (0-100)
# Run as systemd user service: brightness-auto.service
#
# Debounce design (v2): events arriving within DEBOUNCE_SEC of the last
# transition are ignored but never lost — a periodic re-check (read -t
# timeout in event mode, the poll loop in poll mode) re-compares sysfs
# against current_state, so charger flapping can no longer desync us.
set -u

AC_PATH="${BRIGHTNESS_AUTO_AC_PATH:-/sys/class/power_supply/AC0/online}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/eww/brightness-auto"
DEFAULT_AC=80
DEFAULT_BAT=40
DEBOUNCE_SEC=3
RECHECK_SEC="${BRIGHTNESS_AUTO_RECHECK_SEC:-30}"
OSD_SCRIPT="$HOME/.config/eww/scripts/osd.sh"
# udev filter tag, derived from AC_PATH (e.g. /sys/.../AC0/online → AC0)
AC_TAG="$(basename "$(dirname "$AC_PATH")")"

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
    local file="$CACHE_DIR/${1}_level" default val
    if [ "$1" = "ac" ]; then default=$DEFAULT_AC; else default=$DEFAULT_BAT; fi
    val=$(cat "$file" 2>/dev/null)
    case "$val" in
        ''|*[!0-9]*) echo "$default" ;;   # missing/corrupt → default
        *)           echo "$val" ;;
    esac
}

show_osd() {  # $1 = brightness value
    if [ "$OSD_SCRIPT" != "" ] && [ -x "$OSD_SCRIPT" ]; then
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
# Returns 0 if a real transition was processed, 1 if state unchanged.

handle_transition() {
    local new_state cur
    if on_ac; then new_state="ac"; else new_state="bat"; fi
    [ "$new_state" = "$current_state" ] && return 1

    # Save current brightness for the state we're leaving — but never
    # clobber a good pref with a bogus reading (0/empty/non-numeric).
    cur=$(get_brightness)
    if [ -n "$cur" ] && [ "$cur" -gt 0 ] 2>/dev/null; then
        save_pref "$current_state" "$cur"
    fi

    # Restore brightness for the state we're entering
    apply_for_state "$new_state"
    current_state="$new_state"
    return 0
}

# Debounced state check. Safe to call on every event and every re-check:
# it re-reads sysfs, so a swallowed event self-heals on the next call.
check_state() {
    local now
    now=$(date +%s)
    (( now - last_transition < DEBOUNCE_SEC )) && return 0
    if handle_transition; then
        last_transition=$now
    fi
    return 0
}

# ── main ─────────────────────────────────────────────────────────────

if on_ac; then current_state="ac"; else current_state="bat"; fi

# Apply saved preference for the current state on startup
apply_for_state "$current_state"

# Start at 0 so the very first real event is never swallowed by debounce.
last_transition=0

# Two modes:
#   1. Event-driven (default): udevadm monitor + read -t timeout re-check
#      every $RECHECK_SEC — zero CPU while idle, self-heals after any
#      swallowed/flapped event.
#   2. Polling fallback: when BRIGHTNESS_AUTO_POLL_SEC is set (testing /
#      no udev).
POLL_SEC="${BRIGHTNESS_AUTO_POLL_SEC:-}"

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
