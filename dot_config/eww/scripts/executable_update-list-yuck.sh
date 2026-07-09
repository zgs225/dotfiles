#!/usr/bin/env bash
CACHE="$HOME/.cache/eww/updates.json"
GROUP=$(eww get updates_active_group 2>/dev/null || echo "official")

esc() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

if [ ! -f "$CACHE" ]; then
    echo "(box :class \"update-empty\" :orientation \"v\" (label :class \"update-empty-text\" :xalign 0.5 :text \"No data\"))"
    exit 0
fi

items=""
while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    name=$(printf '%s' "$pkg" | jq -r '.name // ""')
    old=$(printf '%s' "$pkg" | jq -r '.old // ""')
    new=$(printf '%s' "$pkg" | jq -r '.new // ""')
    e_name=$(printf '%s' "$name" | esc)
    e_old=$(printf '%s' "$old" | esc)
    e_new=$(printf '%s' "$new" | esc)
    items="${items}(box :class \"update-list-item\" :orientation \"h\" :space-evenly false :spacing 8"
    items="${items}(label :class \"update-pkg-name\" :hexpand true :xalign 0 :text \"${e_name}\")"
    items="${items}(label :class \"update-pkg-version\" :xalign 1 :text \"${e_old} → ${e_new}\"))"
done < <(jq -c --arg g "$GROUP" '.[$g][]' "$CACHE" 2>/dev/null)

if [ -z "$items" ]; then
    items="(label :class \"update-empty-text\" :xalign 0.5 :text \"No updates in this group\")"
fi

echo "(scroll :vscroll true :hscroll false :vexpand true :class \"update-list-scroll\" (box :class \"update-list\" :orientation \"v\" :spacing 4 ${items}))"
