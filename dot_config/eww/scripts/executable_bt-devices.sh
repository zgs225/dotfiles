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

paired_rows=""
other_rows=""
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
        audio-headphones)       dev_icon="󰋋" ;;
        audio-headset)          dev_icon="󰋎" ;;
        audio-card)             dev_icon="󰓃" ;;
        audio-input-microphone) dev_icon="󰍬" ;;
        input-keyboard)         dev_icon="󰌌" ;;
        input-mouse)            dev_icon="󰍽" ;;
        input-gaming)           dev_icon="󰊴" ;;
        input-tablet)           dev_icon="󰓶" ;;
        phone|modem)            dev_icon="󰄜" ;;
        computer|display)       dev_icon="󰍹" ;;
        camera-photo)           dev_icon="󰄀" ;;
        camera-video)           dev_icon="󰕧" ;;
        printer)                dev_icon="󰐪" ;;
        scanner)                dev_icon="󰐫" ;;
        *)                      dev_icon="󰂯" ;;
    esac

    if [ "$connected" -eq 1 ]; then
        rowcls="bt-device connected"
        primary_icon="󰂲"; primary_tip="Disconnect"; primary_act="disconnect"
    elif [ "$paired" -eq 1 ]; then
        rowcls="bt-device"
        primary_icon="󰂱"; primary_tip="Connect"; primary_act="connect"
    elif [ "$trusted" -eq 1 ]; then
        rowcls="bt-device stale"
        primary_icon="󰂱"; primary_tip="Connect"; primary_act="connect"
    else
        rowcls="bt-device"
        primary_icon="󰐕"; primary_tip="Pair"; primary_act="pair"
    fi

    e_name=$(esc "$name")

    row="(box :class \"${rowcls}\" :orientation \"h\" :spacing 10 :valign \"center\" :space-evenly false"
    row="${row}(label :class \"bt-dev-icon\" :text \"${dev_icon}\")"
    row="${row}(label :class \"bt-dev-name\" :xalign 0 :limit-width 16 :hexpand true :text \"${e_name}\")"
    row="${row}(button :class \"bt-act\" :tooltip \"${primary_tip}\""
    row="${row} :onclick \"~/.config/eww/scripts/bt-action.sh ${primary_act} ${mac}\""
    row="${row}(label :class \"bt-act-icon\" :text \"${primary_icon}\"))"
    row="${row}(button :class \"bt-act bt-danger\" :tooltip \"Forget\""
    row="${row} :onclick \"~/.config/eww/scripts/bt-action.sh forget ${mac}\""
    row="${row}(label :class \"bt-act-icon\" :text \"󰆴\")))"

    if [ "$connected" -eq 1 ] || [ "$paired" -eq 1 ] || [ "$trusted" -eq 1 ]; then
        paired_rows="${paired_rows}${row}"
    else
        other_rows="${other_rows}${row}"
    fi
done < <(bluetoothctl devices 2>/dev/null)

rows=""
if [ -n "$paired_rows" ]; then
    rows="${rows}${paired_rows}"
fi
if [ -n "$other_rows" ]; then
    rows="${rows}${other_rows}"
fi

if [ -z "$rows" ]; then
    if bluetoothctl show 2>/dev/null | grep -q "Discovering: yes"; then
        rows="(label :class \"bt-hint\" :xalign 0 :text \"Scanning...\")"
    else
        rows="(label :class \"bt-hint\" :xalign 0 :text \"No devices found\")"
    fi
fi
echo "(box :class \"bt-list\" :orientation \"v\" :spacing 2 ${rows})"
