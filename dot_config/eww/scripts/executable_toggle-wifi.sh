#!/usr/bin/env bash
# eww SIGKILLs onclick children after 200ms; the sleep + `eww update` below
# exceed that, so detach immediately or the instant refresh never runs and the
# tile waits for the 2s poll.
if [ -z "$EWW_TOGGLE_WIFI_DETACHED" ]; then
    EWW_TOGGLE_WIFI_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi
nmcli radio wifi toggle
sleep 0.5
eww update wifi_on="$(~/.config/eww/scripts/network-wifi-on.sh)"
eww update wifi_name="$(~/.config/eww/scripts/network-wifi-name.sh)"
eww update wifi_networks="$(~/.config/eww/scripts/network-wifi-networks.sh)"