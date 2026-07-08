#!/usr/bin/env bash
# Network event monitor for eww - provides instant UI updates on network changes
# Called by deflisten - each line of output updates the wifi_networks variable

WIFI_SCRIPT="$HOME/.config/eww/scripts/network-wifi-networks.sh"

while true; do
    # Output current wifi networks (each line updates the variable)
    "$WIFI_SCRIPT"
    
    # Wait for network changes by polling connection state
    last_wifi=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep 802-11-wireless)
    while true; do
        sleep 2
        current_wifi=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep 802-11-wireless)
        if [ "$current_wifi" != "$last_wifi" ]; then
            last_wifi="$current_wifi"
            break  # Output will happen in next iteration of outer loop
        fi
    done
done