#!/usr/bin/env bash
set -euo pipefail

wallpaper_dir="$HOME/.local/share/wallpapers"
state_file="$HOME/.local/share/wallpapers/.current-index"

mapfile -t wallpapers < <(find "$wallpaper_dir" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    | sort)

count=${#wallpapers[@]}
if (( count == 0 )); then
    notify-send -u low "Wallpaper" "No wallpapers found in $wallpaper_dir"
    exit 1
fi

mode="${1:-next}"
if [[ "$mode" == "random" ]]; then
    idx=$(( RANDOM % count ))
else
    idx=0
    if [[ -f "$state_file" ]]; then
        idx=$(<"$state_file")
        [[ "$idx" =~ ^[0-9]+$ ]] || idx=0
    fi
    idx=$(( (idx + 1) % count ))
fi
echo "$idx" > "$state_file"

current="${wallpapers[$idx]}"
feh --bg-fill "$current"

systemctl --user start lockscreen-refresh.service >/dev/null 2>&1 &
