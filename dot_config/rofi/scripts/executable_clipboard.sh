#!/usr/bin/env bash

CONFIG_FILE="$HOME/.config/greenclip.toml"
CACHE_DIR=$(grep -E '^image_cache_directory' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f2)

if [[ -z "$CACHE_DIR" || ! -d "$CACHE_DIR" ]]; then
    CACHE_DIR="/tmp/greenclip"
fi

case "$ROFI_RETV" in
    0)
        greenclip print | while IFS= read -r line; do
            if [[ "$line" =~ ^image/[[:space:]]+([0-9-]+) ]]; then
                id="${BASH_REMATCH[1]}"
                img_path="$CACHE_DIR/$id.png"
                if [[ -f "$img_path" ]]; then
                    printf '%s\0icon\x1f%s\n' "$line" "$img_path"
                else
                    printf '%s\0icon\x1fimage-x-generic\n' "$line"
                fi
            else
                printf '%s\0icon\x1ftext/plain\n' "$line"
            fi
        done
        ;;
    1)
        greenclip print "$1" >/dev/null
        ;;
esac