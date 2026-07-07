#!/usr/bin/env bash
# Popup state manager — ensures only one popup open at a time
# Usage: open-popup.sh <popup-name>

NEW="$1"
CURRENT=$(eww get popup_open 2>/dev/null || echo "none")

if [ "$NEW" = "close" ]; then
    [ "$CURRENT" != "none" ] && eww close "$CURRENT" 2>/dev/null
    eww close popup-scrim 2>/dev/null
    eww update popup_open="none"
elif [ "$CURRENT" = "$NEW" ]; then
    eww close "$NEW"
    eww close popup-scrim 2>/dev/null
    eww update popup_open="none"
else
    [ "$CURRENT" != "none" ] && eww close "$CURRENT" 2>/dev/null
    eww open popup-scrim 2>/dev/null
    eww open "$NEW"
    eww update popup_open="$NEW"
fi
