#!/usr/bin/env bash
# Power profile via TLP >= 1.9 profiles (tlpctl, no root needed).
#   get  — called by defpoll (~3s). Emits JSON {mode,profile,source,icon,label}.
#          mode: auto = profile follows the power-source default (smart switch),
#          powersave | performance = manually locked, unavailable = tlpctl missing.
#   set auto|powersave|performance — switch mode (auto returns to source default).
#   cycle — auto -> powersave -> performance -> auto (cc quick button onclick).
set -u

AC_ONLINE=/sys/class/power_supply/AC0/online

ICON_AUTO=$(printf '\uf0d0')
ICON_POWERSAVE=$(printf '\uf06c')
ICON_PERFORMANCE=$(printf '\uf0e7')
ICON_UNKNOWN=$(printf '\uf128')

on_ac() {
    [ "$(cat "$AC_ONLINE" 2>/dev/null || echo 0)" = "1" ]
}

# Mirror of TLP_PROFILE_AC/BAT in /etc/tlp.d/00-eos.conf (managed by eos-bootstrap).
source_default_profile() {
    if on_ac; then echo balanced; else echo power-saver; fi
}

current_profile() {
    tlpctl get 2>/dev/null | head -n1 | tr -d '[:space:]'
}

mode_of() {
    case "$1" in
        "$(source_default_profile)") echo auto ;;
        power-saver) echo powersave ;;
        performance) echo performance ;;
        *) echo auto ;;
    esac
}

cmd_get() {
    if ! command -v tlpctl >/dev/null 2>&1; then
        printf '{"mode":"unavailable","profile":"","source":"","icon":"%s","label":"电源"}\n' "$ICON_UNKNOWN"
        exit 0
    fi
    local profile mode icon label src
    profile=$(current_profile)
    mode=$(mode_of "$profile")
    case "$mode" in
        auto)        icon="$ICON_AUTO"; label="自动" ;;
        powersave)   icon="$ICON_POWERSAVE"; label="省电" ;;
        performance) icon="$ICON_PERFORMANCE"; label="性能" ;;
        *)           icon="$ICON_UNKNOWN"; label="电源" ;;
    esac
    if on_ac; then src=ac; else src=bat; fi
    printf '{"mode":"%s","profile":"%s","source":"%s","icon":"%s","label":"%s"}\n' \
        "$mode" "$profile" "$src" "$icon" "$label"
}

cmd_set() {
    command -v tlpctl >/dev/null 2>&1 || exit 0
    case "$1" in
        auto)        tlpctl set "$(source_default_profile)" >/dev/null 2>&1 ;;
        powersave)   tlpctl set power-saver >/dev/null 2>&1 ;;
        performance) tlpctl set performance >/dev/null 2>&1 ;;
    esac
}

case "${1:-get}" in
    get) cmd_get ;;
    set) cmd_set "${2:-auto}" ;;
    cycle)
        case "$(mode_of "$(current_profile)")" in
            auto) cmd_set powersave & ;;
            powersave) cmd_set performance & ;;
            *) cmd_set auto & ;;
        esac
        ;;
esac
