#!/usr/bin/env bash
if command -v paru > /dev/null 2>&1; then
    wezterm start -- bash -c "paru -Syu --noconfirm; ~/.config/eww/scripts/check-updates.sh" &
else
    wezterm start -- bash -c "sudo pacman -Syu --noconfirm; ~/.config/eww/scripts/check-updates.sh" &
fi
disown

