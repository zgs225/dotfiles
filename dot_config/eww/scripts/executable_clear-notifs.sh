#!/bin/bash
# Clear dunst notification history.
# eww SIGKILLs onclick children after 200ms (see update-apply.sh);
# dunstctl history-clear can block on a busy dunst, so detach immediately.
if [ -z "$EWW_CLEAR_NOTIFS_DETACHED" ]; then
    EWW_CLEAR_NOTIFS_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi
dunstctl history-clear 2>/dev/null
