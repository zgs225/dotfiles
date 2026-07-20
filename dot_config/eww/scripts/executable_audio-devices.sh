#!/usr/bin/env bash
# Aggregate audio state for the control-center summary row. Reuses the
# per-list scripts so the friendly-name logic lives in exactly one place and
# the row never disagrees with the popup list.

sinks_json=$(~/.config/eww/scripts/audio-sinks.sh 2>/dev/null)
sources_json=$(~/.config/eww/scripts/audio-sources.sh 2>/dev/null)
[ -z "$sinks_json" ] && sinks_json="[]"
[ -z "$sources_json" ] && sources_json="[]"

current_sink=$(pactl get-default-sink 2>/dev/null || echo "")
current_source=$(pactl get-default-source 2>/dev/null || echo "")

current_sink_friendly=$(printf '%s' "$sinks_json" | jq -r '.[] | select(.active) | .friendly' 2>/dev/null | head -1)
current_source_friendly=$(printf '%s' "$sources_json" | jq -r '.[] | select(.active) | .friendly' 2>/dev/null | head -1)

jq -nc \
    --arg cs "$current_sink" \
    --arg csf "$current_sink_friendly" \
    --arg csrc "$current_source" \
    --arg csrcf "$current_source_friendly" \
    --argjson sinks "$sinks_json" \
    --argjson sources "$sources_json" \
    '{current_sink:$cs, current_sink_friendly:$csf, current_source:$csrc, current_source_friendly:$csrcf, sinks:$sinks, sources:$sources}'
