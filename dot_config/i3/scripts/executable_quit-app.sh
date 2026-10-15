#!/bin/sh
# Gracefully quit the app owning the focused window (macOS Cmd+Q style):
# 1. Send WM_DELETE to every window of the same PID (triggers normal close
#    handling, e.g. "save changes?" dialogs).
# 2. If the process is still alive but has no windows left (tray-only apps),
#    send SIGTERM so it can clean up and exit.
#
# WezTerm exception: multiple wezterm windows normally share one wezterm-gui
# process (the x11-:0-<class> symlink delegation of `wezterm start`), so the
# PID-wide sweep would close *every* wezterm window. Close only the focused
# window with WM_DELETE; window_close_confirmation='NeverPrompt' guarantees it
# responds, so no SIGTERM fallback is needed.
win=$(xdotool getactivewindow 2>/dev/null) || exit 0
[ -n "$win" ] || exit 0
pid=$(xprop -id "$win" _NET_WM_PID 2>/dev/null | grep -oE '[0-9]+')
[ -n "$pid" ] || exit 0

if tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q 'wezterm-gui'; then
    xdotool windowclose "$win" 2>/dev/null
    exit 0
fi

for w in $(xdotool search --pid "$pid" 2>/dev/null); do
    xdotool windowclose "$w" 2>/dev/null
done

sleep 0.5
# Apps with "close to tray" (e.g. Bitwarden) legitimately hide to tray on
# WM_DELETE — they must survive, not be SIGTERMed. Match on cmdline since
# Arch's Electron-packaged apps all have comm="electron".
cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
case "$cmdline" in
    *[Bb]itwarden*) exit 0 ;;
esac

# Use --onlyvisible: apps like Clash Verge hide to tray by *unmapping*
# their window, so a plain search would still find it and skip SIGTERM.
if kill -0 "$pid" 2>/dev/null && [ -z "$(xdotool search --onlyvisible --pid "$pid" 2>/dev/null)" ]; then
    kill "$pid" 2>/dev/null
fi
