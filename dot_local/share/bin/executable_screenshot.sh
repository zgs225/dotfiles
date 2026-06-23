#!/usr/bin/env bash

set -euo pipefail

dir="${SCREENSHOT_DIR:-$HOME/Pictures/screenshots}"
mkdir -p "$dir"

timestamp=$(date +%Y%m%d-%H%M%S)

case "${1:-full}" in
    select)
        grim -g "$(slurp)" "$dir/$timestamp.png"
        ;;
    full)
        grim "$dir/$timestamp.png"
        ;;
    *)
        echo "Usage: screenshot.sh [full|select]" >&2
        exit 1
        ;;
esac
