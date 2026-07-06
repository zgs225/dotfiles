#!/usr/bin/env bash
# Called by defpoll every 500ms
# Output: single line of concatenated (box :class ... ) yuck elements

workspaces_json=$(i3-msg -t get_workspaces 2>/dev/null)
if [ -z "$workspaces_json" ]; then
    echo ""
    exit 0
fi

echo "$workspaces_json" | jq -j 'sort_by(.num) | .[] |
  if .focused then
    "(box :class \"focused\" :onclick \"i3-msg workspace \(.num)\" \"\")"
  elif .urgent then
    "(box :class \"urgent\" :onclick \"i3-msg workspace \(.num)\" \"\")"
  elif (.nodes | length) > 0 then
    "(box :class \"occupied\" :onclick \"i3-msg workspace \(.num)\" \"\")"
  else
    "(box :class \"idle\" :onclick \"i3-msg workspace \(.num)\" \"\")"
  end
'
