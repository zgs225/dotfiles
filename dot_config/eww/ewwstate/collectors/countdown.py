"""Countdown collector.

Replaces countdown.sh. Reads an optional user target from
``~/.config/eww/countdown.txt`` (``YYYY-MM-DD|Label``); falls back to
counting down to the upcoming Saturday.

Emits JSON: ``{"label":"…","sub":"还有 N 天"}`` or ``{"label":"周末","sub":"已到"}``.
"""
from __future__ import annotations

import json
import os
from datetime import date, datetime

from framework import PollCollector, collector

_CONF = os.path.expanduser("~/.config/eww/countdown.txt")


@collector
class Countdown(PollCollector):
    name = "countdown"
    topics = ("countdown",)
    interval = 1800.0  # 30 min

    async def collect(self):
        # Check user config
        try:
            with open(_CONF) as f:
                line = f.readline().strip()
            if "|" in line:
                target_str, label = line.split("|", 1)
                target = datetime.strptime(target_str.strip(), "%Y-%m-%d").date()
                days = (target - date.today()).days
                if days < 0:
                    days = 0
                return {"countdown": json.dumps(
                    {"label": label or "倒计时", "sub": f"还有 {days} 天"},
                    ensure_ascii=False,
                )}
        except (OSError, ValueError):
            pass

        # Fallback: count to Saturday (weekday 5 in Python's 0=Mon)
        today = date.today()
        dow = today.weekday()  # 0=Mon .. 6=Sun
        if dow >= 5:  # Sat or Sun
            return {"countdown": json.dumps(
                {"label": "周末", "sub": "已到"}, ensure_ascii=False)}
        else:
            days = 5 - dow  # days until Saturday
            return {"countdown": json.dumps(
                {"label": "周末", "sub": f"还有 {days} 天"}, ensure_ascii=False)}
