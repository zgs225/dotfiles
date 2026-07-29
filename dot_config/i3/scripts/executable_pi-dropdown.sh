#!/usr/bin/env bash
# Launch the pi coding agent as a dropdown (scratchpad) terminal.
#
# The window is tagged with WM_CLASS "dropdown-pi" so it matches the
# `for_window [class="dropdown-.*"]` rule in the i3 config, which floats it,
# centers it and parks it in the scratchpad. `$mod+backslash` then toggles it.
#
# Idempotent: if a dropdown-pi window already exists this is a no-op, so it is
# safe to run from i3 autostart on every login and to re-invoke manually.
set -euo pipefail

CLASS="dropdown-pi"

# Already running? (xdotool matches on the WM_CLASS class portion)
if [ -n "$(xdotool search --class "$CLASS" 2>/dev/null)" ]; then
    exit 0
fi

exec ~/.config/wezterm/wezterm-wrap.sh start \
    --class "$CLASS" \
    --cwd "$HOME" \
    -- pi
