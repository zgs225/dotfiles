"""Fan/thermal profile collector (fan-profile status --json).

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

from framework import PollCollector, collector
from util import run

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
    interval = 3.0

    async def collect(self):
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
