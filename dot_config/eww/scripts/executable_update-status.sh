#!/usr/bin/env bash
CACHE="$HOME/.cache/eww/updates.json"
if [ ! -f "$CACHE" ]; then
    echo '{"last_check":"Never","total":0,"official_count":0,"aur_count":0,"official":[],"aur":[],"error":null}'
    exit 0
fi
cat "$CACHE"
