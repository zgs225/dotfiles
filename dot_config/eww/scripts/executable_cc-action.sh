#!/usr/bin/env bash
# Control-center bottom action buttons.
# Usage: cc-action.sh {night-light|screenshot}
case "$1" in
    night-light)
        if command -v redshift >/dev/null 2>&1; then
            if pgrep -x redshift >/dev/null; then
                pkill -x redshift
            else
                redshift -O 4000 >/dev/null 2>&1 &
            fi
        elif command -v gammastep >/dev/null 2>&1; then
            pgrep -x gammastep >/dev/null && pkill -x gammastep || gammastep -O 4000 >/dev/null 2>&1 &
        else
            notify-send "护眼模式" "请安装 redshift 或 gammastep" 2>/dev/null
        fi
        ;;
    screenshot)
        eww close-all 2>/dev/null
        mkdir -p "$HOME/Pictures"
        f="$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"
        sleep 0.3
        if command -v maim >/dev/null 2>&1; then
            maim -s "$f" 2>/dev/null && notify-send "截图" "已保存到 $f" 2>/dev/null
        fi
        ;;
esac
