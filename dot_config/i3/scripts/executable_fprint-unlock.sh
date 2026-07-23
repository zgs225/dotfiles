#!/usr/bin/env bash
# Parallel fingerprint listener for i3lock. Polls fprintd-verify and kills the
# given i3lock PID on match (killing i3lock unlocks the session). Exits when
# the PID disappears (password unlock). Self-gates on the fingerprint tier so
# lock.sh can spawn it unconditionally, keeping the D-Bus tier probe off the
# lock critical path.
set -u

pid="${1:?usage: fprint-unlock.sh <i3lock-pid>}"

fprint_tier() {
    [[ -e "$HOME/.config/i3/fprint.disable" ]] && { echo 0; return; }
    command -v fprintd-list >/dev/null 2>&1 || { echo 0; return; }
    local out
    out=$(timeout 5 fprintd-list "$USER" 2>/dev/null) || { echo 0; return; }
    grep -q '^ - #' <<<"$out" && { echo 2; return; }
    grep -q 'no fingers enrolled' <<<"$out" && { echo 1; return; }
    echo 0
}

[[ "$(fprint_tier)" == "2" ]] || exit 0

while kill -0 "$pid" 2>/dev/null; do
    if timeout 15 fprintd-verify >/dev/null 2>&1; then
        kill "$pid" 2>/dev/null
        exit 0
    fi
    sleep 0.3
done
