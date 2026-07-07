#!/usr/bin/env bash
# Called by defpoll every 500ms
# Output: a SINGLE root (box ...) yuck element wrapping the workspace dots
# (eww `literal` requires exactly one root element).

workspaces_json=$(i3-msg -t get_workspaces 2>/dev/null)
if [ -z "$workspaces_json" ]; then
    echo "(box)"
    exit 0
fi

dots=$(echo "$workspaces_json" | jq -j 'sort_by(.num) | .[] |
  (if .focused then "focused"
   elif .urgent then "urgent"
   elif (.nodes | length) > 0 then "occupied"
   else "idle" end) as $state |
  "(eventbox :class \"ws-dot\" :halign \"center\" :valign \"center\" :vexpand false :onclick \"i3-msg workspace \(.num)\" (box :class \"ws-dot-inner \($state)\" :halign \"center\" :valign \"center\" :hexpand false :vexpand false))"
')

echo "(box :class \"ws-list\" :halign \"center\" :valign \"center\" :vexpand false :spacing 6 ${dots})"
