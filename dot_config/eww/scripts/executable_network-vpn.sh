#!/usr/bin/env bash
# Called by defpoll (~5s). Emits a SINGLE root (box ...) yuck element listing
# configured VPN / WireGuard / tun connections with an active-state toggle.

_selfdir="$(dirname "$0")"
source "${_selfdir}/network-common.sh"

rows=""
while IFS=':' read -r name type device active; do
    [ -z "$name" ] && continue

    case "$type" in
        *wireguard*) icon="󰦝" ;;
        *vpn*)       icon="󰒙" ;;
        *tun*)       icon="󰒄" ;;
        *)           icon="󰒙" ;;
    esac

    e_name=$(printf '%s' "$name" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')

    if [ "$active" = "yes" ]; then
        state="on"; act="down"
        toggle="(box :class \"mini-switch on\" :valign \"center\" (box :class \"mini-knob\"))"
    else
        state="off"; act="up"
        toggle="(box :class \"mini-switch\" :valign \"center\" (box :class \"mini-knob\"))"
    fi

    type_cls=$(echo "$type" | sed 's/[^a-z]//g')
    rows="${rows}(button :class \"vpn-row ${type_cls}\" :onclick \"nmcli connection ${act} '${e_name}' &\""
    rows="${rows}(box :orientation \"h\" :spacing 12 :valign \"center\" :space-evenly false"
    rows="${rows}(label :class \"vpn-icon ${state}\" :text \"${icon}\")"
    rows="${rows}(label :class \"vpn-name\" :xalign 0 :hexpand true :text \"${e_name}\")"
    rows="${rows}${toggle}))"
done < <(real_vpn_conns)

if [ -z "$rows" ]; then
    rows="(label :class \"vpn-empty\" :xalign 0 :text \"No VPN configured\")"
fi
echo "(box :class \"vpn-list\" :orientation \"v\" :spacing 2 ${rows})"
