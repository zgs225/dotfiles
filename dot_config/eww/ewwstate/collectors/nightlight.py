"""Night-light collector.

Replaces night-light-on.sh, which shell'd out to ``pgrep -x`` twice per poll.
Reports whether a night-light process (redshift or gammastep) is running as the
eww boolean string ``"true"`` / ``"false"`` — exactly what the legacy script
printed, so the control-center quick button's ``${night_light == 'true' ...}``
needs no change.
"""
from __future__ import annotations

from framework import PollCollector, collector
from util import running


@collector
class NightLight(PollCollector):
    name = "nightlight"
    topics = ("night_light",)
    interval = 3.0

    async def collect(self):
        on = await running("redshift", "gammastep")
        return {"night_light": "true" if on else "false"}
