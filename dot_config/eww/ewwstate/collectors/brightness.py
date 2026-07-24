"""Brightness collector.

Replaces the inline defpoll that shelled out to ``brightnessctl info`` (plus a
grep/tr pipeline) every 2s. Reads sysfs directly — zero subprocesses. The
percentage is ``cur * 100 // max``, exactly the integer ``brightnessctl``
prints in its ``(NN%)`` field, so the control-center slider's
``${brightness}%`` / ``:value "${brightness}"`` needs no change.
"""
from __future__ import annotations

from framework import PollCollector, collector
from util import read_sysfs, sysfs_glob


@collector
class Brightness(PollCollector):
    name = "brightness"
    topics = ("brightness",)
    interval = 2.0

    async def collect(self):
        for dev in sysfs_glob("/sys/class/backlight/*"):
            cur = read_sysfs(f"{dev}/brightness")
            max_ = read_sysfs(f"{dev}/max_brightness")
            if cur.isdigit() and max_.isdigit() and int(max_) > 0:
                return {"brightness": str(int(cur) * 100 // int(max_))}
        return {"brightness": "0"}
