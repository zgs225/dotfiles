#!/usr/bin/env bash
# Called by defpoll (~5s). Emits a SINGLE root (box ...) yuck element
# showing the current wired (802-3-ethernet) connection status.

_selfdir="$(dirname "$0")"
source "${_selfdir}/network-common.sh"

row=$(real_wired_conns | head -1)

if [ -n "$row" ]; then
    device=$(echo "$row" | cut -d: -f3)
    name=$(echo "$row" | cut -d: -f1)
    e_dev=$(printf '%s' "$device" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    e_name=$(printf '%s' "$name" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    echo "(box :class \"wired-list\" :orientation \"v\" (box :class \"wired-row wired-active\" :orientation \"h\" :spacing 12 :valign \"center\" (label :class \"wired-icon\" :text \"󰈀\") (label :class \"wired-name\" :xalign 0 :hexpand true :text \"${e_name}\") (label :class \"wired-device\" :text \"${e_dev}\")))"
else
    echo "(box :class \"wired-list\" :orientation \"v\" (label :class \"wired-empty\" :xalign 0 :text \"No wired connection\"))"
fi
