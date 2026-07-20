#!/usr/bin/env bash
# Holds a BlueZ discovery session alive while the bluetooth popup is open.
# BlueZ stops discovery as soon as the requesting bluetoothctl client
# disconnects from D-Bus, so a short-lived `bluetoothctl scan on` is useless —
# a background process must keep the client connected. Plain `scan on` reads
# commands from stdin and exits on EOF in this non-interactive context, so
# pin the session open with a ~1 year --timeout instead. The pid file lets the
# next poll (or popup close) find and kill exactly that process, leaving
# discovery started by other clients (e.g. blueman) untouched.
PIDFILE=/tmp/eww-bt-scan.pid
# The absurd --timeout doubles as a process signature: only holders we started
# carry it, so pkill/pgrep never touch scans owned by blueman or the user.
SCAN_CMD='bluetoothctl --timeout 31536000 scan on'

case "$1" in
on)
    # A device action (pair/connect) holds the link lock — do not restart
    # discovery mid-operation, BlueZ would abort the new connection.
    exec 8>/tmp/eww-bt-action.lock
    flock -n 8 || exit 0
    existing=$(pgrep -f "$SCAN_CMD" | head -1)
    if [ -n "$existing" ]; then
        echo "$existing" > "$PIDFILE"
        exit 0
    fi
    bluetoothctl show 2>/dev/null | grep -q "Powered: yes" || exit 0
    # 8>&-: the holder must not inherit the lock fd.
    nohup $SCAN_CMD >/dev/null 2>&1 8>&- &
    echo $! > "$PIDFILE"
    ;;
off)
    rm -f "$PIDFILE"
    pkill -f "$SCAN_CMD" 2>/dev/null
    ;;
esac
exit 0
