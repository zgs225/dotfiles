#!/bin/sh
# Copy a base Kvantum SVG for the catppuccin-glass theme.
# The SVG is taken from the system Kvantum installation (KvDark by preference);
# this script is needed because Kvantum themes require a matching SVG file.

set -e

DEST_DIR="${HOME}/.config/Kvantum/catppuccin-glass"
DEST="${DEST_DIR}/catppuccin-glass.svg"

if [ -f "$DEST" ]; then
    echo "Kvantum base SVG already exists at $DEST"
    exit 0
fi

for src in \
    "/usr/share/Kvantum/KvDark/KvDark.svg" \
    "/usr/share/Kvantum/KvGnome/KvGnome.svg"; do
    if [ -f "$src" ]; then
        mkdir -p "$DEST_DIR"
        cp "$src" "$DEST"
        echo "Copied Kvantum base SVG from $src to $DEST"
        exit 0
    fi
done

echo "Warning: no Kvantum base SVG found; $DEST was not created" >&2
exit 0
