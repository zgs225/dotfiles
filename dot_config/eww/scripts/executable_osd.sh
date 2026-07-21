#!/usr/bin/env bash
# EWW on-screen display for volume/brightness/mic media keys.
# Usage: osd.sh <volume-up|volume-down|volume-mute|mic-mute|brightness-up|brightness-down>

set -euo pipefail

TIMER_PID_FILE="/tmp/eww-osd-timer.pid"
OSD_OPEN_FLAG="/tmp/eww-osd-open.flag"

# Defensive reset: if eww was restarted, the window may be gone while the flag
# remains; clear it so the next keypress reopens the OSD cleanly.
if ! eww list-windows 2>/dev/null | grep -q '^osd$'; then
    rm -f "$OSD_OPEN_FLAG"
fi

reset_timer() {
    if [ -f "$TIMER_PID_FILE" ]; then
        local old_pid
        old_pid=$(cat "$TIMER_PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            kill "$old_pid" 2>/dev/null || true
        fi
    fi
    (
        sleep 2
        eww close osd 2>/dev/null || true
        rm -f "$OSD_OPEN_FLAG" "$TIMER_PID_FILE"
    ) &
    echo $! > "$TIMER_PID_FILE"
}

show_osd() {
    local icon="$1" label="$2" value="$3" color="$4"
    eww update osd_icon="$icon" osd_label="$label" osd_value="$value" osd_color="$color" 2>/dev/null || true
    if [ ! -f "$OSD_OPEN_FLAG" ]; then
        eww open osd 2>/dev/null || true
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
            show_osd "󰍬" "麦克风开" "$vol" "green"
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
    *)
        echo "Usage: $0 {volume-up|volume-down|volume-mute|mic-mute|brightness-up|brightness-down}" >&2
        exit 1
        ;;
esac
