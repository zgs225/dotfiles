"""Media player collector.

Replaces the defpoll that shelled out to ``media.sh`` (three playerctl calls
per poll). Uses ``playerctl metadata --format`` to fetch status+title+artist
in a single subprocess, then builds the same JSON the legacy script emitted::

    {"has":true,"title":"…","artist":"…","status":"Playing","icon":"󰏤"}

The idle placeholder (no player / Stopped) is::

    {"has":false,"title":"暂无媒体","artist":"无媒体源","status":"Stopped","icon":"\\u200b"}

``media.sh`` itself is **kept** because ``media-ctl.sh`` calls it for
optimistic updates on button press.
"""
from __future__ import annotations

import json

from framework import PollCollector, collector
from util import run

_IDLE = json.dumps(
    {"has": False, "title": "暂无媒体", "artist": "无媒体源",
     "status": "Stopped", "icon": "\u200b"},
    ensure_ascii=False,
)


@collector
class Media(PollCollector):
    name = "media"
    topics = ("media",)
    interval = 2.0

    async def collect(self):
        # Single playerctl call: status\ttitle\tartist
        raw = await run(
            ["playerctl", "metadata", "--format",
             "{{status}}\t{{title}}\t{{artist}}"],
            timeout=3.0,
        )
        if not raw:
            return {"media": _IDLE}

        parts = raw.split("\t", 2)
        status = parts[0].strip() if len(parts) > 0 else ""
        if not status or status == "Stopped":
            return {"media": _IDLE}

        title = parts[1].strip() if len(parts) > 1 else ""
        artist = parts[2].strip() if len(parts) > 2 else ""

        icon = "\U000f03e4" if status == "Playing" else "\U000f040a"  # 󰏤 / 󰐊

        return {"media": json.dumps(
            {"has": True,
             "title": title or "未知",
             "artist": artist or "未知",
             "status": status,
             "icon": icon},
            ensure_ascii=False,
        )}
