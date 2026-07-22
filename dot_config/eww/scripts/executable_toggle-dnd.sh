#!/usr/bin/env bash
# Toggle dunst do-not-disturb.
if [ -z "$EWW_TOGGLE_DND_DETACHED" ]; then
    EWW_TOGGLE_DND_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi
dunstctl set-paused toggle 2>/dev/null
eww update dnd="$(dunstctl is-paused 2>/dev/null || echo false)"
