#!/bin/sh
# Gracefully quit the app owning the focused window (macOS Cmd+Q style):
# 1. Send WM_DELETE to every window of the same PID (triggers normal close
#    handling, e.g. "save changes?" dialogs).
# 2. If the process is still alive but has no windows left (tray-only apps),
#    send SIGTERM so it can clean up and exit.
win=$(xdotool getactivewindow 2>/dev/null) || exit 0
[ -n "$win" ] || exit 0
pid=$(xprop -id "$win" _NET_WM_PID 2>/dev/null | grep -oE '[0-9]+')
[ -n "$pid" ] || exit 0

for w in $(xdotool search --pid "$pid" 2>/dev/null); do
    xdotool windowclose "$w" 2>/dev/null
done

sleep 0.5
# Use --onlyvisible: apps like Clash Verge hide to tray by *unmapping*
# their window, so a plain search would still find it and skip SIGTERM.
if kill -0 "$pid" 2>/dev/null && [ -z "$(xdotool search --onlyvisible --pid "$pid" 2>/dev/null)" ]; then
    kill "$pid" 2>/dev/null
fi
