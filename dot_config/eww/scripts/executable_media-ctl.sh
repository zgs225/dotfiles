#!/bin/bash
# Media transport control. Usage: media-ctl.sh {play-pause|next|previous}
command -v playerctl >/dev/null 2>&1 || exit 0
case "$1" in
    play-pause|next|previous) ;;
    *) echo "Usage: media-ctl.sh {play-pause|next|previous}" >&2; exit 2 ;;
esac
# eww SIGKILLs onclick children after 200ms (see update-apply.sh); the
# playerctl call plus media.sh refresh below exceed that, so detach
# immediately or the optimistic `eww update media` never lands.
if [ -z "$EWW_MEDIA_CTL_DETACHED" ]; then
    EWW_MEDIA_CTL_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi
playerctl "$1" 2>/dev/null
# Reflect the new playback state at once instead of waiting for the 2s poll.
eww update media="$(~/.config/eww/scripts/media.sh)" 2>/dev/null
