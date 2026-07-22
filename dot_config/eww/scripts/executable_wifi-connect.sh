#!/usr/bin/env bash
# Connect to a Wi-Fi network with immediate in-row "连接中…" feedback.
# onclick: wifi-connect.sh <ssid>
# Detach so eww's 200ms onclick SIGKILL can't kill the connect (nmcli can take
# 5-15s for DHCP / secret-agent prompts — getting killed mid-run is what made
# clicking a network do nothing).
if [ -z "$EWW_WIFI_CONNECT_DETACHED" ]; then
    EWW_WIFI_CONNECT_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi

ssid="$1"
[ -n "$ssid" ] || exit 1
S=~/.config/eww/scripts
CF=/tmp/eww-wifi-connecting

# Remove the connecting mark on any exit so a killed connect can't leave a stale
# "连接中…" behind (the poll's age guard is a second line of defense).
trap 'rm -f "$CF"' EXIT

# Immediate in-progress feedback: mark this SSID in a temp file (NOT an eww var
# — the poll reads the file; calling eww from the defpoll script deadlocks the
# GTK main thread), then redraw the list so the row flips to "连接中…" at once.
echo "$ssid" > "$CF"
eww update wifi_networks="$("$S/network-wifi-networks.sh")"

# Cap a stuck connect so the mark can't linger forever; fall back to the GUI
# editor when nmcli can't complete (e.g. needs a password).
if ! timeout 30 nmcli device wifi connect "$ssid" 2>/dev/null; then
    nm-connection-editor &
fi

# Clear the mark and reflect the real connection state at once.
rm -f "$CF"
eww update wifi_on="$("$S/network-wifi-on.sh")"
eww update wifi_name="$("$S/network-wifi-name.sh")"
eww update wifi_networks="$("$S/network-wifi-networks.sh")"
exit 0
