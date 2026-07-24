"""Notification collector — notif_count, notifications, dnd.

Replaces three separate defpolls (notif-count.sh, notif-yuck.sh, inline
dunstctl is-paused) with a single collector that calls dunstctl once per
poll cycle and derives all three topics from the results.

* notif_count  — integer string, badge on the bar bell icon.
* notifications — yuck-literal (box …) for the notification-popup literal widget.
* dnd          — "true"/"false" string for the DND toggle tile.

notif-count.sh and notif-yuck.sh are **deleted** after migration (no onclick
references).  toggle-dnd.sh calls dunstctl directly for optimistic updates
and is kept.
"""
from __future__ import annotations

import json
import re

from framework import PollCollector, collector
from util import run, shell

# ── app-name → (nerd-font glyph, css-class) ──────────────────────────────
_APP_MAP: list[tuple[str, str, str]] = [
    ("slack",     "\U000f04b1", "slack"),
    ("telegram",  "\U000f0517", "telegram"),
    ("github",    "\U000f02a4", "github"),
    ("git",       "\U000f02a4", "github"),
    ("discord",   "\U000f066f", "discord"),
    ("spotify",   "\U000f04c7", "spotify"),
    ("music",     "\U000f04c7", "spotify"),
    ("firefox",   "\U000f0239", "web"),
    ("chrom",     "\U000f0239", "web"),
    ("mail",      "\U000f01ee", "mail"),
    ("thunder",   "\U000f01ee", "mail"),
    ("volume",    "\U000f057e", "sys"),
    ("audio",     "\U000f057e", "sys"),
    ("update",    "\U000f06b0", "sys"),
    ("pacman",    "\U000f06b0", "sys"),
    ("screenshot","\U000f0e51", "sys"),
    ("maim",      "\U000f0e51", "sys"),
]
_DEFAULT_ICON = ("\U000f009a", "sys")  # 󰂚


def _app_icon(appname: str) -> tuple[str, str]:
    low = appname.lower()
    for needle, glyph, cls in _APP_MAP:
        if needle in low:
            return glyph, cls
    return _DEFAULT_ICON


def _esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def _age_str(age_s: int) -> str:
    if age_s < 0:
        age_s = 0
    if age_s < 60:
        return "刚刚"
    if age_s < 3600:
        return f"{age_s // 60} 分钟前"
    if age_s < 86400:
        return f"{age_s // 3600} 小时前"
    return f"{age_s // 86400} 天前"


def _build_notif_yuck(history_json: str, uptime_s: int) -> str:
    """Parse dunstctl history JSON → yuck-literal string."""
    try:
        data = json.loads(history_json)
        items_raw = data.get("data", [[]])[0]
    except (json.JSONDecodeError, IndexError, TypeError):
        items_raw = []

    if not items_raw:
        return ('(box :class "notif-scroll" :orientation "v" '
                '(label :class "notif-empty" :xalign 0.5 :valign "center" '
                ':text "暂无通知"))')

    parts: list[str] = []
    for row in items_raw:
        appname = (row.get("appname") or {}).get("data", "dunst") or "dunst"
        # bash $(…) strips trailing newlines; replicate that.
        summary = ((row.get("summary") or {}).get("data", "") or "").rstrip("\n")
        body    = ((row.get("body")    or {}).get("data", "") or "").rstrip("\n")
        ts_us   = (row.get("timestamp") or {}).get("data", 0) or 0

        age = uptime_s - ts_us // 1_000_000
        ago = _age_str(age)

        glyph, cls = _app_icon(appname)

        e_sum  = _esc(summary)
        e_body = _esc(body)
        e_ago  = _esc(ago)

        item = (
            '(box :class "notif-item" :orientation "h" :spacing 12 '
            ':valign "start" :space-evenly false'
            f'(box :class "notif-appicon icon-{cls}" :valign "start" '
            f':halign "center" (label :text "{glyph}"))'
            '(box :orientation "v" :spacing 2 :hexpand true :space-evenly false'
            '(box :orientation "h" :space-evenly false'
            f'(label :class "notif-title" :xalign 0 :hexpand true '
            f':limit-width 26 :text "{e_sum}")'
            f'(label :class "notif-time" :xalign 1 :text "{e_ago}"))'
        )
        if e_body:
            item += (f'(label :class "notif-body" :xalign 0 :wrap true '
                     f':limit-width 40 :text "{e_body}")')
        item += "))"
        parts.append(item)

    return ('(box :class "notif-scroll" :orientation "v" :spacing 4 '
            ':space-evenly false ' + "".join(parts) + ")")


@collector
class Notifications(PollCollector):
    name = "notifications"
    topics = ("notif_count", "notifications", "dnd")
    interval = 2.0

    async def collect(self):
        # Fetch all three data sources concurrently
        import asyncio
        count_raw, hist_raw, dnd_raw, uptime_raw = await asyncio.gather(
            run(["dunstctl", "count", "history"], timeout=3.0),
            run(["dunstctl", "history"], timeout=5.0),
            run(["dunstctl", "is-paused"], timeout=3.0),
            shell("awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0",
                  timeout=2.0),
        )

        # notif_count
        try:
            notif_count = str(int(count_raw)) if count_raw.isdigit() else "0"
        except ValueError:
            notif_count = "0"

        # dnd
        dnd = "true" if dnd_raw.strip().lower() == "true" else "false"

        # uptime
        try:
            uptime_s = int(uptime_raw) if uptime_raw.isdigit() else 0
        except ValueError:
            uptime_s = 0

        # notifications yuck-literal
        notifications = _build_notif_yuck(hist_raw, uptime_s)

        return {
            "notif_count": notif_count,
            "notifications": notifications,
            "dnd": dnd,
        }
