#!/usr/bin/env bash
# Eww bar launch — start daemon and open the bar.
#
# DPI-dependent sizes (bar height, icon/font sizes, workspace dots, popups) are
# baked into eww.yuck/eww.scss at `chezmoi apply` time via the shared
# .chezmoitemplates/eww-sizes partial, because eww 0.5.0 cannot resolve
# variables inside a window :geometry and GTK will not size empty boxes from
# runtime CSS variables. Re-run `chezmoi apply` after changing the display DPI.

eww kill 2>/dev/null

wait=0
while pgrep -f 'eww daemon' > /dev/null 2>&1 && [ $wait -lt 30 ]; do
  sleep 0.1
  wait=$((wait + 1))
done

if pgrep -f 'eww daemon' > /dev/null 2>&1; then
  pkill -9 -f 'eww daemon' 2>/dev/null
  sleep 0.2
fi

eww daemon
eww update popup_open="none"
eww close popup-scrim 2>/dev/null
eww open bar
