#!/usr/bin/env bash

register_module calc "=" plain

calc_init() {
    printf '\0prompt\x1f计算\n'
    printf '\0no-custom\x1ftrue\n'
    local q="${LAUNCHER_Q:-}"
    if [ -z "$q" ]; then
        msg_row "用法：= <表达式>（bc -l 语法）"
        return 0
    fi
    local res
    if ! res=$(printf '%s\n' "scale=6; $q" | bc -l 2>/dev/null); then
        msg_row "表达式无效：$q" dialog-error
        return 0
    fi
    [ -z "$res" ] && { msg_row "表达式无效：$q" dialog-error; return 0; }
    res=$(printf '%s' "$res" | sed '/\./ s/0*$//; s/\.$//; s/^\./0./; s/^-\./-0./')
    row "$q = $res" accessories-calculator "copy:$res"
}

calc_select() {
    local info="${ROFI_INFO:-}"
    case "$info" in
        copy:*)
            printf '%s' "${info#copy:}" | xclip -selection clipboard >/dev/null 2>&1
            command -v notify-send >/dev/null 2>&1 && \
                setsid -f notify-send "计算器" "已复制：${info#copy:}" >/dev/null 2>&1
            ;;
    esac
}
