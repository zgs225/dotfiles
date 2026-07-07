#!/usr/bin/env bash
nmcli radio wifi 2>/dev/null | grep -q "enabled" && echo 1 || echo 0
