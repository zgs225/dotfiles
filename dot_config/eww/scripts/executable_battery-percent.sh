#!/usr/bin/env bash
BAT=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
if [ -z "$BAT" ]; then
    echo 100
    exit 0
fi
cat "$BAT" 2>/dev/null || echo 100
