#!/usr/bin/env bash
# Login-time fingerprint enrollment reminder (autostarted by i3).
# Tier 1 only: device present but no prints enrolled -> dunstify with actions.
# Tier 0 (no device / opted out) and tier 2 (enrolled) exit silently.
# Re-invoked with --enroll inside a terminal to guide enrollment.
set -euo pipefail

STATE_DIR="$HOME/.local/state/i3"
DISMISS_MARKER="$STATE_DIR/fprint-reminder-dismissed"
TERM_WRAP="$HOME/.config/wezterm/wezterm-wrap.sh"

fprint_tier() {
    [[ -e "$HOME/.config/i3/fprint.disable" ]] && { echo 0; return; }
    command -v fprintd-list >/dev/null 2>&1 || { echo 0; return; }
    local out
    out=$(timeout 5 fprintd-list "$USER" 2>/dev/null) || { echo 0; return; }
    grep -q '^ - #' <<<"$out" && { echo 2; return; }
    grep -q 'no fingers enrolled' <<<"$out" && { echo 1; return; }
    echo 0
}

enroll() {
    echo "录入 right-index-finger（锁屏指纹解锁用）"
    if ! fprintd-enroll -f right-index-finger; then
        echo
        echo "直接录入失败（会话内无 polkit 授权代理），改用 sudo..."
        sudo fprintd-enroll -f right-index-finger "$USER"
    fi
    echo
    fprintd-list "$USER"
    echo "完成。锁屏后触摸传感器即可解锁。"
    read -r -p "按回车关闭窗口..." _
}

if [[ "${1:-}" == "--enroll" ]]; then
    enroll
    exit 0
fi

[[ -e "$DISMISS_MARKER" ]] && exit 0
[[ "$(fprint_tier)" == "1" ]] || exit 0

action=$(dunstify \
    --action=enroll,录入指纹 \
    --action=never,不再提醒 \
    --urgency=normal \
    --expiretime=0 \
    "检测到指纹模块" "录入指纹后，锁屏时触摸传感器即可解锁" || true)

case "$action" in
    enroll)
        setsid "$TERM_WRAP" start -e "$HOME/.config/i3/scripts/fprint-reminder.sh" --enroll >/dev/null 2>&1 &
        ;;
    never)
        mkdir -p "$STATE_DIR"
        touch "$DISMISS_MARKER"
        ;;
esac
