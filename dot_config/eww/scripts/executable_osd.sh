#!/usr/bin/env bash
# EWW on-screen display for volume/brightness/mic media keys.
# Usage: osd.sh <volume-up|volume-down|volume-mute|mic-mute|brightness-up|brightness-down|brightness-auto [val]>
#
# Hardening (2026-08 forever-stuck OSD incident):
# * Every eww call passes --no-daemonize. eww 0.5's `open` AUTO-SPAWNS a
#   second daemon when it cannot reach the running one — it deletes the
#   original's socket file and rebinds the path itself (see main.rs spawn
#   branch). All later eww traffic then talks to the empty imposter while the
#   real daemon's windows become unreachable forever. That is exactly how the
#   OSD got stuck: the 2s auto-hide timer closed the imposter's window, never
#   the real daemon's.
# * Every eww call is time-bounded (`timeout`). eww 0.5 can wedge its main
#   thread while answering an `open` (the incident trigger: "ERROR sending
#   response from main thread", then silence) — an unbounded client would
#   block this script and the auto-hide timer would never be armed.
# * Health probe with self-heal: if the daemon is unreachable, restart it via
#   launch.sh (same recovery path the popup worker uses) instead of letting
#   `eww open` spawn an imposter; skip this OSD if the daemon does not come
#   back in time.

set -euo pipefail

TIMER_PID_FILE="/tmp/eww-osd-timer.pid"
OSD_OPEN_FLAG="/tmp/eww-osd-open.flag"
LAUNCH="$HOME/.config/eww/scripts/launch.sh"

# Time-bounded, spawn-proof eww client call.
eww_c() { timeout 3 eww "$@" --no-daemonize 2>/dev/null; }

if ! eww_c ping >/dev/null 2>&1; then
    # Daemon dead or wedged. Restart the real thing; never fall through to an
    # `eww open` that would spawn an imposter and hijack the socket path.
    i3-msg exec "$LAUNCH" >/dev/null 2>&1 || true
    up=1
    deadline=$(( $(date +%s) + 4 ))
    while [ "$(date +%s)" -lt "$deadline" ]; do
        sleep 0.25
        if timeout 1 eww ping --no-daemonize >/dev/null 2>&1; then
            up=0
            break
        fi
    done
    # The brightness/volume change itself already happened; the OSD is
    # cosmetic — skip it rather than blocking the media key any longer.
    [ "$up" -eq 0 ] || exit 0
fi

# Defensive reset: if eww was restarted, the window may be gone while the flag
# remains; clear it so this call reopens the OSD cleanly. Must use
# active-windows (actually OPEN windows) — list-windows names every DEFINED
# window and always contains osd, which made the old check a no-op.
if ! timeout 3 eww active-windows --no-daemonize 2>/dev/null | grep -q ': osd$'; then
    rm -f "$OSD_OPEN_FLAG"
fi

reset_timer() {
    if [ -f "$TIMER_PID_FILE" ]; then
        local old_pid
        old_pid=$(cat "$TIMER_PID_FILE" 2>/dev/null || true)
        if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid" 2>/dev/null || true
        fi
    fi
    (
        sleep 2
        timeout 3 eww close --no-daemonize osd 2>/dev/null || true
        rm -f "$OSD_OPEN_FLAG" "$TIMER_PID_FILE"
    ) &
    echo $! > "$TIMER_PID_FILE"
}

show_osd() {
    local icon="$1" label="$2" value="$3" color="$4"
    eww_c update osd_icon="$icon" osd_label="$label" osd_value="$value" osd_color="$color" || true
    if [ ! -f "$OSD_OPEN_FLAG" ]; then
        eww_c open osd || true
        touch "$OSD_OPEN_FLAG"
    fi
    reset_timer
}

volume_icon() {
    local vol="$1"
    if [ "$vol" -ge 66 ]; then
        echo "󰕾"
    elif [ "$vol" -ge 33 ]; then
        echo "󰖀"
    else
        echo "󰕿"
    fi
}

case "$1" in
    volume-up)
        pamixer -i 5
        vol=$(pamixer --get-volume)
        show_osd "$(volume_icon "$vol")" "音量" "$vol" "blue"
        ;;
    volume-down)
        pamixer -d 5
        vol=$(pamixer --get-volume)
        show_osd "$(volume_icon "$vol")" "音量" "$vol" "blue"
        ;;
    volume-mute)
        pamixer -t
        if [ "$(pamixer --get-mute)" = "true" ]; then
            show_osd "󰝟" "已静音" "0" "peach"
        else
            vol=$(pamixer --get-volume)
            show_osd "$(volume_icon "$vol")" "音量" "$vol" "blue"
        fi
        ;;
    mic-mute)
        pamixer --default-source -t
        if [ "$(pamixer --default-source --get-mute)" = "true" ]; then
            show_osd "󰍭" "麦克风关" "0" "red"
        else
            vol=$(pamixer --default-source --get-volume)
            show_osd "$(volume_icon "$vol")" "麦克风开" "$vol" "green"
        fi
        ;;
    brightness-up)
        brightnessctl set +5%
        br=$(brightnessctl info 2>/dev/null | grep -oP '([0-9]+)%' | head -1 | tr -d '%' || echo 0)
        show_osd "󰃝" "亮度" "$br" "yellow"
        ;;
    brightness-down)
        brightnessctl set 5%-
        br=$(brightnessctl info 2>/dev/null | grep -oP '([0-9]+)%' | head -1 | tr -d '%' || echo 0)
        show_osd "󰃜" "亮度" "$br" "yellow"
        ;;
    brightness-auto)
        br="${2:-$(brightnessctl info 2>/dev/null | grep -oP '([0-9]+)%' | head -1 | tr -d '%' || echo 0)}"
        show_osd "󰃠" "亮度(自动)" "$br" "yellow"
        ;;
    *)
        echo "Usage: $0 {volume-up|volume-down|volume-mute|mic-mute|brightness-up|brightness-down}" >&2
        exit 1
        ;;
esac
