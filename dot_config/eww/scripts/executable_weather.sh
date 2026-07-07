#!/usr/bin/env bash
# Called by defpoll (~15m). Best-effort weather via wttr.in with a 30-min cache.
# Emits JSON: {"temp","desc","lohi"}. Falls back to placeholders when offline.

CACHE="/tmp/eww_weather.json"
MAXAGE=1800

if [ -f "$CACHE" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))
    if [ "$age" -lt "$MAXAGE" ]; then
        cat "$CACHE"; exit 0
    fi
fi

raw=$(curl -fsm 6 "https://wttr.in/?format=j1" 2>/dev/null)
if [ -n "$raw" ] && command -v jq >/dev/null 2>&1; then
    out=$(printf '%s' "$raw" | jq -c '{
        temp: (.current_condition[0].temp_C + "\u00b0C"),
        desc: (.current_condition[0].weatherDesc[0].value),
        lohi: (.weather[0].mintempC + "\u00b0 / " + .weather[0].maxtempC + "\u00b0")
    }' 2>/dev/null)
    if [ -n "$out" ]; then
        printf '%s\n' "$out" | tee "$CACHE"
        exit 0
    fi
fi

printf '{"temp":"--\u00b0C","desc":"Unavailable","lohi":"--\u00b0 / --\u00b0"}\n'
