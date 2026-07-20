#!/usr/bin/env bash
# Get audio devices list and current defaults
# Output: JSON with sinks, sources, and current defaults

get_friendly_name() {
    local name="$1"
    local desc="$2"
    
    if [[ "$name" == *"bluez_output"* ]]; then
        echo "蓝牙耳机"
    elif [[ "$name" == *"bluez_input"* ]]; then
        echo "蓝牙麦克风"
    elif [[ "$name" == *"alsa_output"* ]]; then
        echo "内置扬声器"
    elif [[ "$name" == *"alsa_input"* ]]; then
        echo "内置麦克风"
    else
        echo "$desc"
    fi
}

# Get current defaults
current_sink=$(pactl get-default-sink 2>/dev/null || echo "")
current_source=$(pactl get-default-source 2>/dev/null || echo "")

# Build sinks array
sinks_json="["
first=true
while IFS=$'\t' read -r idx name desc; do
    [ -z "$name" ] && continue
    friendly=$(get_friendly_name "$name" "$desc")
    is_active="false"
    [ "$name" = "$current_sink" ] && is_active="true"
    
    if [ "$first" = true ]; then
        first=false
    else
        sinks_json+=","
    fi
    sinks_json+="{\"name\":\"$name\",\"friendly\":\"$friendly\",\"active\":$is_active}"
done < <(pactl list short sinks 2>/dev/null | awk '{print $1 "\t" $2 "\t" $3}')

# Get descriptions for sinks
while IFS= read -r line; do
    if [[ "$line" =~ ^Name:\ (.+)$ ]]; then
        sink_name="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\s+Description:\ (.+)$ ]]; then
        sink_desc="${BASH_REMATCH[1]}"
    fi
done < <(pactl list sinks 2>/dev/null)

sinks_json+="]"

# Build sources array (exclude monitors)
sources_json="["
first=true
while IFS=$'\t' read -r idx name desc; do
    [ -z "$name" ] && continue
    [[ "$name" == *".monitor" ]] && continue
    
    friendly=$(get_friendly_name "$name" "$desc")
    is_active="false"
    [ "$name" = "$current_source" ] && is_active="true"
    
    if [ "$first" = true ]; then
        first=false
    else
        sources_json+=","
    fi
    sources_json+="{\"name\":\"$name\",\"friendly\":\"$friendly\",\"active\":$is_active}"
done < <(pactl list short sources 2>/dev/null | awk '{print $1 "\t" $2 "\t" $3}')

sources_json+="]"

# Get current friendly names
current_sink_friendly=""
current_source_friendly=""
if [ -n "$current_sink" ]; then
    current_sink_friendly=$(get_friendly_name "$current_sink" "")
fi
if [ -n "$current_source" ]; then
    current_source_friendly=$(get_friendly_name "$current_source" "")
fi

# Output JSON
cat <<EOF
{
  "current_sink": "$current_sink",
  "current_sink_friendly": "$current_sink_friendly",
  "current_source": "$current_source",
  "current_source_friendly": "$current_source_friendly",
  "sinks": $sinks_json,
  "sources": $sources_json
}
EOF
