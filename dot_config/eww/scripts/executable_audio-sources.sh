#!/usr/bin/env bash
# Input devices as a JSON array (monitors excluded). Friendly name = real
# Description, except the generic on-board "Built-in Audio" -> localized label.

current=$(pactl get-default-source 2>/dev/null || echo "")

json="[]"
while IFS=$'\t' read -r name desc; do
    [ -z "$name" ] && continue
    [[ "$name" == *.monitor ]] && continue
    if [[ "$desc" == *"Built-in Audio"* ]]; then
        friendly="内置麦克风"
    elif [ -n "$desc" ]; then
        friendly="$desc"
    else
        friendly="$name"
    fi
    active=false
    [ "$name" = "$current" ] && active=true
    json=$(printf '%s' "$json" | jq -c --arg n "$name" --arg f "$friendly" --argjson a "$active" \
        '. + [{"name":$n,"friendly":$f,"active":$a}]')
done < <(pactl list sources 2>/dev/null | awk '
    /^[[:space:]]*Name:[[:space:]]*/        { sub(/^[[:space:]]*Name:[[:space:]]*/, ""); name=$0 }
    /^[[:space:]]*Description:[[:space:]]*/ { sub(/^[[:space:]]*Description:[[:space:]]*/, ""); print name "\t" $0; name="" }
')

printf '%s' "$json"
