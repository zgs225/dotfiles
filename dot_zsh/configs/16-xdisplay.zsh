# Fall back to the local X display when DISPLAY is unset.
#
# When attaching to tmux over SSH, tmux's `update-environment` (which lists
# DISPLAY by default) *removes* DISPLAY from the session environment because
# the attaching client has none — every new window/shell then runs without
# DISPLAY, silently breaking X/clipboard tools (e.g. pi.nvim :PiPasteImage ->
# img-clip.nvim needs DISPLAY to pick xclip). The tmux FAQ recommends fixing
# "must always be present" variables in a shell profile that runs for every
# shell rather than via update-environment.
#
# Only fills in a gap: an existing DISPLAY (local terminal, ssh -X forwarding)
# is never overridden. No-op on hosts without a local X server (e.g. macOS).
if [[ -z "$DISPLAY" ]]; then
  for _x11_sock in /tmp/.X11-unix/X*(N); do
    if [[ -S "$_x11_sock" ]]; then
      export DISPLAY=":${_x11_sock##*/X}"
      break
    fi
  done
  unset _x11_sock
fi
