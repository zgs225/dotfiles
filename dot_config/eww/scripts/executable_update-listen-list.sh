#!/usr/bin/env bash
CACHE_DIR="$HOME/.cache/eww"
CACHE_FILE="$CACHE_DIR/updates.json"
REFRESH_FLAG="$CACHE_DIR/update-list-refresh.flag"

esc() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

render() {
    local group
    group=$(eww get updates_active_group 2>/dev/null || echo "official")

    if [ ! -f "$CACHE_FILE" ]; then
        echo "(box :class \"update-empty\" :orientation \"v\" (label :class \"update-empty-text\" :xalign 0.5 :text \"No data\"))"
        return
    fi

    local items=""
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        local name old new e_name e_old e_new
        name=$(printf '%s' "$pkg" | jq -r '.name // ""')
        old=$(printf '%s' "$pkg" | jq -r '.old // ""')
        new=$(printf '%s' "$pkg" | jq -r '.new // ""')
        e_name=$(printf '%s' "$name" | esc)
        e_old=$(printf '%s' "$old" | esc)
        e_new=$(printf '%s' "$new" | esc)
        items="${items}(box :class \"update-list-item\" :orientation \"h\" :space-evenly false :spacing 8"
        items="${items}(label :class \"update-pkg-name\" :hexpand true :xalign 0 :text \"${e_name}\")"
        items="${items}(label :class \"update-pkg-version\" :xalign 1 :text \"${e_old} → ${e_new}\"))"
    done < <(jq -c --arg g "$group" '.[$g][]' "$CACHE_FILE" 2>/dev/null)

    if [ -z "$items" ]; then
        items="(label :class \"update-empty-text\" :xalign 0.5 :text \"No updates in this group\")"
    fi

    echo "(scroll :vscroll true :hscroll false :vexpand true :class \"update-list-scroll\" (box :class \"update-list\" :orientation \"v\" :spacing 4 ${items}))"
}

mkdir -p "$CACHE_DIR"

touch "$REFRESH_FLAG"
render

inotifywait -e modify,create,delete,move,attrib -m "$CACHE_DIR" 2>/dev/null | while read -r line; do
    case "$line" in
        *updates.json*|*update-list-refresh.flag*)
            render
            ;;
    esac
done
