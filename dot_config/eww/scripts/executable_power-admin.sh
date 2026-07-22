#!/usr/bin/env bash
# Privileged power actions (charge threshold / temporary full charge).
# onclick: power-admin.sh threshold <60|80|100> | power-admin.sh fullcharge
# Detach so eww's 200ms onclick SIGKILL can't kill us, then push the fresh
# power_info back to eww so the seg-btn highlight flips instantly. If the
# passwordless sudo is missing, surface it instead of failing silently.
if [ -z "$EWW_POWER_ADMIN_DETACHED" ]; then
    EWW_POWER_ADMIN_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi

ADMIN=/usr/local/sbin/eww-power-admin

# The privileged call is slow (sudo + `tlp start` ~0.6s) and power-info.sh adds
# ~0.2s more (longer while the dGPU is active). Updating only AFTER that leaves
# the seg-btn highlight dead for 1-3s. The highlight depends solely on
# power_info.threshold, so flip it optimistically the instant the click lands by
# overriding just that field in the current JSON; the reconcile below corrects
# everything once the write completes (and reverts the highlight if sudo fails).
if [ "$1" = threshold ]; then
    cur=$(timeout 3 eww get power_info 2>/dev/null)
    if [ -n "$cur" ]; then
        eww update power_info="$(printf '%s' "$cur" | sed -e "s/\"threshold\":\"[0-9]*\"/\"threshold\":\"${2:-80}\"/")" 2>/dev/null
    fi
fi

rc=0
case "$1" in
    threshold)  sudo -n "$ADMIN" threshold "${2:-80}" >/dev/null 2>&1 || rc=$? ;;
    fullcharge) sudo -n "$ADMIN" fullcharge >/dev/null 2>&1 || rc=$? ;;
    *) exit 1 ;;
esac

# Reconcile the other fields (watts/percent/dGPU) against reality. On a
# successful threshold write, keep threshold pinned to the requested value:
# sysfs can lag `tlp start` by ~1s, and reading it mid-transition would flicker
# the highlight target->old->target. The 3s poll confirms the settled value.
fresh=$(~/.config/eww/scripts/power-info.sh)
if [ "$rc" -eq 0 ] && [ "$1" = threshold ]; then
    fresh=$(printf '%s' "$fresh" | sed -e "s/\"threshold\":\"[0-9]*\"/\"threshold\":\"${2:-80}\"/")
fi
eww update power_info="$fresh"

if [ "$rc" -ne 0 ]; then
    notify-send "电源" "操作未执行：缺少免密 sudo 权限（NOPASSWD）" 2>/dev/null
fi
exit 0
