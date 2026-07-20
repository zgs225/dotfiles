#!/usr/bin/env bash

set -euo pipefail

TIMER_PID_FILE="/tmp/eww-screenshot-timer.pid"

action="${1:-}"
path="$(eww get screenshot_path | tr -d '"')"

kill_timer() {
    if [ -f "$TIMER_PID_FILE" ]; then
        local old_pid
        old_pid=$(cat "$TIMER_PID_FILE")
        kill "$old_pid" 2>/dev/null || true
        rm -f "$TIMER_PID_FILE"
    fi
}

close_popup() {
    kill_timer
    eww close screenshot-popup 2>/dev/null || true
}

case "$action" in
    annotate)
        close_popup
        satty --filename "$path" --output-filename "$path" \
              --copy-command "xclip -selection clipboard -t image/png" \
              --early-exit
        ;;
    open)
        close_popup
        xdg-open "$path" &
        ;;
    delete)
        close_popup
        rm -f "$path"
        ;;
    *)
        echo "Usage: screenshot-action.sh [annotate|open|delete]" >&2
        exit 1
        ;;
esac
