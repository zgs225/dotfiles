#!/usr/bin/env bash
# Control-center bottom action buttons.
# Usage: cc-action.sh {night-light|screenshot|performance}
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
            notify-send "Night Light" "Install redshift or gammastep" 2>/dev/null
        fi
        ;;
    screenshot)
        eww close-all 2>/dev/null
        mkdir -p "$HOME/Pictures"
        f="$HOME/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"
        sleep 0.3
        if command -v maim >/dev/null 2>&1; then
            maim -s "$f" 2>/dev/null && notify-send "Screenshot" "Saved to $f" 2>/dev/null
        fi
        ;;
    performance)
        command -v xfce4-taskmanager >/dev/null 2>&1 && xfce4-taskmanager & \
            || (command -v wezterm >/dev/null 2>&1 && wezterm start -- btop 2>/dev/null &) \
            || notify-send "Performance" "No monitor tool found" 2>/dev/null
        ;;
esac
