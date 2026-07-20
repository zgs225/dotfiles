#!/usr/bin/env bash
# Called by defpoll bt_devices. Emits a SINGLE root (box ...) yuck element
# listing known Bluetooth devices with per-device actions (eww `literal`
# needs exactly one root).
# Each row: [type icon] name / status .......... [connect|disconnect|pair] [forget]
# States: Connected / Paired (bond valid, not connected) / Stale (Trusted
# leftover but bond lost — phone still bonded, needs repair pair) / Not paired.

esc() { printf '%s' "$1" | sed -e 's/"/\\"/g'; }

if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    echo "(box :class \"bt-list\" :orientation \"v\" (label :class \"bt-hint\" :xalign 0 :text \"Bluetooth is off\"))"
    exit 0
fi

# Devices only show up in `bluetoothctl devices` while a discovery session is
# running (BlueZ drops unpaired devices when the discovering client exits).
# Hold a scan open for as long as the popup is visible, stop it afterwards.
if wmctrl -l 2>/dev/null | grep -q 'Eww - bluetooth-popup'; then
    ~/.config/eww/scripts/bt-scan.sh on
else
    ~/.config/eww/scripts/bt-scan.sh off
fi

rows=""
while read -r _ mac name; do
    case "$mac" in *:*) ;; *) continue ;; esac
    # Skip unnamed devices — BlueZ substitutes the MAC as name, pure noise.
    [ -z "$name" ] || [ "$name" = "$(printf '%s' "$mac" | tr ':' '-')" ] && continue

    info=$(bluetoothctl info "$mac" 2>/dev/null)
    connected=0; paired=0; trusted=0
    echo "$info" | grep -q "Connected: yes" && connected=1
    # Bonded covers LE-only devices where BlueZ reports Bonded without Paired.
    echo "$info" | grep -qE "(Paired|Bonded): yes" && paired=1
    echo "$info" | grep -q "Trusted: yes" && trusted=1
    icon_name=$(echo "$info" | awk -F': ' '/Icon: / {print $2; exit}')

    case "$icon_name" in
        audio-headphones|audio-headset|audio-card) dev_icon="󰋋" ;;
        input-keyboard) dev_icon="󰌌" ;;
        input-mouse)    dev_icon="󰍽" ;;
        phone|*phone*)  dev_icon="󰄜" ;;
        *)              dev_icon="󰂯" ;;
    esac

    if [ "$connected" -eq 1 ]; then
        status="Connected"; rowcls="bt-device connected"
        primary_icon="󰂲"; primary_tip="Disconnect"; primary_act="disconnect"
    elif [ "$paired" -eq 1 ]; then
        status="Paired"; rowcls="bt-device"
        primary_icon="󰂱"; primary_tip="Connect"; primary_act="connect"
    elif [ "$trusted" -eq 1 ]; then
        # Trusted flag survived a lost bond (keys cleared locally on
        # disconnect, remote side usually still bonded). Try connect first —
        # the remote often accepts and re-establishes the bond.
        status="Reconnect"; rowcls="bt-device stale"
        primary_icon="󰂱"; primary_tip="Connect"; primary_act="connect"
    else
        status="Not paired"; rowcls="bt-device"
        primary_icon="󰐕"; primary_tip="Pair"; primary_act="pair"
    fi

    e_name=$(esc "$name")

    rows="${rows}(box :class \"${rowcls}\" :orientation \"h\" :spacing 10 :valign \"center\" :space-evenly false"
    rows="${rows}(label :class \"bt-dev-icon\" :text \"${dev_icon}\")"
    rows="${rows}(box :orientation \"v\" :spacing 1 :hexpand true"
    rows="${rows}(label :class \"bt-dev-name\" :xalign 0 :limit-width 16 :text \"${e_name}\")"
    rows="${rows}(label :class \"bt-dev-status\" :xalign 0 :text \"${status}\"))"
    rows="${rows}(button :class \"bt-act\" :tooltip \"${primary_tip}\""
    rows="${rows} :onclick \"~/.config/eww/scripts/bt-action.sh ${primary_act} ${mac}\""
    rows="${rows}(label :class \"bt-act-icon\" :text \"${primary_icon}\"))"
    rows="${rows}(button :class \"bt-act bt-danger\" :tooltip \"Forget\""
    rows="${rows} :onclick \"~/.config/eww/scripts/bt-action.sh forget ${mac}\""
    rows="${rows}(label :class \"bt-act-icon\" :text \"󰆴\")))"
done < <(bluetoothctl devices 2>/dev/null)

if [ -z "$rows" ]; then
    if bluetoothctl show 2>/dev/null | grep -q "Discovering: yes"; then
        rows="(label :class \"bt-hint\" :xalign 0 :text \"Scanning...\")"
    else
        rows="(label :class \"bt-hint\" :xalign 0 :text \"No devices found\")"
    fi
fi
echo "(box :class \"bt-list\" :orientation \"v\" :spacing 2 ${rows})"
