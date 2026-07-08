#!/usr/bin/env bash
_selfdir="$(dirname "$0")"
source "${_selfdir}/network-common.sh"
real_wired_conns | head -1 | cut -d: -f1 | grep -q . && echo 1 || echo 0
