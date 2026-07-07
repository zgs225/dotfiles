#!/usr/bin/env bash
# Poll airplane mode → 1 when all radios soft-blocked, else 0.
out=$(rfkill list 2>/dev/null)
[ -z "$out" ] && { echo 0; exit 0; }
if echo "$out" | grep -q "Soft blocked: no"; then echo 0; else echo 1; fi
