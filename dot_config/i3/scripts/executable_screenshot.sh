#!/usr/bin/env bash

set -euo pipefail

dir="${SCREENSHOT_DIR:-$HOME/Pictures/screenshots}"
mkdir -p "$dir"

timestamp=$(date +%Y%m%d-%H%M%S)

tmp=$(mktemp -t screenshot.XXXXXX.png)
trap 'rm -f "$tmp"' EXIT

mode="${1:-full}"
case "$mode" in
    select|full|ocr)
        case "$mode" in
            select) maim -s "$tmp" ;;
            full)   maim    "$tmp" ;;
            ocr)    maim -s "$tmp" ;;
        esac
        ;;
    *)
        echo "Usage: screenshot.sh [full|select|ocr]" >&2
        exit 1
        ;;
esac

cp "$tmp" "$dir/$timestamp.png"
xclip -selection clipboard -t image/png < "$tmp"

if [[ "$mode" == "ocr" ]]; then
    pre="$(mktemp -t screenshot.pre.XXXXXX.png)"
    trap 'rm -f "$tmp" "$pre"' EXIT

    magick "$tmp" -colorspace Gray -resize 200% "$pre" || pre="$tmp"

    text="$(tesseract "$pre" stdout -l chi_sim+eng --psm 6 --oem 1 2>/dev/null || true)"
    printf '%s' "$text" | xclip -selection clipboard -t text/plain
    snippet="${text:0:200}"
    [[ -z "$snippet" ]] && snippet="(no text recognized)"
    notify-send -u low -t 5000 \
        -i "$dir/$timestamp.png" \
        "OCR text copied to clipboard" \
        "$snippet" \
        || true
else
    thumb="/tmp/screenshot-thumb.png"
    magick "$tmp" -resize 400x300 "$thumb" 2>/dev/null || cp "$tmp" "$thumb"

    eww update screenshot_path="$dir/$timestamp.png" screenshot_thumb="$thumb"
    eww open screenshot-popup

    timer_pid_file="/tmp/eww-screenshot-timer.pid"
    if [ -f "$timer_pid_file" ]; then
        kill "$(cat "$timer_pid_file")" 2>/dev/null || true
    fi
    (sleep 6; eww close screenshot-popup 2>/dev/null || true; rm -f "$timer_pid_file") &
    echo $! > "$timer_pid_file"
fi
