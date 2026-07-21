#!/usr/bin/env bash
# Network status script using nmcli device show
# Outputs JSON: {"type":"wifi|wired|none","name":"...","icon":"..."}

_exclude_types="bridge loopback wifi-p2p dummy tun"
_exclude_pat="^(docker[0-9]*|br-[0-9a-f]+|veth[0-9a-f]*|virbr[0-9]*|lo|p2p-)"

is_excluded() {
    local device="$1" type="$2"
    for t in $_exclude_types; do [ "$type" = "$t" ] && return 0; done
    echo "$device" | grep -qE "$_exclude_pat" && return 0
    return 1
}

get_status() {
    while IFS=':' read -r device type state; do
        [ -z "$device" ] && continue
        is_excluded "$device" "$type" && continue
        [ "$type" = "ethernet" ] && [ "$state" = "connected" ] && wired_dev="$device" && break
    done < <(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null)

    if [ -n "$wired_dev" ]; then
        name=$(nmcli -t -f GENERAL.CONNECTION device show "$wired_dev" 2>/dev/null | cut -d: -f2)
        echo "{\"type\":\"wired\",\"name\":\"${name:-以太网}\",\"icon\":\"󰈀\"}"
        return
    fi

    while IFS=':' read -r device type state; do
        [ -z "$device" ] && continue
        is_excluded "$device" "$type" && continue
        [ "$type" = "wifi" ] && [ "$state" = "connected" ] && wifi_dev="$device" && break
    done < <(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null)

    if [ -n "$wifi_dev" ]; then
        name=$(nmcli -t -f GENERAL.CONNECTION device show "$wifi_dev" 2>/dev/null | cut -d: -f2)
        echo "{\"type\":\"wifi\",\"name\":\"${name:-无线网}\",\"icon\":\"󰤨\"}"
        return
    fi

    echo "{\"type\":\"none\",\"name\":\"未连接\",\"icon\":\"󰤭\"}"
}

get_status