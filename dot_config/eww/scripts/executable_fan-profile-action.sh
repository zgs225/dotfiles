#!/usr/bin/env bash
# Fan-profile seg-btn onclick: apply the choice and refresh the eww
# variable from sysfs immediately. Unlike tlpctl, the sysfs write is
# synchronous, so the read-back is authoritative -- no optimistic emit.
set -euo pipefail

# Detach guard -- eww SIGKILLs onclick commands after 200ms.
if [ -z "${FAN_PROFILE_ACTION_DETACHED:-}" ]; then
    FAN_PROFILE_ACTION_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 8>&- 9>&- &
    exit 0
fi

cmd="${1:-}"
choice="${2:-}"
case "$cmd" in
    set) ;;
    *)
        echo "usage: fan-profile-action.sh set quiet|balanced|performance" >&2
        exit 2
        ;;
esac
case "$choice" in
    quiet | balanced | performance) ;;
    *)
        echo "usage: fan-profile-action.sh set quiet|balanced|performance" >&2
        exit 2
        ;;
esac

if ! sudo -n /usr/local/lib/fan-profile/fan-profile set "$choice" >/dev/null 2>&1; then
    notify-send -a fan-profile -u critical "风扇策略" "切换失败：$choice（缺少 NOPASSWD sudo 权限？）" 2>/dev/null || true
    exit 1
fi

# Read back the authoritative state and push it into eww instantly; the
# daemon poll reconciles afterwards. Never update with an empty value
# (gotchas #26/#27).
state=$(timeout 3 fan-profile status --json 2>/dev/null || true)
if [ -n "$state" ]; then
    eww update fan_profile="$state"
fi
