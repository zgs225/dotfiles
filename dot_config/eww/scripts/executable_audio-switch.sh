#!/usr/bin/env bash
# Switch default audio device
# Usage: audio-switch.sh <sink|source> <device_name>

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
