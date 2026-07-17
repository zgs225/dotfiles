#!/usr/bin/env bash

THEME="$HOME/.config/rofi/launcher.rasi"
SELF="$HOME/.config/i3/scripts/launcher.sh"
MOD_DIR="$HOME/.config/i3/scripts/launcher.d"

msg_row() {
    printf '%s\0icon\x1f%s\x1fnonselectable\x1ftrue\n' "$1" "${2:-dialog-information}"
}

row() {
    printf '%s\0icon\x1f%s\x1finfo\x1f%s\n' "$1" "$2" "$3"
}

open_target() {
    setsid -f xdg-open "$1" >/dev/null 2>&1
}

urlencode() {
    /usr/bin/python3 -c 'import sys,urllib.parse;print(urllib.parse.quote_plus(sys.argv[1]))' "$1"
}

declare -a MODS=()
declare -A MOD_PREFIX=() MOD_STAGE=() MOD_HOTKEY=()

register_module() {
    MODS+=("$1")
    MOD_PREFIX[$1]="$2"
    MOD_STAGE[$1]="$3"
    MOD_HOTKEY[$1]="${4:-}"
}

load_modules() {
    local f
    for f in "$MOD_DIR"/*.sh; do
        [ "${f##*/}" = common.sh ] && continue
        source "$f"
    done
}

chain() {
    local mode="$1" q="$2" filter="" hotkey=""
    hotkey="${MOD_HOTKEY[$mode]:-}"
    [ "${MOD_STAGE[$mode]:-}" = filter ] && filter="$q"
    setsid -f bash -c \
        'while pgrep -x rofi >/dev/null 2>&1; do sleep 0.05; done; exec env LAUNCHER_Q="$1" rofi -show "$2" -modi "$2:$3 --mod $2" -theme "$4" -filter "$5" -kb-cancel "Escape,Alt+space" ${6:+-kb-custom-1 "$6"}' \
        _ "$q" "$mode" "$SELF" "$THEME" "$filter" "$hotkey" >/dev/null 2>&1
}

fallback_drun() {
    setsid -f bash -c \
        'while pgrep -x rofi >/dev/null 2>&1; do sleep 0.05; done; exec rofi -show drun -filter "$1" -theme "$2"' \
        _ "$1" "$THEME" >/dev/null 2>&1
}
