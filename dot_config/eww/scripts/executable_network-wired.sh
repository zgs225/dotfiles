#!/usr/bin/env bash
nmcli -t -f TYPE,STATE c show --active 2>/dev/null | grep -q "^802-3-ethernet" && echo 1 || echo 0
