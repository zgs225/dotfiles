#!/usr/bin/env bash
# Toggle whether this adapter is visible to other devices.
# `discoverable on` uses BlueZ's default DiscoverableTimeout (180s), after
# which the adapter auto-hides — the 2s defpoll reflects that back to the
# switch automatically, so no extra timer is needed here.
if bluetoothctl show 2>/dev/null | grep -q "Discoverable: yes"; then
    bluetoothctl discoverable off
else
    bluetoothctl discoverable on
fi
sleep 0.3
eww update bt_discoverable="$(~/.config/eww/scripts/bt-discoverable-on.sh)"
