#!/usr/bin/env bash
# Called by defpoll (~60s). Renders ~/.config/eww/events.json into a single
# root (box ...) yuck element for the calendar card's "Events" column.

CONF="$HOME/.config/eww/events.json"
if [ ! -f "$CONF" ]; then
    echo "(box :orientation \"v\" (label :class \"events-empty\" :xalign 0 :text \"暂无日程\"))"
    exit 0
fi

rows=""
while IFS= read -r item; do
    [ -z "$item" ] && continue
    title=$(printf '%s' "$item" | jq -r '.title // ""')
    time=$(printf '%s' "$item" | jq -r '.time // ""')
    color=$(printf '%s' "$item" | jq -r '.color // "blue"')
    esc() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
    e_title=$(printf '%s' "$title" | esc)
    e_time=$(printf '%s' "$time" | esc)
    rows="${rows}(box :class \"event-item\" :orientation \"h\" :spacing 8 :valign \"start\" :space-evenly false"
    rows="${rows}(box :class \"event-dot event-dot-${color}\" :valign \"center\")"
    rows="${rows}(box :orientation \"v\" :spacing 1 :hexpand true :space-evenly false"
    rows="${rows}(label :class \"event-title\" :xalign 0 :limit-width 18 :text \"${e_title}\")"
    rows="${rows}(label :class \"event-time\" :xalign 0 :text \"${e_time}\")))"
done < <(jq -c '.[]' "$CONF" 2>/dev/null)

if [ -z "$rows" ]; then
    rows="(label :class \"events-empty\" :xalign 0 :text \"暂无日程\")"
fi
echo "(box :class \"events-list\" :orientation \"v\" :spacing 10 ${rows})"
