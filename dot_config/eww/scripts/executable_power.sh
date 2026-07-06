#!/usr/bin/env bash
# power.sh — execute power actions
case "$1" in
    lock)     betterlockscreen -l blur ;;
    logout)   i3-msg exit ;;
    suspend)  systemctl suspend ;;
    reboot)   systemctl reboot ;;
    poweroff) systemctl poweroff ;;
    *)        echo "Usage: power.sh {lock|logout|suspend|reboot|poweroff}" >&2 ;;
esac
