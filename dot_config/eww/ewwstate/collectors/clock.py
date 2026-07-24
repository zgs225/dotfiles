"""Clock + calendar collector.

Replaces shichen.sh (the traditional double-hour + civil time) and the three
inline ``date`` defpolls for the calendar hero (monthday / month / year). Pure
Python datetime — no subprocesses at all, so this collector costs essentially
nothing and never spawns a fork storm on its 10s tick.

The shichen mapping is reproduced exactly from the legacy script:
  names = 子丑寅卯辰巳午未申酉戌亥
  idx   = ((hour + 1) // 2) % 12
so 23:00–00:59 -> 子, 01:00–02:59 -> 丑, …, 15:00–16:59 -> 申, etc.
"""
from __future__ import annotations

from datetime import datetime

from framework import PollCollector, collector

_STEMS = ("子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥")


def shichen(hour: int, minute: int) -> str:
    """Return e.g. ``申时 · 15:05`` for the given wall-clock hour/minute."""
    idx = ((hour + 1) // 2) % 12
    return f"{_STEMS[idx]}时 · {hour:02d}:{minute:02d}"


def calendar_fields(now: datetime) -> dict[str, str]:
    """Monthday / month / year without leading zeros (matches ``date +%-d`` etc.)."""
    return {
        "calendar_monthday": str(now.day),
        "calendar_month": str(now.month),
        "calendar_year": f"{now.year:04d}",
    }


@collector
class Clock(PollCollector):
    name = "clock"
    topics = ("clock_time", "calendar_monthday", "calendar_month", "calendar_year")
    interval = 10.0

    async def collect(self):
        now = datetime.now()
        out = {"clock_time": shichen(now.hour, now.minute)}
        out.update(calendar_fields(now))
        return out
