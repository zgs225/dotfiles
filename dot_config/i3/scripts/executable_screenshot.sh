#!/usr/bin/env bash
# screenshot.sh — region screenshots with a FROZEN screen.
#
# select/ocr modes: capture the full virtual desktop the instant the hotkey
# fires, overlay every monitor with its frozen image (freeze-overlay:
# override-redirect + MIT-SHM, maps all screens in one XSync), let the user
# drag a region over the frozen picture (slop), then crop the region from
# the frozen frame — never from a second live capture. Handles any number
# of monitors (parsed from xrandr at runtime).

set -euo pipefail

dir="${SCREENSHOT_DIR:-$HOME/Pictures/screenshots}"
mkdir -p "$dir"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

timestamp=$(date +%Y%m%d-%H%M%S)

tmp=$(mktemp -t screenshot.XXXXXX.png)
work=""                 # freeze-overlay workspace (select/ocr only)
pre=""                  # OCR preprocessing image
overlay_pids=()

cleanup() {
    local p
    for p in "${overlay_pids[@]:-}"; do
        kill "$p" 2>/dev/null || true
    done
    [[ -n "$work" ]] && rm -rf "$work"
    [[ -n "$pre" ]] && rm -f "$pre"
    rm -f "$tmp"
}
trap cleanup EXIT

ensure_overlay_bin() {
    local bin="$script_dir/freeze-overlay" src="$script_dir/freeze-overlay.c"
    if [[ ! -x "$bin" || "$src" -nt "$bin" ]]; then
        gcc -O2 -o "$bin" "$src" -lX11 -lXext -lXinerama
    fi
}

overlays_hide() {
    local p
    for p in "${overlay_pids[@]:-}"; do
        kill "$p" 2>/dev/null || true
    done
    overlay_pids=()
}

# Freeze-then-select: crops the chosen region into $tmp.
# Returns 1 when the user cancels.
freeze_select() {
    work=$(mktemp -d -t screenshot-freeze.XXXXXX)
    mkfifo "$work/ready"
    # -u: no cursor in the frozen frame (the live cursor still moves above it)
    # bmp: ~5x faster than PNG at this size; PNG only for the final crop
    maim -u -f bmp "$work/full.bmp"

    # freeze-overlay discovers monitors itself via Xinerama (xrandr/RandR
    # stalls >1.5s on a lazy EDID reprobe — never call it on the hot path)
    ensure_overlay_bin
    "$script_dir/freeze-overlay" "$work/ready" "$work/full.bmp" &
    overlay_pids+=("$!")

    # Overlay announces readiness only after every window is mapped+synced.
    if ! read -r -t 5 _ <> "$work/ready"; then
        return 1
    fi

    local geo="" rc=0
    # -t 0: drag-only selection — with overlays on top, slop's window-click
    # mode would select the overlay instead of the real window.
    geo=$(slop -t 0 -f "%wx%h+%x+%y") || rc=$?
    overlays_hide
    if (( rc != 0 )) || [[ -z "$geo" ]]; then
        return 1
    fi

    # Ignore empty regions (bare click).
    local rw rh
    IFS='x+' read -r rw rh _ <<< "$geo"
    if (( rw <= 0 || rh <= 0 )); then
        return 1
    fi

    magick "$work/full.bmp" -crop "$geo" +repage "$tmp"
    return 0
}

mode="${1:-full}"
case "$mode" in
    select|ocr)
        freeze_select || { exit 0; }      # cancelled: quiet exit
        ;;
    full)
        maim "$tmp"
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

    eww update screenshot_path="$dir/$timestamp.png" screenshot_thumb="$thumb" screenshot_kind=png
    eww open screenshot-popup

    timer_pid_file="/tmp/eww-screenshot-timer.pid"
    if [ -f "$timer_pid_file" ]; then
        kill "$(cat "$timer_pid_file")" 2>/dev/null || true
    fi
    (sleep 6; eww close screenshot-popup 2>/dev/null || true; rm -f "$timer_pid_file") &
    echo $! > "$timer_pid_file"
fi
