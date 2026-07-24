"""Airplane-mode collector.

Replaces the defpoll of airplane-on.sh. Airplane mode is "on" (``"1"``) only
when rfkill reports no radio with ``Soft blocked: no`` — i.e. every radio is
soft-blocked. An empty rfkill listing (no radios) is treated as off, matching
the legacy script.

The legacy script is *kept* for the onclick optimistic update in
toggle-airplane.sh (instant feedback after rfkill block/unblock); only the
polling path moves here.
"""
from __future__ import annotations

from framework import PollCollector, collector
from util import run


@collector
class Airplane(PollCollector):
    name = "airplane"
    topics = ("airplane_on",)
    interval = 5.0

    async def collect(self):
        out = await run(["rfkill", "list"], timeout=3.0)
        if not out:
            return {"airplane_on": "0"}
        on = "0" if "Soft blocked: no" in out else "1"
        return {"airplane_on": on}
