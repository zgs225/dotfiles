"""Calendar events collector — replaces events.py.

Reads the SQLite event database (via caldb), expands recurrences for the
selected date, and publishes:

* ``events``          — yuck-literal ``(box :class "events-list" …)`` for the
                        calendar-popup's events column.  Backward-compatible
                        with the format the old events.py produced.
* ``cal_date_label``  — human-readable label for the selected date
                        (e.g. "今天 · 7月19日 周六" or "7月21日 周一").
* ``cal_has_events``  — "true"/"false" for gating UI elements.

The selected date is read from the eww variable ``cal_selected_date``
(set by the popup's nav buttons).  Empty → today.

Pure sqlite3 + Python datetime — zero subprocesses except one ``eww get``
for the selected date (same pattern as updates_filter in updates.py).
"""
from __future__ import annotations

import asyncio
import json
import logging
from datetime import date, datetime, timedelta

from framework import EventCollector, PollCollector, collector
from util import run

log = logging.getLogger("ewwstated")

_WEEKDAY_CN = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]


def _esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def _date_label(target: date) -> str:
    today = date.today()
    wd = _WEEKDAY_CN[target.weekday()]
    if target == today:
        return f"今天 · {target.month}月{target.day}日 {wd}"
    if target == today + timedelta(days=1):
        return f"明天 · {target.month}月{target.day}日 {wd}"
    if target == today - timedelta(days=1):
        return f"昨天 · {target.month}月{target.day}日 {wd}"
    return f"{target.month}月{target.day}日 {wd}"


def _build_yuck(items: list[dict]) -> str:
    """Build the events-list yuck-literal from caldb event dicts."""
    if not items:
        return ('(box :class "events-list" :orientation "v" '
                '(label :class "events-empty" :xalign 0 :text "暂无日程"))')

    rows: list[str] = []
    for item in items:
        title = _esc(item.get("title", ""))
        color = item.get("account_color", "blue")
        eid = item.get("id", 0)

        # Time line: "10:00 - 11:00" or "10:00" or "全天"
        ts = item.get("time_start", "")
        te = item.get("time_end", "")
        if ts and te:
            time_str = f"{ts} - {te}"
        elif ts:
            time_str = ts
        else:
            time_str = "全天"

        # Recurrence marker
        if item.get("is_recurring"):
            time_str += " \u21bb"  # ↻

        time_str = _esc(time_str)
        acct = _esc(item.get("account_name", ""))

        rows.append(
            '(box :class "event-item" :orientation "h" :spacing 8 '
            ':valign "center" :space-evenly false'
            f'(box :class "event-dot event-dot-{color}" :valign "center")'
            '(box :orientation "v" :spacing 1 :hexpand true :space-evenly false'
            f'(label :class "event-title" :xalign 0 :limit-width 28 '
            f':text "{title}")'
            '(box :orientation "h" :spacing 6 :space-evenly false'
            f'(label :class "event-time" :xalign 0 :text "{time_str}")'
            f'(label :class "event-acct" :xalign 0 :text "{acct}")))'
            f'(button :class "event-del-btn" :valign "center"'
            f' :onclick "~/.config/eww/scripts/cal-add-action.sh delete {eid}"'
            f' (label :text "✕" :class "event-del-icon")))'
        )

    return ('(box :class "events-list" :orientation "v" :spacing 6 '
            + "".join(rows) + ")")


@collector
class CalendarEvents(PollCollector):
    name = "calendar"
    topics = ("events", "cal_date_label", "cal_has_events")
    interval = 60.0

    async def collect(self):
        import sys, os
        # Ensure caldb/rrule are importable (they live alongside this file)
        ewwstate_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        if ewwstate_dir not in sys.path:
            sys.path.insert(0, ewwstate_dir)

        import caldb

        # Read selected date from eww (empty = today)
        raw = await run(["eww", "get", "cal_selected_date"], timeout=2.0)
        raw = raw.strip()
        today = date.today()
        if raw:
            try:
                target = date.fromisoformat(raw)
            except ValueError:
                target = today
        else:
            target = today

        # Ensure DB exists (lazy init for first run)
        caldb.ensure_db()

        items = caldb.events_for_date(target)
        label = _date_label(target)
        has = "true" if items else "false"

        return {
            "events": _build_yuck(items),
            "cal_date_label": label,
            "cal_has_events": has,
        }


# ── Notification EventCollector ──────────────────────────────────────────

_NOTIF_SCAN_INTERVAL = 30.0  # seconds between scans


@collector
class CalendarNotify(EventCollector):
    """Scan for upcoming events and fire dunstify notifications.

    Every 30 seconds, checks the DB for events whose remind_minutes window
    covers 'now'.  Tracks already-notified (event_id, date) pairs in memory
    to avoid duplicates.  Respects DND (dunstctl is-paused).
    """

    name = "calendar_notify"
    topics = ()  # no eww topics — side-effect only (dunstify)

    async def run(self) -> None:
        import sys, os
        ewwstate_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        if ewwstate_dir not in sys.path:
            sys.path.insert(0, ewwstate_dir)

        import caldb
        caldb.ensure_db()

        notified: set[tuple[int, str]] = set()  # (event_id, date_str)

        while True:
            try:
                # Check DND
                dnd_raw = await run(["dunstctl", "is-paused"], timeout=3.0)
                is_dnd = dnd_raw.strip().lower() == "true"

                if not is_dnd:
                    upcoming = caldb.upcoming_events(minutes_ahead=60)
                    for ev in upcoming:
                        key = (ev["id"], date.today().isoformat())
                        if key in notified:
                            continue
                        notified.add(key)

                        # Build notification
                        title = ev["title"]
                        ts = ev.get("time_start", "")
                        te = ev.get("time_end", "")
                        if ts and te:
                            time_str = f"{ts} - {te}"
                        elif ts:
                            time_str = ts
                        else:
                            time_str = "全天"

                        mins = ev.get("minutes_until", 0)
                        if mins > 0:
                            body = f"{time_str} · {mins} 分钟后"
                        else:
                            body = f"{time_str} · 现在开始"

                        acct = ev.get("account_name", "")
                        if acct:
                            body += f"  [{acct}]"

                        # Use event_id as notification id so repeated
                        # reminders for the same event replace each other.
                        nid = 9000 + ev["id"]  # offset to avoid collisions
                        await run([
                            "dunstify",
                            "-a", "eww-calendar",
                            "-i", "x-office-calendar",
                            "-u", "normal",
                            "-r", str(nid),
                            "-t", "15000",  # 15s timeout
                            title,
                            body,
                        ], timeout=5.0)

                        log.info("calendar_notify: fired #%d '%s' (%s)",
                                 ev["id"], title, body)

                # Prune old entries (keep only today's)
                today_str = date.today().isoformat()
                notified = {k for k in notified if k[1] == today_str}

            except asyncio.CancelledError:
                raise
            except Exception:
                log.exception("calendar_notify: scan failed")

            await asyncio.sleep(_NOTIF_SCAN_INTERVAL)
