#!/usr/bin/env bash

register_module calc "=" plain

calc_init() {
    printf '\0prompt\x1fCalc\n'
    printf '\0no-custom\x1ftrue\n'
    local q="${LAUNCHER_Q:-}"
    if [ -z "$q" ]; then
        msg_row "Usage: = <expression>   (bc -l syntax)"
        return 0
    fi
    local res
    if ! res=$(printf '%s\n' "scale=6; $q" | bc -l 2>/dev/null); then
        msg_row "Invalid expression: $q" dialog-error
        return 0
    fi
    [ -z "$res" ] && { msg_row "Invalid expression: $q" dialog-error; return 0; }
    res=$(printf '%s' "$res" | sed '/\./ s/0*$//; s/\.$//; s/^\./0./; s/^-\./-0./')
    row "$q = $res" accessories-calculator "copy:$res"
}

calc_select() {
    local info="${ROFI_INFO:-}"
    case "$info" in
        copy:*)
            printf '%s' "${info#copy:}" | xclip -selection clipboard >/dev/null 2>&1
            command -v notify-send >/dev/null 2>&1 && \
                setsid -f notify-send "Calculator" "Copied: ${info#copy:}" >/dev/null 2>&1
            ;;
    esac
}
