#!/usr/bin/env bash
# Poll bluetooth power state → 1 (on) / 0 (off).
if command -v bluetoothctl >/dev/null 2>&1; then
    bluetoothctl show 2>/dev/null | grep -q "Powered: yes" && echo 1 || echo 0
    exit 0
fi
rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: no" && echo 1 || echo 0
