#!/usr/bin/env bash
# rofi 剪贴板 modi
#
# 性能要点：显示文本截断到 $MAX 个字符，用 info 字段传「行号」，选中时再按行号
# 回查真实条目。否则一条几十万字符的单行条目（greenclip 会把换行替换成 U+00A0
# 拼成一行）会让 rofi 每一帧都对整串文本做 Pango 排版/断行
# （pango_layout_get_baseline → pango_default_break），面板打开期间持续烧
# 40~100% 单核 CPU，开窗 1s+，按键延迟 200~340ms。

CONFIG_FILE="$HOME/.config/greenclip.toml"
CACHE_DIR=$(sed -n 's/^[[:space:]]*image_cache_directory[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$CONFIG_FILE" 2>/dev/null)

if [[ -z "$CACHE_DIR" || ! -d "$CACHE_DIR" ]]; then
    CACHE_DIR="/tmp/greenclip"
fi

MAX=110

case "$ROFI_RETV" in
    0)
        greenclip print | awk -v max="$MAX" -v cache="$CACHE_DIR" '
            {
                n++
                icon = "text/plain"
                if (match($0, /^image[ \t]+[0-9-]+/)) {
                    id = substr($0, RSTART, RLENGTH)
                    sub(/^image[ \t]+/, "", id)
                    icon = cache "/" id ".png"
                    if (system("test -f \"" icon "\"") != 0) {
                        icon = "image-x-generic"
                    }
                }
                disp = substr($0, 1, max)
                if (length($0) > max) {
                    disp = disp "…"
                }
                # info 必须排在 icon 之前，否则此版本 rofi 会丢掉 info
                printf "%s\0info\x1f%d\0icon\x1f%s\n", disp, n, icon
            }'
        ;;
    1|3)
        idx="$ROFI_INFO"
        [[ -z "$idx" ]] && exit 0
        line=$(greenclip print | sed -n "${idx}p")
        [[ -z "$line" ]] && exit 0
        if (( ${#line} < 100000 )); then
            greenclip print "$line" >/dev/null 2>&1
        else
            # 超过 MAX_ARG_STRLEN(128KiB) 无法作为 argv 交回 greenclip，
            # 直接把 U+00A0 还原成换行写入剪贴板
            printf '%s' "$line" | tr '\302\240' '\n' | xclip -selection clipboard -i
        fi
        ;;
esac
