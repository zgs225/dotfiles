#!/usr/bin/env bash
if command -v paru > /dev/null 2>&1; then
    wezterm start -- paru &
else
    wezterm start -- bash -c "sudo pacman -Syu" &
fi
disown

