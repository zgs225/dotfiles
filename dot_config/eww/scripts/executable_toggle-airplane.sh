#!/usr/bin/env bash
# Toggle airplane mode: block/unblock all radios.
if rfkill list 2>/dev/null | grep -q "Soft blocked: no"; then
    rfkill block all
else
    rfkill unblock all
fi
