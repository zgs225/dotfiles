#!/usr/bin/env bash
# Called by defpoll (~2s). Emits JSON describing the active media player.
# Uses playerctl when available; degrades gracefully to an idle placeholder.
# Fields: has (bool), title, artist, status ("Playing"|"Paused"), icon.

if ! command -v playerctl >/dev/null 2>&1; then
    printf '{"has":false,"title":"Nothing Playing","artist":"No media source","status":"Stopped","icon":"\u200b"}\n'
    exit 0
fi

status=$(playerctl status 2>/dev/null)
if [ -z "$status" ] || [ "$status" = "Stopped" ]; then
    printf '{"has":false,"title":"Nothing Playing","artist":"No media source","status":"Stopped","icon":"\u200b"}\n'
    exit 0
fi

title=$(playerctl metadata title 2>/dev/null)
artist=$(playerctl metadata artist 2>/dev/null)
esc() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
title=$(printf '%s' "${title:-Unknown}" | esc)
artist=$(printf '%s' "${artist:-Unknown}" | esc)

if [ "$status" = "Playing" ]; then icon="󰏤"; else icon="󰐊"; fi
printf '{"has":true,"title":"%s","artist":"%s","status":"%s","icon":"%s"}\n' \
    "$title" "$artist" "$status" "$icon"
