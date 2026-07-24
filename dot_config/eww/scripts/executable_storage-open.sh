#!/usr/bin/env bash
# storage-open.sh -- open a mountpoint in Thunar.
# Usage: storage-open.sh <mountpoint>
#
# Detach guard: eww SIGKILLs :onclick commands still alive after 200ms.
# Launching Thunar can occasionally exceed that, so we detach first and let
# the real launch run disconnected (same pattern as open-popup.sh / eject).
set -euo pipefail

if [ -z "${EWW_OPEN_DETACHED:-}" ]; then
    EWW_OPEN_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi

thunar "${1:?usage: storage-open.sh <mountpoint>}" &
disown
