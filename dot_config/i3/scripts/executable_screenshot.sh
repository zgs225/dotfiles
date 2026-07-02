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

xclip -selection clipboard -t image/png < "$tmp"

choice=$(notify-send -u low \
    -t 10000 \
    -i "$tmp" \
    -A "default=Save" \
    -A "open=Open" \
    -A "opendir=Open folder" \
    "Screenshot copied" \
    "Click Save to keep a copy on disk" 2>/dev/null || true)

case "$choice" in
    default|open|opendir)
        final="$dir/$timestamp.png"
        cp "$tmp" "$final"
        case "$choice" in
            open)    feh "$final" >/dev/null 2>&1 & ;;
            opendir) xdg-open "$dir" >/dev/null 2>&1 & ;;
            default) : ;;
        esac
        ;;
esac
