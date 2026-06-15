#!/usr/bin/env bash

set -euo pipefail

dir="${SCREENSHOT_DIR:-$HOME/Pictures/screenshots}"
mkdir -p "$dir"

timestamp=$(date +%Y%m%d-%H%M%S)

case "${1:-full}" in
    select)
        maim -s "$dir/$timestamp.png"
        ;;
    full)
        maim "$dir/$timestamp.png"
        ;;
    *)
        echo "Usage: screenshot.sh [full|select]" >&2
        exit 1
        ;;
esac
