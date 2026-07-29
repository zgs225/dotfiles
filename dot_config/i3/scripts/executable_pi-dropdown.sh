#!/usr/bin/env bash
# Launch the pi coding agent as a dropdown (scratchpad) terminal, running
# inside a dedicated, persistent tmux session.
#
# Why tmux: the wezterm window is only a view onto the `pi-dropdown` tmux
# session. Closing/killing the window does NOT kill pi — the session (and the
# running agent) survives in the tmux server, and the next toggle reattaches.
# This is what makes show/hide robust "in all cases".
#
# The window is tagged WM_CLASS "dropdown-pi" so it matches the
# `for_window [class="dropdown-.*"]` rule in the i3 config, which floats it,
# centers it and parks it in the scratchpad. pi-dropdown-toggle.sh (bound to
# $mod+backslash) shows/hides it.
#
# Idempotent on the WINDOW: if a dropdown-pi window already exists this is a
# no-op, so it is safe from i3 autostart and from repeated invocation.
set -euo pipefail

CLASS="dropdown-pi"
SESSION="pi-dropdown"

# Window already up? (xdotool matches the WM_CLASS class portion)
if [ -n "$(xdotool search --class "$CLASS" 2>/dev/null)" ]; then
    exit 0
fi

# -A: attach if the session already exists (pi still running there), otherwise
# create it running pi. Closing the window never destroys the session.
exec ~/.config/wezterm/wezterm-wrap.sh start \
    --class "$CLASS" \
    --cwd "$HOME" \
    -- tmux new-session -A -s "$SESSION" pi
