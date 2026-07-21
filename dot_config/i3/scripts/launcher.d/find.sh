#!/usr/bin/env bash

register_module find "find" filter "Alt+Return"

find_init() {
    printf '\0prompt\x1f查找\n'
    printf '\0message\x1f回车=打开；Alt+回车=打开文件夹；无结果时回车=重新搜索\n'
    printf '\0use-hot-keys\x1ftrue\n'
    local q="${LAUNCHER_Q:-}"
    if ! command -v fd >/dev/null 2>&1; then
        msg_row "未安装 fd — sudo pacman -S fd" dialog-warning
        return 0
    fi
    if [ -z "$q" ]; then
        msg_row "用法：find <名称>"
        return 0
    fi
    local results
    results=$(timeout 5 fd -H -F --max-results 5000 \
        --exclude .git --exclude .cache --exclude node_modules --exclude .local/share/Trash \
        -- "$q" "$HOME" 2>/dev/null || true)
    if [ -z "$results" ]; then
        msg_row "未找到：$q（按回车重试）" dialog-information
        return 0
    fi
    local p display
    while IFS= read -r p; do
        display="${p/#$HOME/\~}"
        if [ -d "$p" ]; then
            row "$display" folder "open:$p"
        else
            row "$display" text-x-generic "open:$p"
        fi
    done <<< "$results"
}

find_select() {
    local input="$1" info="${ROFI_INFO:-}" retv="${ROFI_RETV:-1}"
    case "$info" in
        open:*)
            local p="${info#open:}"
            if [ "$retv" = "10" ]; then
                [ -d "$p" ] || p="${p%/*}"
            fi
            open_target "$p" ;;
        *)
            [ -n "$input" ] && chain find "$input" ;;
    esac
}
