#!/usr/bin/env bash
# Bluetooth device actions for the bluetooth-popup device rows.
# Usage: bt-action.sh <connect|disconnect|pair|forget> <mac>
#
# eww runs button :onclick commands with a 200ms timeout and SIGKILLs whatever
# is still running (crates/eww/src/widgets/mod.rs). bluetoothctl connect/pair
# regularly take seconds, so detach immediately, then refresh the device list
# once the operation settles (the 2s defpoll would catch up anyway).
if [ -z "$EWW_BT_ACT_DETACHED" ]; then
    EWW_BT_ACT_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi

exec >>/tmp/eww-bt-action.log 2>&1
echo "=== $(date +%H:%M:%S) $* ==="

action="$1"
mac="$2"
[ -n "$action" ] && [ -n "$mac" ] || exit 1

# BlueZ aborts locally-initiated connections while a discovery session is
# active ("le-connection-abort-by-local"), so pair/connect MUST run with
# scanning stopped. This lock serializes against the auto-scan that
# bt-devices.sh keeps alive while the popup is open: bt-scan.sh refuses to
# restart discovery for as long as an action holds the lock. Long-lived
# children must not inherit fd 8 (8>&-) or the lock would leak into them.
exec 8>/tmp/eww-bt-action.lock
flock -w 20 8 || exit 0

esc() { printf '%s' "$1" | sed -e 's/"/\\"/g'; }
notice() { timeout 5 eww update "bt_notice=$(esc "$1")" 2>/dev/null; }
refresh() { timeout 8 eww update bt_devices="$(~/.config/eww/scripts/bt-devices.sh 8>&-)" 2>/dev/null; }
paired()    { bluetoothctl info "$mac" 2>/dev/null | grep -qE "(Paired|Bonded): yes"; }
connected() { bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; }
known()     { bluetoothctl info "$mac" >/dev/null 2>&1; }
trusted()   { bluetoothctl info "$mac" 2>/dev/null | grep -q "Trusted: yes"; }

label=$(bluetoothctl info "$mac" 2>/dev/null | awk -F': ' '/Name: / {print $2; exit}')
[ -z "$label" ] && label="$mac"

# Connect without a bond fails for UNTRUSTED devices — route those to pair.
# Trusted devices (previously paired, bond lost on disconnect) should try
# connect first: the remote side often still holds valid keys and will accept.
if [ "$action" = connect ] && known && ! paired && ! trusted; then
    action=pair
fi

case "$action" in
connect)
    ~/.config/eww/scripts/bt-scan.sh off 8>&-
    sleep 0.5
    notice "正在连接 $label..."
    out=$(bluetoothctl connect "$mac")
    echo "$out"
    sleep 1
    if echo "$out" | grep -q "Connection successful" && connected; then
        notice ""
    elif trusted; then
        echo "connect failed for trusted device, attempting pair"
        dbus-send --session --dest=org.eww.BtAgent --type=method_call \
            /org/eww/BtAgent org.eww.BtAgent.PairDevice string:"$mac" string:"$label" 2>/dev/null
    else
        err=$(echo "$out" | grep -o 'org.bluez.Error.*' | head -1)
        [ -z "$err" ] && err="device unreachable or not connectable"
        notice "连接失败: $err"
    fi
    ;;
disconnect)
    ~/.config/eww/scripts/bt-scan.sh off 8>&-
    sleep 0.5
    out=$(bluetoothctl disconnect "$mac")
    echo "$out"
    connected && notice "断开失败" || notice ""
    ;;
pair)
    ~/.config/eww/scripts/bt-scan.sh off 8>&-
    sleep 0.5
    # Try pairing directly even for Trusted-but-not-Paired devices.
    # Removing first is counterproductive: the remote still holds old keys
    # and will reject re-pairing regardless of local state.
    # pair needs the device in BlueZ's cache; after a remove it must be
    # rediscovered. Run a private short-lived discovery (NOT bt-scan.sh —
    # it refuses while we hold the action lock) and poll for the device.
    if ! known; then
        setsid bluetoothctl --timeout 20 scan on >/dev/null 2>&1 8>&- &
        redisc=$!
        for _ in $(seq 1 15); do
            known && break
            sleep 1
        done
        kill "$redisc" 2>/dev/null
        wait "$redisc" 2>/dev/null
        sleep 0.5
    fi
    if ! known; then
        notice "未找到设备 - 请保持 $label 可被发现后重试"
    else
        dbus-send --session --dest=org.eww.BtAgent --type=method_call \
            /org/eww/BtAgent org.eww.BtAgent.PairDevice string:"$mac" string:"$label" 2>/dev/null
    fi
    ;;
forget)
    out=$(bluetoothctl remove "$mac")
    echo "$out"
    notice ""
    ;;
*)
    exit 1
    ;;
esac

sleep 0.5
refresh
exit 0
