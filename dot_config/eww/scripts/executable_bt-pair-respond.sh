#!/bin/bash
# Responds to a Bluetooth pairing confirmation dialog via the daemon.
# Usage: bt-pair-respond.sh <yes|no>
case "$1" in
    yes|no) ;;
    *) echo "Usage: bt-pair-respond.sh <yes|no>" >&2; exit 2 ;;
esac
# eww SIGKILLs onclick children after 200ms (see update-apply.sh); a
# session-bus round trip to the agent daemon can outlast that, so detach
# immediately or the prompt stays on screen and the click is lost. The
# argument is validated above, so a bad call still exits non-zero.
if [ -z "$EWW_BT_PAIR_RESPOND_DETACHED" ]; then
    EWW_BT_PAIR_RESPOND_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi
dbus-send --session --dest=org.eww.BtAgent --type=method_call \
    /org/eww/BtAgent org.eww.BtAgent.RespondPair string:"$1" 2>/dev/null
