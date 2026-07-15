#!/usr/bin/env bash
CACHE_DIR="$HOME/.cache/eww"
CACHE_FILE="$CACHE_DIR/updates.json"
DEFAULT='{"last_check":"Never","total":0,"official_count":0,"aur_count":0,"official":[],"aur":[],"error":null}'

mkdir -p "$CACHE_DIR"

if [ -f "$CACHE_FILE" ]; then
    jq -c . "$CACHE_FILE" 2>/dev/null || echo "$DEFAULT"
else
    echo "$DEFAULT"
fi

inotifywait -e modify,create,delete,move -m "$CACHE_DIR" 2>/dev/null | while read -r line; do
    case "$line" in
        *updates.json*)
            if [ -f "$CACHE_FILE" ]; then
                jq -c . "$CACHE_FILE" 2>/dev/null || echo "$DEFAULT"
            else
                echo "$DEFAULT"
            fi
            ;;
    esac
done
