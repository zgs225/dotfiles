#!/bin/sh
# Seed the greeter background on first boot only. The lightdm greeter runs as
# the lightdm user and cannot read ~/.local/share (700 home), so a wallpaper is
# mirrored to /usr/share/backgrounds/default.png. Once lock-render.py has
# rendered the lockscreen composite it takes over this path (richer artwork),
# so this script only seeds when the file is absent and never overwrites it.

set -e

DEST="/usr/share/backgrounds/default.png"
FEHBG="${HOME}/.fehbg"

# Already seeded (or composite present) — do not overwrite.
[ -f "$DEST" ] && exit 0

[ -f "$FEHBG" ] || exit 0

# Extract the quoted path from: feh --no-fehbg --bg-fill '/path/to/wall.png'
src=$(sed -n "s/.*--bg-fill '\(.*\)'.*/\1/p" "$FEHBG")
[ -n "$src" ] && [ -f "$src" ] || exit 0

sudo mkdir -p "$(dirname "$DEST")"
sudo cp "$src" "$DEST"
sudo chmod 644 "$DEST"
echo "Seeded greeter wallpaper: $(basename "$src")"
