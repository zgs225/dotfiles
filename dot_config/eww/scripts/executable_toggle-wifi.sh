#!/usr/bin/env bash
nmcli radio wifi toggle
sleep 0.5
eww update wifi_on="$(~/.config/eww/scripts/network-wifi-on.sh)"
eww update wifi_name="$(~/.config/eww/scripts/network-wifi-name.sh)"
eww update wifi_networks="$(~/.config/eww/scripts/network-wifi-networks.sh)"