"""Fan/thermal profile collector (fan-profile status --json).

Reads the CLI's own read cache (``/run/user/<uid>/fan-profile.<uid>.status.json``)
first: a fresh entry costs zero subprocesses, while one ``fan-profile status``
invocation forks ~35 helpers for the hwmon scan. The CLI refreshes that file,
so a cold/expired cache simply falls through to the command. Fan RPM and
package temperature do not change fast enough to justify a 3s cadence.


New feature -- no legacy defpoll to migrate. Emits the fan-profile CLI
status JSON enriched with display strings and PUA icons for the power
popup's fan-policy section:

  {backend, supported, current, choices, fans, temp_c,
   fan_line, temp_line, icon_quiet, icon_balanced, icon_performance,
   icon_status}

Icons are injected here (PUA discipline, gotchas #20): yuck templates
contain no raw PUA characters.
"""
from __future__ import annotations

import json
import os
import time

from framework import PollCollector, collector
from util import run

#: A cached sample younger than this is published as-is (no subprocess). The
#: CLI's own TTL is 5s, so every other poll here is served from disk.
_CACHE_MAX_AGE = 20.0


def _cache_file() -> str:
    """Same path the CLI uses for its read cache (see lib/fan-profile)."""
    base = os.environ.get("XDG_RUNTIME_DIR") or os.environ.get("TMPDIR") or "/tmp"
    return os.path.join(base, f"fan-profile.{os.getuid()}.status.json")


def _cached_status(max_age: float = _CACHE_MAX_AGE) -> "str | None":
    """Return the cached JSON body when it is fresh and well-formed.

    The file is ``<epoch>\n<json>`` (written by the CLI). Anything unexpected
    returns None so the caller falls back to running the command.
    """
    try:
        with open(_cache_file(), encoding="utf-8") as handle:
            stamp = int(handle.readline().strip())
            body = handle.readline().strip()
    except (OSError, ValueError):
        return None
    if not body.startswith("{"):
        return None
    if time.time() - stamp > max_age:
        return None
    return body

# Symbols Nerd Font PUA codepoints, verified via fonttools cmap
# (SymbolsNerdFont-Regular.ttf). NOTE: codepoints above U+FFFF need the
# \U 8-hex-digit escape -- a 5-hex-digit \u escape silently becomes
# U+0XXX + a literal hex char (\uf081d = U+F081 + "d").
ICON_QUIET = "\U000F081D"  # md-fan_off
ICON_BALANCED = "\U000F0210"  # md-fan
ICON_PERFORMANCE = "\uf0e7"  # fa-bolt (same glyph as TLP performance)

_FALLBACK = {
    "backend": "",
    "supported": False,
    "current": "",
    "choices": [],
    "fans": [],
    "temp_c": 0,
    "fan_line": "--",
    "temp_line": "--",
}


def _friendly(name: str) -> str:
    """hwmon labels are sanitized by the CLI (cpu/gpu/...); uppercase."""
    n = name.strip()
    return n.upper() if n else "FAN"


@collector
class FanProfile(PollCollector):
    name = "fanprofile"
    topics = ("fan_profile",)
    # Fans/temps are slow-moving; the popup reads the last stored value, not a
    # fresh one, so a coarser cadence is invisible to the user.
    interval = 15.0

    async def collect(self):
        raw = _cached_status()
        if raw is None:
            raw = await run(["fan-profile", "status", "--json"], timeout=3.0)
        data = _FALLBACK
        if raw:
            try:
                parsed = json.loads(raw)
                if isinstance(parsed, dict):
                    data = parsed
            except ValueError:
                pass

        fans = data.get("fans")
        fan_line = "--"
        if isinstance(fans, list):
            parts = []
            for f in fans:
                if not isinstance(f, dict):
                    continue
                name = f.get("name")
                rpm = f.get("rpm")
                if name is None or rpm is None:
                    continue
                parts.append(f"{_friendly(str(name))} {int(rpm)}")
            if parts:
                fan_line = " · ".join(parts)

        temp = 0
        try:
            temp = int(data.get("temp_c") or 0)
        except (TypeError, ValueError):
            temp = 0

        data = dict(data)
        data.update(
            fan_line=fan_line,
            temp_line=f"{temp}°C" if temp else "--",
            icon_quiet=ICON_QUIET,
            icon_balanced=ICON_BALANCED,
            icon_performance=ICON_PERFORMANCE,
        )
        return {"fan_profile": json.dumps(data, ensure_ascii=False, separators=(",", ":"))}
