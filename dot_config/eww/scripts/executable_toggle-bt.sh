#!/usr/bin/env bash
# toggle-bt.sh
rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: yes" && rfkill unblock bluetooth || rfkill block bluetooth
