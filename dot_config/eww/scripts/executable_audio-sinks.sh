#!/usr/bin/env bash
# Get audio sinks (output devices) as JSON array

get_friendly_name() {
    local name="$1"
    if [[ "$name" == *"bluez_output"* ]]; then
        echo "蓝牙耳机"
    elif [[ "$name" == *"alsa_output"* ]]; then
        echo "内置扬声器"
    else
        echo "$name"
    fi
}

current_sink=$(pactl get-default-sink 2>/dev/null || echo "")

echo -n "["
first=true
while IFS=$'\t' read -r idx name rest; do
    [ -z "$name" ] && continue
    friendly=$(get_friendly_name "$name")
    is_active="false"
    [ "$name" = "$current_sink" ] && is_active="true"
    if [ "$first" = true ]; then first=false; else echo -n ","; fi
    echo -n "{\"name\":\"$name\",\"friendly\":\"$friendly\",\"active\":$is_active}"
done < <(pactl list short sinks 2>/dev/null)
echo "]"
