#!/usr/bin/env bash
# Switch default audio device
# Usage: audio-switch.sh <sink|source> <device_name>

# Detach so eww's 200ms onclick SIGKILL can't kill the post-switch `eww update`;
# otherwise the checkmark waits for the 2s audio poll to move.
if [ -z "$EWW_AUDIO_SWITCH_DETACHED" ]; then
    EWW_AUDIO_SWITCH_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi

TYPE="$1"
DEVICE="$2"

[ -z "$TYPE" ] || [ -z "$DEVICE" ] && exit 1

case "$TYPE" in
    sink)
        CURRENT=$(pactl get-default-sink 2>/dev/null)
        if [ "$CURRENT" != "$DEVICE" ]; then
            pactl set-default-sink "$DEVICE" 2>/dev/null
        fi
        ;;
    source)
        CURRENT=$(pactl get-default-source 2>/dev/null)
        if [ "$CURRENT" != "$DEVICE" ]; then
            pactl set-default-source "$DEVICE" 2>/dev/null
        fi
        ;;
    *)
        exit 1
        ;;
esac

# Reflect the new default device immediately rather than waiting for the 2s poll.
eww update audio_sinks="$(~/.config/eww/scripts/audio-sinks.sh)"
eww update audio_sources="$(~/.config/eww/scripts/audio-sources.sh)"
eww update audio_devices="$(~/.config/eww/scripts/audio-devices.sh)"
