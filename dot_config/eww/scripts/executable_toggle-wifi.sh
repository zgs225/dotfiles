#!/usr/bin/env bash
# eww SIGKILLs onclick children after 200ms; the sleep + `eww update` below
# exceed that, so detach immediately or the instant refresh never runs and the
# tile waits for the 2s poll.
if [ -z "$EWW_TOGGLE_WIFI_DETACHED" ]; then
    EWW_TOGGLE_WIFI_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi
# nmcli has no `radio wifi toggle` subcommand (only on/off) — read current
# state and invert. The old `nmcli radio wifi toggle` exited with an error
# ("invalid 'wifi' argument: 'toggle'"), silently swallowed by the detached
# nohup, so the switch did nothing.
if nmcli radio wifi 2>/dev/null | grep -q "enabled"; then
    nmcli radio wifi off
else
    nmcli radio wifi on
fi
sleep 0.5
eww update wifi_on="$(~/.config/eww/scripts/network-wifi-on.sh)"
eww update wifi_name="$(~/.config/eww/scripts/network-wifi-name.sh)"
eww update wifi_networks="$(~/.config/eww/scripts/network-wifi-networks.sh)"