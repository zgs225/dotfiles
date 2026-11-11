#!/bin/bash
# Fire the periodic update check now (systemd user unit does the work).
#
# eww SIGKILLs a button :onclick command after ~200ms (see
# update-apply.sh / open-popup.sh), and a `systemctl start` that has to wait
# for the user bus can exceed that, leaving 检查更新 silently dead. Detach
# immediately; the unit is started with --no-block either way.
if [ -z "$EWW_UPDATE_TRIGGER_DETACHED" ]; then
    EWW_UPDATE_TRIGGER_DETACHED=1 setsid nohup "$(readlink -f "$0")" "$@" >/dev/null 2>&1 &
    exit 0
fi
systemctl --user start --no-block update-check.service
