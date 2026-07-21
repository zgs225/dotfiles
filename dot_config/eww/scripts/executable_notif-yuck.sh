#!/usr/bin/env bash
# Called by defpoll every 2s.
# Renders `dunstctl history` into a SINGLE root (box ...) yuck element
# (eww `literal` needs exactly one root). Each row: [app icon] title/body [ago].

hist=$(dunstctl history 2>/dev/null)
count=$(printf '%s' "$hist" | jq '.data[0] | length' 2>/dev/null || echo 0)

if [ "${count:-0}" -eq 0 ] 2>/dev/null; then
    echo "(box :class \"notif-scroll\" :orientation \"v\" (label :class \"notif-empty\" :xalign 0.5 :valign \"center\" :text \"暂无通知\"))"
    exit 0
fi

uptime_s=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)

esc() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

# Map an app name to (glyph, color-class).
app_icon() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        *slack*)              echo "󰒱 slack" ;;
        *telegram*)           echo "󰔗 telegram" ;;
        *github*|*git*)       echo "󰊤 github" ;;
        *discord*)            echo "󰙯 discord" ;;
        *spotify*|*music*)    echo "󰓇 spotify" ;;
        *firefox*|*chrom*)    echo "󰈹 web" ;;
        *mail*|*thunder*)     echo "󰇮 mail" ;;
        *volume*|*audio*)     echo "󰕾 sys" ;;
        *update*|*pacman*)    echo "󰚰 sys" ;;
        *screenshot*|*maim*)  echo "󰹑 sys" ;;
        *)                    echo "󰂚 sys" ;;
    esac
}

items=""
while IFS= read -r row; do
    [ -z "$row" ] && continue
    appname=$(printf '%s' "$row" | jq -r '.appname.data // "dunst"')
    summary=$(printf '%s' "$row" | jq -r '.summary.data // ""')
    body=$(printf '%s' "$row" | jq -r '.body.data // ""')
    ts_us=$(printf '%s' "$row" | jq -r '.timestamp.data // 0')

    age=$(( uptime_s - ts_us / 1000000 ))
    [ "$age" -lt 0 ] && age=0
    if   [ "$age" -lt 60 ];    then ago="刚刚"
    elif [ "$age" -lt 3600 ];  then ago="$((age / 60)) 分钟前"
    elif [ "$age" -lt 86400 ]; then ago="$((age / 3600)) 小时前"
    else ago="$((age / 86400)) 天前"; fi

    read -r glyph cls < <(app_icon "$appname")

    e_sum=$(printf '%s' "$summary" | esc)
    e_body=$(printf '%s' "$body" | esc)
    e_ago=$(printf '%s' "$ago" | esc)

    items="${items}(box :class \"notif-item\" :orientation \"h\" :spacing 12 :valign \"start\" :space-evenly false"
    items="${items}(box :class \"notif-appicon icon-${cls}\" :valign \"start\" :halign \"center\" (label :text \"${glyph}\"))"
    items="${items}(box :orientation \"v\" :spacing 2 :hexpand true :space-evenly false"
    items="${items}(box :orientation \"h\" :space-evenly false"
    items="${items}(label :class \"notif-title\" :xalign 0 :hexpand true :limit-width 26 :text \"${e_sum}\")"
    items="${items}(label :class \"notif-time\" :xalign 1 :text \"${e_ago}\"))"
    if [ -n "$e_body" ]; then
        items="${items}(label :class \"notif-body\" :xalign 0 :wrap true :limit-width 40 :text \"${e_body}\")"
    fi
    items="${items}))"
done < <(printf '%s' "$hist" | jq -c '.data[0][]' 2>/dev/null)

echo "(box :class \"notif-scroll\" :orientation \"v\" :spacing 4 :space-evenly false ${items})"
