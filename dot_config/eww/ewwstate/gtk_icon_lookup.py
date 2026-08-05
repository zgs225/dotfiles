"""Resolve icon names to file paths via the session GTK icon theme.

Standalone helper, invoked by collectors/notifications.py as a subprocess:
GTK3 is not thread-safe and the ewwstate daemon is pure asyncio, so GTK
must never be touched in-process. A segfault here kills only this tiny
helper, never the daemon.

Usage: gtk_icon_lookup.py CANDIDATE...  → prints first resolved path.
Exits 1 when no candidate resolves.
"""
import sys

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk


def main() -> int:
    theme = Gtk.IconTheme.get_default()
    for cand in sys.argv[1:]:
        info = theme.lookup_icon(cand, 48, 0)
        if info:
            fn = info.get_filename()
            if fn:
                print(fn)
                return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
