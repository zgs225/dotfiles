#!/usr/bin/env bash
# Media transport control. Usage: media-ctl.sh {play-pause|next|previous}
command -v playerctl >/dev/null 2>&1 || exit 0
case "$1" in
    play-pause|next|previous) playerctl "$1" 2>/dev/null ;;
esac
# Reflect the new playback state at once instead of waiting for the 2s poll.
eww update media="$(~/.config/eww/scripts/media.sh)" 2>/dev/null
