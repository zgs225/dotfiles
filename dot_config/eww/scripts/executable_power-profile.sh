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
        printf '{"mode":"unavailable","profile":"","source":"","icon":"%s","label":"电源","icon_auto":"%s","icon_powersave":"%s","icon_performance":"%s"}\n' \
            "$ICON_UNKNOWN" "$ICON_AUTO" "$ICON_POWERSAVE" "$ICON_PERFORMANCE"
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
    printf '{"mode":"%s","profile":"%s","source":"%s","icon":"%s","label":"%s","icon_auto":"%s","icon_powersave":"%s","icon_performance":"%s"}\n' \
        "$mode" "$profile" "$src" "$icon" "$label" "$ICON_AUTO" "$ICON_POWERSAVE" "$ICON_PERFORMANCE"
}

cmd_set() {
    command -v tlpctl >/dev/null 2>&1 || exit 0
    case "$1" in
        auto)        tlpctl set "$(source_default_profile)" >/dev/null 2>&1 ;;
        powersave)   tlpctl set power-saver >/dev/null 2>&1 ;;
        performance) tlpctl set performance >/dev/null 2>&1 ;;
    esac
}

# `tlpctl get` lags ~0.3s behind `tlpctl set`, so re-reading it right after a set
# yields the PREVIOUS profile (the highlight would show the old mode). Instead
# emit the deterministic target state straight from the requested mode: the
# seg-btn highlight / cc quick icon flip the instant the click lands, and the
# 3s poll reconciles against the real profile afterwards.
emit_for_mode() {
    local mode="$1" profile icon label src
    case "$mode" in
        auto)        profile="$(source_default_profile)"; icon="$ICON_AUTO";        label="自动" ;;
        powersave)   profile="power-saver";               icon="$ICON_POWERSAVE";   label="省电" ;;
        performance) profile="performance";               icon="$ICON_PERFORMANCE"; label="性能" ;;
        *)           return 0 ;;
    esac
    if on_ac; then src=ac; else src=bat; fi
    printf '{"mode":"%s","profile":"%s","source":"%s","icon":"%s","label":"%s","icon_auto":"%s","icon_powersave":"%s","icon_performance":"%s"}\n' \
        "$mode" "$profile" "$src" "$icon" "$label" "$ICON_AUTO" "$ICON_POWERSAVE" "$ICON_PERFORMANCE"
}

show_mode() { eww update power_profile="$(emit_for_mode "$1")" 2>/dev/null; }

# tlpctl takes ~0.6s; eww SIGKILLs onclick children after 200ms.
# Detach into a new session so the real work survives.
if [ "${1:-}" = "set" ] || [ "${1:-}" = "cycle" ]; then
    if [ -z "${_PP_DETACHED:-}" ]; then
        _PP_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
        exit 0
    fi
fi

case "${1:-get}" in
    get) cmd_get ;;
    set)
        show_mode "${2:-auto}"   # optimistic highlight, then apply (~0.2s)
        cmd_set "${2:-auto}"
        ;;
    cycle)
        case "$(mode_of "$(current_profile)")" in
            auto)        next=powersave ;;
            powersave)   next=performance ;;
            *)           next=auto ;;
        esac
        show_mode "$next"
        cmd_set "$next"
        ;;
esac
