#!/usr/bin/env bash
# Shared network filtering logic for eww network scripts.
# Source this file: source "$(dirname "$0")/network-common.sh"

# Types that are never real user-facing network connections.
_EXCLUDE_TYPES="bridge loopback wifi-p2p dummy"

# Name patterns (pipe-separated for grep -E) to exclude virtual devices.
_EXCLUDE_NAME_PAT="^(docker[0-9]*|br-[0-9a-f]+|veth[0-9a-f]*|virbr[0-9]*|lo)$"

# Return 0 (true) if the connection type+name represents a real network
# connection that should be shown in the UI.
is_real_connection() {
    local type="$1" name="$2"
    for t in $_EXCLUDE_TYPES; do
        [ "$type" = "$t" ] && return 1
    done
    echo "$name" | grep -qE "$_EXCLUDE_NAME_PAT" && return 1
    return 0
}

# Emit filtered active connections: NAME:TYPE:DEVICE:ACTIVE
# Only includes connections that pass is_real_connection.
real_active_connections() {
    nmcli -t -f NAME,TYPE,DEVICE,STATE connection show --active 2>/dev/null \
        | while IFS=':' read -r name type device state; do
            [ -z "$name" ] && continue
            is_real_connection "$type" "$name" || continue
            active="no"
            [ "$state" = "activated" ] && active="yes"
            printf '%s:%s:%s:%s\n' "$name" "$type" "$device" "$active"
        done
}

# Emit filtered active WiFi connections only: NAME:TYPE:DEVICE:ACTIVE
real_wifi_conns() {
    real_active_connections | awk -F: '$2 ~ /^802-11-wireless$/'
}

# Emit filtered active wired connections only: NAME:TYPE:DEVICE:ACTIVE
# Excludes virtual ethernet (veth*, docker*).
real_wired_conns() {
    real_active_connections | awk -F: '$2 ~ /^802-3-ethernet$/'
}

# Emit filtered active VPN/tunnel connections: NAME:TYPE:DEVICE:ACTIVE
# Includes vpn, wireguard, tun types.
real_vpn_conns() {
    real_active_connections | awk -F: '$2 ~ /vpn|wireguard|tun/'
}
