#!/usr/bin/env bash
BAT_CAP=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
if [ -z "$BAT_CAP" ]; then
    echo false
    exit 0
fi
status=$(cat "${BAT_CAP%/*}/status" 2>/dev/null || echo "Unknown")
if [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
    echo true
else
    echo false
fi
