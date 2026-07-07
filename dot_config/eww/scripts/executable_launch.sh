#!/usr/bin/env bash
# Eww bar launch — start daemon and open the bar.
#
# DPI-dependent sizes (bar height, icon/font sizes, workspace dots, popups) are
# baked into eww.yuck/eww.scss at `chezmoi apply` time via the shared
# .chezmoitemplates/eww-sizes partial, because eww 0.5.0 cannot resolve
# variables inside a window :geometry and GTK will not size empty boxes from
# runtime CSS variables. Re-run `chezmoi apply` after changing the display DPI.

eww kill 2>/dev/null
sleep 0.3

eww daemon
eww update popup_open="none"
eww close popup-scrim 2>/dev/null
eww open bar
