#!/usr/bin/env bash
# cal-add-action.sh — Thin wrapper for the eww calendar add-event form.
# Delegates all logic to ewwstate/cal_add.py.
set -euo pipefail

# Detach guard — eww SIGKILLs onclick commands after 200ms.
if [ -z "${EWW_CALADD_DETACHED:-}" ]; then
    EWW_CALADD_DETACHED=1 setsid nohup "$0" "$@" >/dev/null 2>&1 &
    exit 0
fi

export PYTHONDONTWRITEBYTECODE=1
exec python3 "$HOME/.config/eww/ewwstate/cal_add.py" "$@"
