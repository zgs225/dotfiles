#!/usr/bin/env bash
CACHE_DIR="$HOME/.cache/eww"
CACHE_FILE="$CACHE_DIR/updates.json"
REFRESH_FLAG="$CACHE_DIR/update-list-refresh.flag"

esc() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

source_icon() {
    case "$1" in
        official) printf '%s' "" ;;
        aur)      printf '%s' "" ;;
    esac
}

source_class() {
    case "$1" in
        official|aur) printf '%s' "$1" ;;
        *)          printf 'unknown' ;;
    esac
}

render_group() {
    local source="$1"
    local icon
    icon=$(source_icon "$source")
    local css_class
    css_class=$(source_class "$source")

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
        items="${items}(label :class \"update-source-badge ${css_class}\" :text \"${icon}\")"
        items="${items}(label :class \"update-pkg-name\" :hexpand true :xalign 0 :text \"${e_name}\")"
        items="${items}(label :class \"update-pkg-version\" :xalign 1 :text \"${e_old} → ${e_new}\"))"
    done < <(jq -c --arg g "$source" '.[$g][]' "$CACHE_FILE" 2>/dev/null)
}

render() {
    local filter
    filter=$(eww get updates_filter 2>/dev/null || echo "all")
    case "$filter" in
        all|official|aur) : ;;
        *) filter="all" ;;
    esac

    if [ ! -f "$CACHE_FILE" ]; then
        echo "(box :class \"update-empty\" :orientation \"v\" (label :class \"update-empty-text\" :xalign 0.5 :text \"暂无数据\"))"
        return
    fi

    local items=""
    if [ "$filter" = "all" ]; then
        render_group "official"
        render_group "aur"
    else
        render_group "$filter"
    fi

    if [ -z "$items" ]; then
        items="(label :class \"update-empty-text\" :xalign 0.5 :text \"该分组无更新\")"
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
