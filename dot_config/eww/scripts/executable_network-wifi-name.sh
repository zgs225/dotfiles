#!/usr/bin/env bash
_selfdir="$(dirname "$0")"
source "${_selfdir}/network-common.sh"
ssid=$(real_wifi_conns | head -1 | cut -d: -f1)
echo "${ssid:-未连接}"
