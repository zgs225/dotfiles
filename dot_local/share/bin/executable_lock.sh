#!/usr/bin/env bash

# i3lock wrapper — Catppuccin Mocha
# Takes a screenshot, blurs it, and uses it as lock background

tmpbg="/tmp/i3lock-$(date +%s).png"

# Take screenshot
maim "$tmpbg"

# Blur screenshot
convert "$tmpbg" -blur 0x8 "$tmpbg"

# Lock with Catppuccin Mocha colors
i3lock \
    --image="$tmpbg" \
    --inside-color=1e1e2e66 \
    --ring-color=b4befe \
    --line-color=00000000 \
    --keyhl-color=a6e3a1 \
    --bshl-color=f38ba8 \
    --separator-color=00000000 \
    --insidever-color=1e1e2e66 \
    --ringver-color=89b4fa \
    --insidewrong-color=1e1e2e66 \
    --ringwrong-color=f38ba8 \
    --radius=100 \
    --ring-width=5 \
    --verif-text="" \
    --wrong-text="" \
    --noinput-text="" \
    --lock-text="" \
    --clock \
    --time-color=cdd6f4 \
    --time-align=1 \
    --date-color=a6adc8 \
    --date-align=1 \
    --time-font="Noto Sans CJK SC" \
    --date-font="Noto Sans CJK SC" \
    --time-size=48 \
    --date-size=18 \
    --time-str="%H:%M" \
    --date-str="%Y-%m-%d"

# Clean up
rm "$tmpbg"
