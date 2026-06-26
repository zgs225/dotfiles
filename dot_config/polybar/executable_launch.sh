#!/usr/bin/env bash

if ! command -v polybar > /dev/null; then
    exit 0
fi

DPI=$(xrdb -query | awk '/Xft.dpi/ {print $2}')
if [ -n "$DPI" ] && [ "$DPI" -ge 192 ] 2>/dev/null; then
    DPI_MODE=retina
elif [ -n "$DPI" ] && [ "$DPI" -ge 144 ] 2>/dev/null; then
    DPI_MODE=hidpi
else
    DPI_MODE=normal
fi
DPI_INI=/tmp/polybar-dpi.ini

case "$DPI_MODE" in
    retina)
        cat > "$DPI_INI" <<EOF
[bar/main]
height = 60
padding-left = 4
padding-right = 4
module-margin-left = 1
module-margin-right = 1
font-0 = "Symbols Nerd Font:size=24;1"
font-1 = "JetBrainsMono Nerd Font:size=20;2"
font-2 = "Noto Sans CJK SC:size=20;2"

[module/tray]
tray-maxsize = 32
tray-padding = 4
EOF
        ;;
    hidpi)
        cat > "$DPI_INI" <<EOF
[bar/main]
height = 45
padding-left = 3
padding-right = 3
module-margin-left = 1
module-margin-right = 1
font-0 = "Symbols Nerd Font:size=18;1"
font-1 = "JetBrainsMono Nerd Font:size=15;2"
font-2 = "Noto Sans CJK SC:size=15;2"

[module/tray]
tray-maxsize = 24
tray-padding = 3
EOF
        ;;
    *)
        cat > "$DPI_INI" <<EOF
[bar/main]
height = 30
padding-left = 2
padding-right = 2
module-margin-left = 1
module-margin-right = 1
font-0 = "Symbols Nerd Font:size=12;1"
font-1 = "JetBrainsMono Nerd Font:size=10;2"
font-2 = "Noto Sans CJK SC:size=10;2"

[module/tray]
tray-maxsize = 16
tray-padding = 2
EOF
        ;;
esac

# Terminate already running bar instances
polybar-msg cmd quit 2>/dev/null
sleep 0.5
killall -q polybar 2>/dev/null

# Wait until the processes have been shut down
timeout=10
elapsed=0
while pgrep -u $UID -x polybar >/dev/null 2>&1; do
    if [ "$elapsed" -ge "$timeout" ]; then
        killall -q -9 polybar 2>/dev/null
        sleep 0.5
        break
    fi
    sleep 0.5
    elapsed=$((elapsed + 1))
done

# Launch bar(s) — one per monitor
if type "xrandr" > /dev/null; then
    for m in $(polybar -m | cut -d":" -f1); do
        MONITOR=$m polybar --reload main &
    done
else
    polybar --reload main &
fi
