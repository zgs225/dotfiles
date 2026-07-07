#!/usr/bin/env bash
ssid=$(nmcli -t -f NAME c show --active 2>/dev/null | grep -v '^lo$' | head -1)
echo "${ssid:-Disconnected}"
