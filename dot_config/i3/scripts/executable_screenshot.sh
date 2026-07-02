#!/usr/bin/env bash

set -euo pipefail

dir="${SCREENSHOT_DIR:-$HOME/Pictures/screenshots}"
mkdir -p "$dir"

timestamp=$(date +%Y%m%d-%H%M%S)

tmp=$(mktemp -t screenshot.XXXXXX.png)
trap 'rm -f "$tmp"' EXIT

case "${1:-full}" in
    select)
        maim -s "$tmp"
        ;;
    full)
        maim "$tmp"
        ;;
    *)
        echo "Usage: screenshot.sh [full|select]" >&2
        exit 1
        ;;
esac

cp "$tmp" "$dir/$timestamp.png"
xclip -selection clipboard -t image/png < "$tmp"
