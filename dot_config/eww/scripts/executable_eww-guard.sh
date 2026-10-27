#!/bin/bash
# eww-guard.sh -- sourced helper for scripts that drive eww windows.
# Source this file: source "$HOME/.config/eww/scripts/eww-guard.sh"
#
# eww 0.5.0 clients auto-spawn a daemon when they cannot reach the running one
# ("can_start_daemon"). The imposter unlinks the real IPC socket and rebinds
# the path, so every later client lands on a daemon whose window registry is
# empty: `eww close` reports success and closes nothing, `eww get` returns the
# defvar defaults, while the real windows keep belonging to the orphaned
# daemon. `eww ping` cannot detect it -- the imposter answers happily. Only the
# window registry does (frozen screenshot preview, 2026-10-26).
#
# ewwc():       use for every eww call from these scripts -- a stalled daemon
#               then turns the hijack into a plain failed call instead of
#               poisoning the socket for the whole session.
# eww_ensure(): repair a dead daemon or a hijacked socket. Call it before
#               opening a window and again before its auto-close timer fires.

ewwc() { timeout 4 eww "$@" --no-daemonize; }

# True when a daemon answers. One retry: a single ping can lose a race with a
# busy GTK main loop.
eww_daemon_up() {
    ewwc ping >/dev/null 2>&1 && return 0
    ewwc ping >/dev/null 2>&1
}

eww_window_exists() { # $1 = eww window name
    [ -n "$(xdotool search --name "^Eww - $1\$" 2>/dev/null | head -1)" ]
}

eww_owns_window() { # $1 = eww window name
    ewwc active-windows 2>/dev/null | grep -q "^$1:"
}

# launch.sh kills every eww process, drops the stale socket, restarts the state
# daemon and reopens the bar.
eww_relaunch() {
    if [ -x "$HOME/.config/eww/scripts/launch.sh" ]; then
        "$HOME/.config/eww/scripts/launch.sh" >/dev/null 2>&1 || true
    fi
}

# The bar is the sentinel: it is always on screen, so "bar exists in X but is
# missing from active-windows" is exactly the hijack signature.
eww_ensure() {
    if ! eww_daemon_up; then
        eww_relaunch
        return 0
    fi
    if eww_window_exists bar && ! eww_owns_window bar; then
        eww_relaunch
    fi
    return 0
}
