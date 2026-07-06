#!/usr/bin/env bash
# Eww bar launch — DPI detection, variable injection, daemon start

DPI=$(xrdb -query | awk '/Xft.dpi/ {print $2}')
if [ -n "$DPI" ] && [ "$DPI" -ge 192 ]; then
    BAR_HEIGHT=72;  ICON_SIZE=28; FONT_SIZE=24
    DOT_SIZE=10;    PILL_W=36;  PILL_H=24; CELL_PAD=40
elif [ -n "$DPI" ] && [ "$DPI" -ge 144 ]; then
    BAR_HEIGHT=54;  ICON_SIZE=20; FONT_SIZE=17
    DOT_SIZE=8;     PILL_W=28;  PILL_H=20; CELL_PAD=34
else
    BAR_HEIGHT=38;  ICON_SIZE=14; FONT_SIZE=12
    DOT_SIZE=6;     PILL_W=20;  PILL_H=14; CELL_PAD=28
fi

eww kill 2>/dev/null
sleep 0.3

eww daemon

eww update bar_height=$BAR_HEIGHT icon_size=$ICON_SIZE font_size=$FONT_SIZE \
          dot_size=$DOT_SIZE pill_w=$PILL_W pill_h=$PILL_H cell_pad=$CELL_PAD \
          popup_open="none"

eww open bar

# Start D-Bus notification log monitor daemon
~/.config/eww/scripts/notif-logger.sh &
