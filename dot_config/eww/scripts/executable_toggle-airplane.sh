#!/usr/bin/env bash
# Toggle airplane mode: block/unblock all radios.
if [ -z "$EWW_TOGGLE_AIRPLANE_DETACHED" ]; then
    EWW_TOGGLE_AIRPLANE_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi
if rfkill list 2>/dev/null | grep -q "Soft blocked: no"; then
    rfkill block all
else
    rfkill unblock all
fi
# Airplane blocks every radio, so reflect airplane/wifi/bt back to the UI at
# once instead of waiting for the 5s airplane / 2s wifi-bt polls.
sleep 0.5
eww update airplane_on="$(~/.config/eww/scripts/airplane-on.sh)"
eww update wifi_on="$(~/.config/eww/scripts/network-wifi-on.sh)"
eww update bt_on="$(~/.config/eww/scripts/bt-on.sh)"
