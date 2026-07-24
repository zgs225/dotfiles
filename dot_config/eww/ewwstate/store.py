"""The shared state store: in-memory cache + atomic tmpfs file mirror.

This is the decoupling point between collection and retrieval:

* ``set()``  — called by collectors. Updates memory and, only when the value
  actually changed, atomically writes ``<statedir>/<topic>`` and notifies
  in-daemon subscribers.
* ``get()``  — a pure dict read. It NEVER collects and NEVER blocks, so a slow
  or stuck collector can never delay a read.

The file mirror means retrieval (``ewwstate get`` = ``cat`` a file) does not
even need the daemon to be alive: the last collected value persists.
"""
from __future__ import annotations

import asyncio
import os
import tempfile
from typing import Any, Optional


class StateStore:
    def __init__(self, statedir: str):
        self.statedir = statedir
        os.makedirs(statedir, exist_ok=True)
        self._data: dict[str, str] = {}
        self._version: dict[str, int] = {}
        self._subs: dict[str, list[asyncio.Queue]] = {}
        self._lock = asyncio.Lock()

    # ---- retrieval (non-blocking) ---------------------------------------
    def get(self, topic: str) -> Optional[str]:
        return self._data.get(topic)

    def snapshot(self) -> dict[str, Any]:
        return {
            topic: {"value": value, "version": self._version.get(topic, 0)}
            for topic, value in self._data.items()
        }

    # ---- collection ------------------------------------------------------
    async def set(self, topic: str, value: Any) -> None:
        value = "" if value is None else str(value)
        async with self._lock:
            if self._data.get(topic) == value:
                return  # unchanged: skip persist + notify
            self._data[topic] = value
            self._version[topic] = self._version.get(topic, 0) + 1
        await self._persist(topic, value)
        for q in list(self._subs.get(topic, ())):
            q.put_nowait(value)

    async def _persist(self, topic: str, value: str) -> None:
        # Atomic: write a temp file in the same directory, then rename over the
        # target. Same filesystem => rename is atomic, so a reader never sees a
        # partially-written value.
        path = os.path.join(self.statedir, topic)
        fd, tmp = tempfile.mkstemp(dir=self.statedir, prefix=f".{topic}.")
        try:
            with os.fdopen(fd, "w") as f:
                f.write(value)
                if not value.endswith("\n"):
                    f.write("\n")
            os.replace(tmp, path)
        except Exception:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise

    # ---- in-daemon subscriptions (for a future push/control socket) -------
    def subscribe(self, topic: str) -> asyncio.Queue:
        q: asyncio.Queue = asyncio.Queue()
        self._subs.setdefault(topic, []).append(q)
        return q

    def unsubscribe(self, topic: str, q: asyncio.Queue) -> None:
        subs = self._subs.get(topic)
        if subs and q in subs:
            subs.remove(q)
