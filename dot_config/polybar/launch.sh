#!/usr/bin/env bash

if ! command -v polybar > /dev/null; then
    exit 0
fi

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
timeout=10
elapsed=0
while pgrep -u $UID -x polybar >/dev/null; do
    if [ "$elapsed" -ge "$timeout" ]; then
        break
    fi
    sleep 1
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
