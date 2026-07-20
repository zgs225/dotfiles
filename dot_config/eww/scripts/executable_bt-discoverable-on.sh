#!/usr/bin/env bash
# Poll adapter discoverable state → 1 (on) / 0 (off).
bluetoothctl show 2>/dev/null | grep -q "Discoverable: yes" && echo 1 || echo 0
