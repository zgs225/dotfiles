#!/usr/bin/env bash
BAT_CAP=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
if [ -z "$BAT_CAP" ]; then
    echo "󰁹"
    exit 0
fi

percent=$(cat "$BAT_CAP" 2>/dev/null || echo 100)
status=$(cat "${BAT_CAP%/*}/status" 2>/dev/null || echo "Unknown")

charging="false"
if [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
    charging="true"
fi

if [ "$charging" = "true" ]; then
    echo "󰂄"
elif [ "$percent" -ge 90 ] 2>/dev/null; then
    echo "󰁹"
elif [ "$percent" -ge 70 ] 2>/dev/null; then
    echo "󰂁"
elif [ "$percent" -ge 50 ] 2>/dev/null; then
    echo "󰁾"
elif [ "$percent" -ge 30 ] 2>/dev/null; then
    echo "󰁼"
elif [ "$percent" -ge 15 ] 2>/dev/null; then
    echo "󰁺"
else
    echo "󰂃"
fi
