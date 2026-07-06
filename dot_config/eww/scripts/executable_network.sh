#!/usr/bin/env bash
# Called by defpoll every 5s — outputs key=value lines

if ! nmcli radio wifi 2>/dev/null | grep -q "enabled"; then
    echo "wifi_on=0"
    echo "wifi_icon=󰤭"
    echo "wifi_name=Disconnected"
    echo "wired=0"
    echo "wifi_networks="
    exit 0
fi

echo "wifi_on=1"

# Wired detection
if nmcli -t -f TYPE,STATE c show --active 2>/dev/null | grep -q "^802-3-ethernet"; then
    echo "wired=1"
    echo "wifi_icon=󰈀"
else
    echo "wired=0"
    echo "wifi_icon=󰤉"
fi

# Active SSID
ssid=$(nmcli -t -f NAME c show --active 2>/dev/null | grep -v '^lo$' | head -1)
echo "wifi_name=${ssid:-Disconnected}"

# Available networks formatted as yuck literal
networks_yuck=""
while IFS=':' read -r ssid security in_use; do
    [ -z "$ssid" ] && continue
    lock="󰉂"
    case "$security" in WPA1|WPA2|WPA3) lock="󰉃" ;; esac
    networks_yuck="${networks_yuck}(box :class \"wifi-network\" :onclick \"nmcli device wifi connect '${ssid}' 2>/dev/null || nm-connection-editor &\" (label :text \"${lock}  ${ssid}\" :class \"wifi-network-ssid\"))"
done < <(nmcli -t -f SSID,SECURITY device wifi list 2>/dev/null | sort -u)

echo "wifi_networks=$networks_yuck"
