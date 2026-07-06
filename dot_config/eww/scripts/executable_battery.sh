#!/usr/bin/env bash
# Called by defpoll every 5s

BAT=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
if [ -z "$BAT" ]; then
    echo "battery_percent=100"
    echo "battery_charging=false"
    echo "battery_icon=󰁹"
    exit 0
fi

percent=$(cat "$BAT" 2>/dev/null || echo 100)
status=$(cat "${BAT%/*}/status" 2>/dev/null || echo "Unknown")

charging="false"
if [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
    charging="true"
fi

if [ "$charging" = "true" ]; then
    icon="󰂄"
elif [ "$percent" -ge 90 ] 2>/dev/null; then icon="󰁹"
elif [ "$percent" -ge 70 ] 2>/dev/null; then icon="󰂁"
elif [ "$percent" -ge 50 ] 2>/dev/null; then icon="󰁾"
elif [ "$percent" -ge 30 ] 2>/dev/null; then icon="󰁼"
elif [ "$percent" -ge 15 ] 2>/dev/null; then icon="󰁺"
else icon="󰂃"
fi

echo "battery_percent=$percent"
echo "battery_charging=$charging"
echo "battery_icon=$icon"
