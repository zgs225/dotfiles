#!/usr/bin/env bash
# Toggle bluetooth power.
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
