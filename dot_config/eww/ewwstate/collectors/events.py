"""Events collector.

Replaces events.sh. Reads ``~/.config/eww/events.json`` (a JSON array of
``{title, time, color}`` objects) and renders it into a yuck-literal
``(box :class "events-list" …)`` for the calendar-popup's events column.

Pure file I/O + string building — zero subprocesses.
"""
from __future__ import annotations

import json
import os

from framework import PollCollector, collector

_CONF = os.path.expanduser("~/.config/eww/events.json")
_EMPTY = ('(box :orientation "v" '
          '(label :class "events-empty" :xalign 0 :text "暂无日程"))')


def _esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def _build_yuck(items: list[dict]) -> str:
    if not items:
        return ('(box :class "events-list" :orientation "v" :spacing 10 '
                '(label :class "events-empty" :xalign 0 :text "暂无日程"))')

    rows: list[str] = []
    for item in items:
        title = _esc(item.get("title", ""))
        time  = _esc(item.get("time", ""))
        color = item.get("color", "blue")
        rows.append(
            '(box :class "event-item" :orientation "h" :spacing 8 '
            ':valign "start" :space-evenly false'
            f'(box :class "event-dot event-dot-{color}" :valign "center")'
            '(box :orientation "v" :spacing 1 :hexpand true :space-evenly false'
            f'(label :class "event-title" :xalign 0 :limit-width 18 '
            f':text "{title}")'
            f'(label :class "event-time" :xalign 0 :text "{time}")))'
        )

    return ('(box :class "events-list" :orientation "v" :spacing 10 '
            + "".join(rows) + ")")


@collector
class Events(PollCollector):
    name = "events"
    topics = ("events",)
    interval = 60.0

    async def collect(self):
        try:
            with open(_CONF) as f:
                items = json.load(f)
            if not isinstance(items, list):
                items = []
        except (OSError, json.JSONDecodeError):
            return {"events": _EMPTY}

        return {"events": _build_yuck(items)}
