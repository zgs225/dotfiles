#!/usr/bin/env bash
CACHE_DIR="$HOME/.cache/eww"
CHECKING_FILE="$CACHE_DIR/updates.checking"

check_state() {
    [ -f "$CHECKING_FILE" ] && echo "true" || echo "false"
}

mkdir -p "$CACHE_DIR"

check_state

inotifywait -e create,delete,move -m "$CACHE_DIR" 2>/dev/null | while read -r line; do
    case "$line" in
        *updates.checking*)
            check_state
            ;;
    esac
done
