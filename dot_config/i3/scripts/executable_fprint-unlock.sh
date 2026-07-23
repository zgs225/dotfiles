#!/usr/bin/env bash
# Parallel fingerprint listener for i3lock. Polls fprintd-verify and kills the
# given i3lock PID on match (killing i3lock unlocks the session). Exits when
# the PID disappears (password unlock). Started by lock.sh only when the
# fingerprint tier is 2 (device present + prints enrolled).
set -u

pid="${1:?usage: fprint-unlock.sh <i3lock-pid>}"

while kill -0 "$pid" 2>/dev/null; do
    if timeout 15 fprintd-verify >/dev/null 2>&1; then
        kill "$pid" 2>/dev/null
        exit 0
    fi
    sleep 0.3
done
