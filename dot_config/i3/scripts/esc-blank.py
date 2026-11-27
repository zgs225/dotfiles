#!/usr/bin/env python3
"""esc-blank.py — turn the panel off when ESC is pressed on the lock screen.

Started by lock.sh for the lifetime of i3lock (it exits when its parent dies),
so it can never blank the screen in an unlocked session.

Why a watcher instead of an i3lock option
-----------------------------------------
i3lock-color 2.13 is based on i3lock 2.13, which *removed* DPMS support: the
classic "-d/--dpms: ESC (or backspace) with an empty password buffer turns the
monitors off" behaviour is gone and upstream refuses to readd it ("DPMS support
has been removed from i3lock").

Why XInput2 raw events
----------------------
While locked, i3lock holds an *active* keyboard grab, so key events are
delivered to i3lock only — a normal X client never sees the ESC, and i3's
bindsym grabs / xdotool / xinput do not either. XI2 *raw* events are generated
at the device layer and are exempt from grabs, so XI_RawKeyPress on the root
window still reports every key i3lock swallows. Verified on this machine
against a real i3lock grab: RawKeyPress detail=9 / keysym=Escape arrives.

Why the `blanked` bookkeeping
-----------------------------
Any input wakes a DPMS-off panel *before* the key is delivered, so by the time
the raw event reaches us the panel is already lit again. The press that wakes
a dark lock screen must therefore not blank it, or ESC would look broken
(screen flashes, goes dark, and pressing ESC "does nothing"). `blanked` tracks
"we blanked it and no other input has arrived since", which is exactly the
condition under which this ESC is the waking press:

    ESC on a lit panel   -> xset dpms force off, blanked = True
    ESC on our dark panel-> leave it lit (the press just woke it)
    any other input      -> blanked = False (that input woke the panel)

A panel blanked by somebody else (idle-lock.sh's "30s after auto-lock" timer,
dpms-auto.sh on battery) cannot be detected reliably — the wake races our
state query and wins — so ESC there just re-blanks it: press any other key to
wake. That matches the classic i3lock behaviour of "ESC = go dark".

DPMS is driven through `xset` (its own X connection, same idiom as
idle-lock.sh) so this client issues *no* request/reply round-trip on its
long-lived connection: python-xlib is known to desync its request/reply
matching over a long session (see the patched keyd-application-mapper note in
eos-bootstrap), and a wedged watcher would silently lose the feature.

Tested with a /dev/uinput virtual keyboard (real input path, so the DPMS wake
behaves exactly like a physical key) against i3lock -n, plus SIGTERM/SIGKILL
of lock.sh to confirm the watcher never outlives the lock.
"""

import ctypes
import os
import select
import signal
import struct
import subprocess
import sys

from Xlib import XK, display
from Xlib.ext import xinput


def log(msg):
    print(f"esc-blank: {msg}", file=sys.stderr, flush=True)


def die_with_parent():
    """Leave with lock.sh — a stale watcher would blank the screen on every
    ESC in a normal session."""
    pr_set_pdeathsig = 1
    try:
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(pr_set_pdeathsig, signal.SIGTERM)
    except OSError as exc:  # pragma: no cover — odd libc
        log(f"prctl(PDEATHSIG) failed: {exc}")
    if os.getppid() == 1:  # parent vanished before prctl took effect
        sys.exit(0)


def force_off():
    try:
        return subprocess.run(
            ["xset", "dpms", "force", "off"],
            capture_output=True,
            timeout=5,
        ).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def main():
    die_with_parent()

    dsp = display.Display()
    if not dsp.has_extension("XInputExtension"):
        log("no XInputExtension on this server — ESC blanking disabled")
        return 0
    # python-xlib initialises every extension the server advertises at connect
    # time, so the XI2 request helpers are already registered.
    info = dsp.query_extension("XInputExtension")

    root = dsp.screen().root
    root.xinput_select_events([(
        xinput.AllDevices,
        xinput.RawKeyPressMask
        | xinput.RawKeyReleaseMask
        | xinput.RawButtonPressMask
        | xinput.RawMotionMask,
    )])
    dsp.sync()

    # Every keycode currently bound to Escape (keyd/layout changes included).
    escape_codes = {
        code for code in range(8, 256)
        if dsp.keycode_to_keysym(code, 0) == XK.XK_Escape
    }

    fds = [dsp.fileno()]
    esc_down = False
    blanked = False

    def on_escape():
        nonlocal blanked
        if blanked:
            blanked = False
            log("ESC on our own blank — leaving the panel awake")
            return
        if force_off():
            blanked = True
            log("panel off")
        else:
            log("xset dpms force off failed")

    log(f"watching for ESC (escape keycodes: {sorted(escape_codes)})")

    while True:
        select.select(fds, [], [], None)
        while dsp.pending_events():
            ev = dsp.next_event()
            if ev.__class__.__name__ != "GenericEvent":
                continue
            if ev.extension != info.major_opcode:
                continue

            if ev.evtype not in (
                xinput.RawKeyPress,
                xinput.RawKeyRelease,
                xinput.RawButtonPress,
            ):
                blanked = False  # pointer motion woke the panel
                continue

            code = struct.unpack_from("<I", bytes(ev.data), 6)[0]
            if code in escape_codes:
                if ev.evtype == xinput.RawKeyPress:
                    # Press repeats and the slave+master duplicate of a single
                    # press both land here; only the first counts.
                    if not esc_down:
                        esc_down = True
                        on_escape()
                else:
                    esc_down = False
            elif blanked:
                blanked = False
                log("panel woken by other input")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
