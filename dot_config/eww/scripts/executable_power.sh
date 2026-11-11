#!/bin/bash
# power.sh — execute power actions
case "$1" in
    lock|logout|suspend|reboot|poweroff) ;;
    *) echo "Usage: power.sh {lock|logout|suspend|reboot|poweroff}" >&2; exit 2 ;;
esac
# eww SIGKILLs onclick children after 200ms (see update-apply.sh); lock.sh
# alone can outlast that, which would leave the popup open and the action
# half-done. Detach immediately (the argument is validated above, so the
# usage path still exits non-zero and `power.sh lock && open-popup.sh`
# keeps its meaning).
if [ -z "$EWW_POWER_DETACHED" ]; then
    EWW_POWER_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi
case "$1" in
    lock)     ~/.config/i3/scripts/lock.sh ;;
    logout)   i3-msg exit ;;
    suspend)  systemctl suspend ;;
    reboot)   systemctl reboot ;;
    poweroff) systemctl poweroff ;;
esac
