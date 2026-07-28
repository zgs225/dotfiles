#!/bin/sh
# Force-kill the process owning the currently focused window (kill -9).
win=$(xdotool getactivewindow 2>/dev/null) || exit 0
[ -n "$win" ] || exit 0
pid=$(xprop -id "$win" _NET_WM_PID 2>/dev/null | grep -oE '[0-9]+')
[ -n "$pid" ] && kill -9 "$pid"
