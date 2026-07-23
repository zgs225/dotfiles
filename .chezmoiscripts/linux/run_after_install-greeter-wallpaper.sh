#!/bin/sh
# Copy the current desktop wallpaper to /usr/share/backgrounds/default.png
# so lightdm-gtk-greeter (running as the lightdm user) can display it.
# Reads the current wallpaper from ~/.fehbg (written by feh --bg-fill).

set -e

DEST="/usr/share/backgrounds/default.png"
FEHBG="${HOME}/.fehbg"

[ -f "$FEHBG" ] || exit 0

# Extract the quoted path from: feh --no-fehbg --bg-fill '/path/to/wall.png'
src=$(sed -n "s/.*--bg-fill '\(.*\)'.*/\1/p" "$FEHBG")
[ -n "$src" ] && [ -f "$src" ] || exit 0

# Skip if already identical
if [ -f "$DEST" ] && cmp -s "$src" "$DEST"; then
	exit 0
fi

sudo cp "$src" "$DEST"
sudo chmod 644 "$DEST"
echo "Updated greeter wallpaper: $(basename "$src")"
