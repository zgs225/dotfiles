#!/usr/bin/env bash
# Toggle whether this adapter is visible to other devices.
# `discoverable on` uses BlueZ's default DiscoverableTimeout (180s), after
# which the adapter auto-hides — the 2s defpoll reflects that back to the
# switch automatically, so no extra timer is needed here.
# Detach so eww's 200ms onclick SIGKILL can't kill the post-toggle `eww update`.
if [ -z "$EWW_TOGGLE_DISC_DETACHED" ]; then
    EWW_TOGGLE_DISC_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi
if bluetoothctl show 2>/dev/null | grep -q "Discoverable: yes"; then
    bluetoothctl discoverable off
else
    bluetoothctl discoverable on
fi
sleep 0.3
eww update bt_discoverable="$(~/.config/eww/scripts/bt-discoverable-on.sh)"
