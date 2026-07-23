#!/bin/sh
# Install catppuccin-glass GTK theme system-wide so lightdm-gtk-greeter
# (running as the lightdm user) can read it. ~/.themes/ is under a 700
# home directory, so a symlink would be permission-denied for lightdm.
# Idempotent: skips copy when content is already identical.

set -e

SRC="${HOME}/.themes/catppuccin-glass"
DEST="/usr/share/themes/catppuccin-glass"

[ -d "$SRC" ] || exit 0

if diff -rq "$SRC" "$DEST" >/dev/null 2>&1; then
	exit 0
fi

sudo mkdir -p "$DEST/gtk-3.0"
sudo cp "$SRC/index.theme" "$DEST/"
sudo cp "$SRC/gtk-3.0/gtk.css" "$DEST/gtk-3.0/"
sudo chmod -R a+r "$DEST"
sudo find "$DEST" -type d -exec chmod 755 {} +
echo "Installed catppuccin-glass theme to $DEST"
