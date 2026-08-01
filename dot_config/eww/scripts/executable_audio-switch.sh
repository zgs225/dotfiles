#!/usr/bin/env bash
# Switch default audio device or sound card profile.
# Usage: audio-switch.sh <type> <name> [card]
#   type=sink    name=<sink_name>           → pactl set-default-sink
#   type=source  name=<source_name>         → pactl set-default-source
#   type=profile name=<profile> card=<card> → pactl set-card-profile + set sink

# Detach so eww's 200ms onclick SIGKILL can't kill the post-switch `eww update`;
# otherwise the checkmark waits for the 2s audio poll to move.
if [ -z "$EWW_AUDIO_SWITCH_DETACHED" ]; then
    EWW_AUDIO_SWITCH_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi

TYPE="$1"
NAME="$2"
CARD="$3"

[ -z "$TYPE" ] || [ -z "$NAME" ] && exit 1

_update_eww() {
    eww update audio_sinks="$(~/.config/eww/scripts/audio-sinks.sh)"
    eww update audio_sources="$(~/.config/eww/scripts/audio-sources.sh)"
    eww update audio_devices="$(~/.config/eww/scripts/audio-devices.sh)"
}

case "$TYPE" in
    sink)
        CURRENT=$(pactl get-default-sink 2>/dev/null)
        if [ "$CURRENT" != "$NAME" ]; then
            pactl set-default-sink "$NAME" 2>/dev/null
            # Unmute the new sink — PipeWire stores mute per-sink,
            # so the target may be muted from a previous session.
            pamixer -u 2>/dev/null
        fi
        _update_eww
        ;;
    source)
        CURRENT=$(pactl get-default-source 2>/dev/null)
        if [ "$CURRENT" != "$NAME" ]; then
            pactl set-default-source "$NAME" 2>/dev/null
        fi
        _update_eww
        ;;
    profile)
        [ -z "$CARD" ] && exit 1
        pactl set-card-profile "$CARD" "$NAME" 2>/dev/null
        # Wait for PipeWire to destroy old sink and create the new one
        for _ in 1 2 3 4 5 6 7 8; do
            sleep 0.25
            NEW_SINK=$(pactl list sinks short 2>/dev/null | awk '{print $2}' | head -1)
            [ -n "$NEW_SINK" ] && break
        done
        if [ -n "$NEW_SINK" ]; then
            pactl set-default-sink "$NEW_SINK" 2>/dev/null
            # Unmute — new sink inherits its own (possibly muted) state
            pamixer -u 2>/dev/null
        fi
        _update_eww
        ;;
    *)
        exit 1
        ;;
esac
