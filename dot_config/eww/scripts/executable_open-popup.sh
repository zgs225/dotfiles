#!/usr/bin/env bash
# Popup state manager — ensures only one popup open at a time
# Usage: open-popup.sh <popup-name>

NEW="$1"
CURRENT=$(eww get popup_open 2>/dev/null || echo "none")

has_compositor() {
  # This dotfiles uses picom as the X11 compositor. When it is not running
  # (e.g. in a VM to avoid flicker/CPU cost), skip the ARGB scrim so it does
  # not render as an opaque black fullscreen window.
  pgrep -x picom >/dev/null 2>&1
}

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
    eww close popup-scrim 2>/dev/null
    if has_compositor; then
        eww open popup-scrim 2>/dev/null
    fi
    eww open "$NEW"
    eww update popup_open="$NEW"
fi
