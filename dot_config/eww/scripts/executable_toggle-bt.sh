#!/usr/bin/env bash
# Toggle bluetooth power.
# Detach so eww's 200ms onclick SIGKILL can't kill the post-toggle `eww update`
# (bluetoothctl power on/off alone can exceed 200ms on a loaded system).
if [ -z "$EWW_TOGGLE_BT_DETACHED" ]; then
    EWW_TOGGLE_BT_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi
if command -v bluetoothctl >/dev/null 2>&1; then
    if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
        bluetoothctl power off
    else
        rfkill unblock bluetooth 2>/dev/null
        bluetoothctl power on
    fi
    sleep 0.5
    eww update bt_on="$(~/.config/eww/scripts/bt-on.sh)"
    exit 0
fi
rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: yes" && rfkill unblock bluetooth || rfkill block bluetooth
