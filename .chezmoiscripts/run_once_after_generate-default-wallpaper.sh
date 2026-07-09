#!/usr/bin/env bash

set -euo pipefail

wallpaper_dir="$HOME/.local/share/wallpapers"
default_wallpaper="$wallpaper_dir/default.jpg"

mkdir -p "$wallpaper_dir"

if [ ! -f "$default_wallpaper" ]; then
    if command -v magick > /dev/null 2>&1; then
        magick convert -size 1920x1080 xc:"#1e1e2e" "$default_wallpaper"
    elif command -v convert > /dev/null 2>&1; then
        convert -size 1920x1080 xc:"#1e1e2e" "$default_wallpaper"
    else
        echo "Warning: ImageMagick not found, skipping default wallpaper generation" >&2
    fi
fi
