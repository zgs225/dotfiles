#!/usr/bin/env bash
# screenshot-action.sh -- handle screenshot-popup button clicks (annotate/open/delete).
#
# IMPORTANT -- eww onclick 200ms kill:
#   eww SIGKILLs any :onclick command still running after 200ms (crates/eww/
#   src/widgets/mod.rs).  The annotate action launches satty (a GUI app that
#   blocks for the user's entire editing session).  Without the detach guard
#   below, eww kills /bin/sh after 200ms and satty dies with it — the user
#   sees "button clicked, nothing happened".
#
#   Additionally, eww daemon internal state can corrupt after long uptime:
#   `eww update` returns success but `eww get` returns empty.  When that
#   happens `satty --filename ""` fails immediately.  Restart the daemon
#   (`i3-msg exec launch.sh`) to recover.

set -euo pipefail

# Detach guard — eww SIGKILLs onclick commands after 200ms.
if [ -z "${EWW_SCREENSHOT_ACTION_DETACHED:-}" ]; then
    EWW_SCREENSHOT_ACTION_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi

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
