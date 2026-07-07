#!/usr/bin/env bash
# Called by defpoll (~30m). Emits JSON: {"label","sub"}.
# Reads an optional user target from ~/.config/eww/countdown.txt formatted as
#   YYYY-MM-DD|Label
# Falls back to counting down to the upcoming weekend (Saturday).

CONF="$HOME/.config/eww/countdown.txt"
if [ -f "$CONF" ]; then
    line=$(head -1 "$CONF")
    target=${line%%|*}
    label=${line#*|}
    days=$(( ( $(date -d "$target" +%s 2>/dev/null || date +%s) - $(date +%s) ) / 86400 ))
    [ "$days" -lt 0 ] && days=0
    printf '{"label":"%s","sub":"%d days left"}\n' "${label:-Countdown}" "$days"
    exit 0
fi

dow=$(date +%u)   # 1=Mon .. 7=Sun
if [ "$dow" -ge 6 ]; then
    printf '{"label":"Weekend","sub":"It'\''s here"}\n'
else
    days=$(( 6 - dow ))
    printf '{"label":"Weekend","sub":"%d days left"}\n' "$days"
fi
