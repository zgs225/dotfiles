#!/usr/bin/env bash
# screenshot.sh — region screenshots with a FROZEN screen.
#
# select/ocr modes: capture the full virtual desktop the instant the hotkey
# fires, overlay each monitor with its frozen image (feh --fullscreen), let
# the user drag a region over the frozen picture (slop), then crop the region
# from the frozen frame — never from a second live capture. Handles any
# number of monitors (parsed from xrandr at runtime).

set -euo pipefail

dir="${SCREENSHOT_DIR:-$HOME/Pictures/screenshots}"
mkdir -p "$dir"

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

# Show the frozen frame, one fullscreen feh per monitor.
# Reads "idx x y w h" lines from stdin; echoes nothing.
overlays_show() {
    local idx x y w h
    local nmon=0
    while read -r idx x y w h; do
        magick "$work/full.png" -crop "${w}x${h}+${x}+${y}" +repage \
            "$work/mon${idx}.png"
        feh --fullscreen --xinerama-index "$idx" \
            --image-bg black "$work/mon${idx}.png" &
        overlay_pids+=("$!")
        nmon=$((nmon + 1))
    done

    # Wait until every overlay window is mapped (max ~3s). feh titles
    # contain the full image path, so match on the unique workdir. Plus a
    # beat so the compositor finishes fading them in.
    local tries=0 n
    while (( tries < 30 )); do
        n=$(xdotool search --name "$work/" 2>/dev/null | wc -l)
        if (( n >= nmon )); then
            sleep 0.2
            return 0
        fi
        sleep 0.1
        tries=$((tries + 1))
    done
}

overlays_hide() {
    local p
    for p in "${overlay_pids[@]:-}"; do
        kill "$p" 2>/dev/null || true
    done
    overlay_pids=()
}

# Freeze-then-select: puts the region as WxH+X+Y into $REGION.
# Returns 1 when the user cancels.
freeze_select() {
    work=$(mktemp -d -t screenshot-freeze.XXXXXX)
    # -u: no cursor in the frozen frame (the live cursor still moves above it)
    maim -u "$work/full.png"

    # xrandr order == Xinerama index order (verified against
    # XineramaQueryScreens), so NR works as feh --xinerama-index.
    if ! overlays_show < <(xrandr --listmonitors | awk 'NR>1 {
            split($3, g, /[x+]/)
            split(g[1], w, "/"); split(g[2], h, "/")
            print NR-2, g[3], g[4], w[1], h[1]
        }'); then
        return 1
    fi

    local geo="" rc=0
    # -t 0: drag-only selection — with overlays on top, slop's window-click
    # mode would select the feh overlay instead of the real window.
    geo=$(slop -t 0 -f "%wx%h+%x+%y") || rc=$?
    overlays_hide
    if (( rc != 0 )) || [[ -z "$geo" ]]; then
        return 1
    fi

    # Ignore empty regions (bare click).
    local w h
    IFS='x+' read -r w h _ <<< "$geo"
    if (( w <= 0 || h <= 0 )); then
        return 1
    fi

    magick "$work/full.png" -crop "$geo" +repage "$tmp"
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
