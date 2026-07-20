#!/usr/bin/env bash
# Responds to a Bluetooth pairing confirmation dialog via the daemon.
# Usage: bt-pair-respond.sh <yes|no>
dbus-send --session --dest=org.eww.BtAgent --type=method_call \
    /org/eww/BtAgent org.eww.BtAgent.RespondPair string:"$1" 2>/dev/null
