#!/usr/bin/env bash
# Emits "true" while a night-light (redshift/gammastep) is active, else "false".
if pgrep -x redshift >/dev/null 2>&1 || pgrep -x gammastep >/dev/null 2>&1; then
    echo true
else
    echo false
fi
