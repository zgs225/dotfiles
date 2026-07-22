#!/usr/bin/env bash
# Called by defpoll/deflisten. Emits a SINGLE root (box ...) yuck element listing
# available Wi-Fi networks (eww `literal` needs exactly one root).
# Each row: [connected dot] SSID .......... [lock] [signal]

source "$(dirname "$0")/network-common.sh"

if ! nmcli radio wifi 2>/dev/null | grep -q "enabled"; then
    echo "(box :class \"wifi-list\" :orientation \"v\" (label :class \"wifi-off-hint\" :xalign 0 :text \"无线网已关闭\"))"
    exit 0
fi

connected_ssid=$(real_wifi_conns | head -1 | cut -d: -f1)
connecting=$(eww get wifi_connecting 2>/dev/null | tr -d '"')

rows=""
while IFS=':' read -r in_use ssid signal security; do
    [ -z "$ssid" ] && continue

    if [ "${signal:-0}" -ge 75 ]; then sig="󰤨"
    elif [ "${signal:-0}" -ge 50 ]; then sig="󰤥"
    elif [ "${signal:-0}" -ge 25 ]; then sig="󰤢"
    else sig="󰤟"; fi

    lock="󰤾"
    secured=0
    case "$security" in *WPA*|*WEP*|*802*) lock="󰌾"; secured=1 ;; esac

    if [ "$ssid" = "$connected_ssid" ]; then
        dot="(box :class \"wifi-dot wifi-dot-on\" :valign \"center\")"
        rowcls="wifi-network connected"
    elif [ -n "$connecting" ] && [ "$ssid" = "$connecting" ]; then
        dot="(box :class \"wifi-dot\" :valign \"center\")"
        rowcls="wifi-network connecting"
    else
        dot="(box :class \"wifi-dot\" :valign \"center\")"
        rowcls="wifi-network"
    fi

    e_ssid=$(printf '%s' "$ssid" | sed -e 's/"/\\"/g')

    if [ -n "$connecting" ] && [ "$ssid" = "$connecting" ]; then
        tailw="(label :class \"wifi-signal\" :text \"连接中…\")"
    else
        if [ "$secured" -eq 1 ]; then lockw="(label :class \"wifi-lock\" :text \"$lock\")"; else lockw=""; fi
        tailw="${lockw}(label :class \"wifi-signal\" :text \"${sig}\")"
    fi

    rows="${rows}(button :class \"${rowcls}\" :onclick \"~/.config/eww/scripts/wifi-connect.sh '${e_ssid}'\""
    rows="${rows}(box :orientation \"h\" :spacing 10 :space-evenly false ${dot}"
    rows="${rows}(label :class \"wifi-ssid\" :xalign 0 :hexpand true :limit-width 20 :text \"${e_ssid}\")"
    rows="${rows}${tailw}))"
done < <(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null | awk -F: 'NF>=2 && $2!="" && !seen[$2]++' | head -6)

if [ -z "$rows" ]; then
    rows="(label :class \"wifi-off-hint\" :xalign 0 :text \"未发现网络\")"
fi
echo "(box :class \"wifi-list\" :orientation \"v\" :spacing 2 ${rows})"