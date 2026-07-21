#!/usr/bin/env bash
# Called by defpoll every 500ms
# Output: a SINGLE root (box ...) yuck element wrapping the workspace seals
# (eww `literal` requires exactly one root element).
#
# Workspace numbers map onto the ten Heavenly Stems (jia yi bing ding wu
# ji geng xin ren gui); numbers above 10 fall back to the digit itself.

stems=(甲 乙 丙 丁 戊 己 庚 辛 壬 癸)

workspaces_json=$(i3-msg -t get_workspaces 2>/dev/null)
if [ -z "$workspaces_json" ]; then
    echo "(box)"
    exit 0
fi

seals=""
while read -r num state; do
    [ -z "$num" ] && continue
    if [ "$num" -ge 1 ] && [ "$num" -le 10 ]; then
        glyph="${stems[$((num - 1))]}"
    else
        glyph="$num"
    fi
    seals+="(eventbox :class \"ws-seal-wrap\" :halign \"center\" :valign \"center\" :vexpand false :onclick \"i3-msg workspace ${num}\" (label :class \"ws-seal ${state}\" :halign \"center\" :valign \"center\" :text \"${glyph}\"))"
done < <(echo "$workspaces_json" | jq -r 'sort_by(.num) | .[] |
  "\(.num) \(if .focused then "active"
    elif .urgent then "urgent"
    elif (.nodes | length) > 0 then "occupied"
    else "idle" end)"')

echo "(box :class \"ws-list\" :halign \"center\" :valign \"center\" :vexpand false :spacing 8 ${seals})"
