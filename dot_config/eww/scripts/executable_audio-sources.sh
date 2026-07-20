#!/usr/bin/env bash
# Get audio sources (input devices) as JSON array

get_friendly_name() {
    local name="$1"
    if [[ "$name" == *"bluez_input"* ]]; then
        echo "蓝牙麦克风"
    elif [[ "$name" == *"alsa_input"* ]]; then
        echo "内置麦克风"
    else
        echo "$name"
    fi
}

current_source=$(pactl get-default-source 2>/dev/null || echo "")

echo -n "["
first=true
while IFS=$'\t' read -r idx name rest; do
    [ -z "$name" ] && continue
    [[ "$name" == *".monitor" ]] && continue
    friendly=$(get_friendly_name "$name")
    is_active="false"
    [ "$name" = "$current_source" ] && is_active="true"
    if [ "$first" = true ]; then first=false; else echo -n ","; fi
    echo -n "{\"name\":\"$name\",\"friendly\":\"$friendly\",\"active\":$is_active}"
done < <(pactl list short sources 2>/dev/null)
echo "]"
