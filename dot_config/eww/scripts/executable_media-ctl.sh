#!/usr/bin/env bash
# Media transport control. Usage: media-ctl.sh {play-pause|next|previous}
command -v playerctl >/dev/null 2>&1 || exit 0
case "$1" in
    play-pause|next|previous) playerctl "$1" 2>/dev/null ;;
esac
