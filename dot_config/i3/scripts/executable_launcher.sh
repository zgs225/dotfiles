#!/usr/bin/env bash

set -euo pipefail

DIR="$HOME/.config/i3/scripts"
source "$DIR/launcher.d/common.sh"
load_modules

mode_main() {
    if [ "$#" -eq 0 ]; then
        apps_init
        return 0
    fi
    local input="$1" info="${ROFI_INFO:-}"
    apps_select "$info" && return 0
    local mod prefix q
    for mod in "${MODS[@]}"; do
        prefix="${MOD_PREFIX[$mod]}"
        case "$input" in
            "$prefix "*|"$prefix")
                q="${input#"$prefix"}"; q="${q# }"
                case "${MOD_STAGE[$mod]}" in
                    direct) "${mod}_direct" "$q" ;;
                    *)      chain "$mod" "$q" ;;
                esac
                return 0
                ;;
        esac
    done
    fallback_drun "$input"
}

toggle_pattern() {
    local m list="launcher"
    for m in "${MODS[@]}"; do
        [ "${MOD_STAGE[$m]}" != direct ] && list+="|$m"
    done
    printf 'rofi -show (%s) -modi' "$list"
}

case "${1:-}" in
    "")
        local_pattern=$(toggle_pattern)
        if pgrep -f "$local_pattern" >/dev/null 2>&1; then
            pkill -f "$local_pattern"
            exit 0
        fi
        exec rofi -show launcher -modi "launcher:$SELF --mode-main" -theme "$THEME" \
            -kb-cancel "Escape,Alt+space"
        ;;
    --mode-main)
        shift
        mode_main "$@"
        ;;
    --mod)
        mod="${2:?missing module name}"
        shift 2
        if [ "$#" -eq 0 ]; then
            "${mod}_init"
        else
            "${mod}_select" "$@"
        fi
        ;;
    *)
        echo "未知参数：$*" >&2
        exit 1
        ;;
esac
