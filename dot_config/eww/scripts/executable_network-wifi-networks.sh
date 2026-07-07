#!/usr/bin/env bash
# Called by defpoll (~5s). Emits a SINGLE root (box ...) yuck element listing
# available Wi-Fi networks (eww `literal` needs exactly one root).
# Each row: [connected dot] SSID .......... [lock] [signal]

if ! nmcli radio wifi 2>/dev/null | grep -q "enabled"; then
    echo "(box :class \"wifi-list\" :orientation \"v\" (label :class \"wifi-off-hint\" :xalign 0 :text \"Wi-Fi is off\"))"
    exit 0
fi

rows=""
while IFS=':' read -r in_use ssid signal security; do
    [ -z "$ssid" ] && continue

    # Signal icon by strength bucket.
    if   [ "${signal:-0}" -ge 75 ]; then sig="󰤨"
    elif [ "${signal:-0}" -ge 50 ]; then sig="󰤥"
    elif [ "${signal:-0}" -ge 25 ]; then sig="󰤢"
    else sig="󰤟"; fi

    lock="󰤾"   # open network glyph slot (kept blank-ish)
    secured=0
    case "$security" in *WPA*|*WEP*|*802*) lock="󰌾"; secured=1 ;; esac

    if [ "$in_use" = "*" ]; then
        dot="(box :class \"wifi-dot wifi-dot-on\" :valign \"center\")"
        rowcls="wifi-network connected"
    else
        dot="(box :class \"wifi-dot\" :valign \"center\")"
        rowcls="wifi-network"
    fi

    e_ssid=$(printf '%s' "$ssid" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')

    if [ "$secured" -eq 1 ]; then lockw="(label :class \"wifi-lock\" :text \"$lock\")"; else lockw=""; fi

    rows="${rows}(button :class \"${rowcls}\" :onclick \"nmcli device wifi connect '${e_ssid}' 2>/dev/null || nm-connection-editor &\""
    rows="${rows}(box :orientation \"h\" :spacing 10 :space-evenly false ${dot}"
    rows="${rows}(label :class \"wifi-ssid\" :xalign 0 :hexpand true :limit-width 20 :text \"${e_ssid}\")"
    rows="${rows}${lockw}(label :class \"wifi-signal\" :text \"${sig}\")))"
done < <(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null | awk -F: 'NF>=2 && $2!="" && !seen[$2]++' | head -6)

if [ -z "$rows" ]; then
    rows="(label :class \"wifi-off-hint\" :xalign 0 :text \"No networks found\")"
fi
echo "(box :class \"wifi-list\" :orientation \"v\" :spacing 2 ${rows})"
