#!/usr/bin/env bash

# fan — 风扇策略模块（fan-profile 框架）
# 前缀：fan。菜单 = 状态行（当前档位 + 风扇转速 + 温度）+ 档位选择。
# 切换走 NOPASSWD sudoers drop（fan-profile set），detach + notify。

register_module fan "fan" plain "" "风扇"

_fan_label() {
    case "$1" in
        quiet) echo "静音" ;;
        balanced) echo "均衡" ;;
        performance) echo "性能" ;;
        *) echo "$1" ;;
    esac
}

_fan_icon() {
    case "$1" in
        quiet) echo "weather-windy" ;;
        balanced) echo "preferences-system" ;;
        performance) echo "system-run" ;;
        *) echo "dialog-information" ;;
    esac
}

fan_init() {
    printf '\0prompt\x1f风扇\n'
    printf '\0no-custom\x1ftrue\n'

    local state supported current
    state=$(timeout 3 fan-profile status --json 2>/dev/null || true)
    case "$state" in
        "{"*) ;;
        *)
            msg_row "fan-profile 不可用" dialog-error
            return 0
            ;;
    esac

    supported=$(jq -r '.supported // false' <<<"$state")
    current=$(jq -r '.current // empty' <<<"$state")

    # 状态行（nonselectable）：风扇转速 + 温度
    local status_line
    # jq 三元 ?: 在条件含 pipe 时不合法，必须用 if-then-else-end
    status_line=$(jq -r '
      (if (.fans | length) > 0 then
         ([.fans[] | ((.name | ascii_upcase) + " " + (.rpm | tostring))] | join(" · "))
       else "风扇 --" end) + " · " + (.temp_c | tostring) + "°C"' <<<"$state" 2>/dev/null) \
        || status_line="风扇 -- · --°C"

    if [ "$supported" = "true" ]; then
        msg_row "当前：$(_fan_label "$current") · $status_line"
    else
        msg_row "当前：-- · $status_line"
        msg_row "此设备不支持切换风扇策略" dialog-error
        return 0
    fi

    local c label mark
    while read -r c; do
        [ -n "$c" ] || continue
        label=$(_fan_label "$c")
        mark=""
        [ "$c" = "$current" ] && mark=" · 当前"
        row "$label$mark" "$(_fan_icon "$c")" "set:$c"
    done < <(jq -r '.choices[]' <<<"$state")
}

fan_select() {
    local info="${ROFI_INFO:-}"
    case "$info" in
        set:*)
            local choice="${info#set:}"
            setsid -f bash -c '
                choice="$1"
                if sudo -n /usr/local/lib/fan-profile/fan-profile set "$choice" >/dev/null 2>&1; then
                    case "$choice" in
                        quiet) label="静音" ;;
                        balanced) label="均衡" ;;
                        performance) label="性能" ;;
                        *) label="$choice" ;;
                    esac
                    notify-send -a fan-profile "风扇策略" "已切换：$label"
                else
                    notify-send -a fan-profile -u critical "风扇策略" "切换失败：$choice"
                fi
            ' _ "$choice" >/dev/null 2>&1
            ;;
    esac
}
