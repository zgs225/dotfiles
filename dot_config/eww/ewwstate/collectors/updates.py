"""Updates collector — EventCollector via inotifywait.

Replaces three deflisten scripts (update-listen-checking.sh,
update-listen-updates.sh, update-listen-list.sh) with a single
EventCollector that watches ``~/.cache/eww/`` for file changes and
derives all three topics:

* updates_checking — "true"/"false" based on existence of updates.checking
* updates          — JSON from updates.json (or default)
* update_list      — yuck-literal rendered from updates.json, filtered by
                     the eww variable ``updates_filter`` (read via eww get)

Action scripts (check-updates.sh, update-trigger.sh, update-apply.sh) are
**kept** — they are referenced by onclick handlers.
"""
from __future__ import annotations

import asyncio
import json
import os
from typing import Optional

from framework import EventCollector, collector
from util import run, shell

_CACHE_DIR = os.path.expanduser("~/.cache/eww")
_CHECKING_FILE = os.path.join(_CACHE_DIR, "updates.checking")
_CACHE_FILE = os.path.join(_CACHE_DIR, "updates.json")
_REFRESH_FLAG = os.path.join(_CACHE_DIR, "update-list-refresh.flag")

_DEFAULT_UPDATES = json.dumps({
    "last_check": "Never", "total": 0,
    "official_count": 0, "aur_count": 0,
    "official": [], "aur": [], "error": None,
}, separators=(",", ":"))


def _esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def _source_icon(source: str) -> str:
    if source == "official":
        return "\uf303"  # Arch logo nerd font
    if source == "aur":
        return "\uf005"  # star
    return ""


def _source_class(source: str) -> str:
    return source if source in ("official", "aur") else "unknown"


def _render_update_list(cache_data: Optional[dict], filter_val: str) -> str:
    """Render the update list yuck-literal, matching update-listen-list.sh."""
    if not cache_data:
        return ('(box :class "update-empty" :orientation "v" '
                '(label :class "update-empty-text" :xalign 0.5 '
                ':text "暂无数据"))')

    # Validate filter
    if filter_val not in ("all", "official", "aur"):
        filter_val = "all"

    items: list[str] = []

    def _render_group(source: str) -> None:
        icon = _source_icon(source)
        css_class = _source_class(source)
        pkgs = cache_data.get(source, [])
        for pkg in pkgs:
            name = _esc(pkg.get("name", ""))
            old = _esc(pkg.get("old", ""))
            new = _esc(pkg.get("new", ""))
            items.append(
                '(box :class "update-list-item" :orientation "h" '
                ':space-evenly false :spacing 8'
                f'(label :class "update-source-badge {css_class}" '
                f':text "{icon}")'
                f'(label :class "update-pkg-name" :hexpand true :xalign 0 '
                f':text "{name}")'
                f'(label :class "update-pkg-version" :xalign 1 '
                f':text "{old} → {new}"))'
            )

    if filter_val == "all":
        _render_group("official")
        _render_group("aur")
    else:
        _render_group(filter_val)

    if not items:
        inner = ('(label :class "update-empty-text" :xalign 0.5 '
                 ':text "该分组无更新")')
    else:
        inner = "".join(items)

    return ('(scroll :vscroll true :hscroll false :vexpand true '
            ':class "update-list-scroll" '
            f'(box :class "update-list" :orientation "v" :spacing 4 {inner}))')


def _read_checking() -> str:
    return "true" if os.path.exists(_CHECKING_FILE) else "false"


def _read_updates_json() -> str:
    try:
        with open(_CACHE_FILE) as f:
            data = json.load(f)
        # Compact JSON (matches jq -c . in the old script)
        return json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    except (OSError, json.JSONDecodeError):
        return _DEFAULT_UPDATES


def _read_updates_data() -> Optional[dict]:
    try:
        with open(_CACHE_FILE) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


@collector
class Updates(EventCollector):
    name = "updates"
    topics = ("updates_checking", "updates", "update_list")

    async def run(self) -> None:
        os.makedirs(_CACHE_DIR, exist_ok=True)

        # Initial publish
        await self._publish_checking()
        await self._publish_updates()
        await self._publish_update_list()

        # Watch for changes
        while True:
            try:
                proc = await asyncio.create_subprocess_exec(
                    "inotifywait", "-mq",
                    "-e", "create,delete,modify,move,attrib",
                    _CACHE_DIR,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.DEVNULL,
                )
                assert proc.stdout is not None
                async for raw_line in proc.stdout:
                    line = raw_line.decode(errors="replace").rstrip()
                    parts = line.split()
                    if len(parts) < 3:
                        continue
                    filename = parts[-1]

                    if "updates.checking" in filename:
                        await self._publish_checking()
                    if "updates.json" in filename:
                        await self._publish_updates()
                        await self._publish_update_list()
                    if "update-list-refresh.flag" in filename:
                        await self._publish_update_list()

            except (FileNotFoundError, OSError):
                await asyncio.sleep(2)

    async def _publish_checking(self) -> None:
        await self.store.set("updates_checking", _read_checking())

    async def _publish_updates(self) -> None:
        await self.store.set("updates", _read_updates_json())

    async def _publish_update_list(self) -> None:
        # Read filter from eww (cross-variable dependency)
        filter_val = await run(["eww", "get", "updates_filter"], timeout=2.0)
        if not filter_val:
            filter_val = "all"
        data = _read_updates_data()
        yuck = _render_update_list(data, filter_val)
        await self.store.set("update_list", yuck)
