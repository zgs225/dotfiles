"""Collector framework for the eww state daemon.

A *collector* publishes one or more *topics* into the shared StateStore. Two
flavours exist:

* ``PollCollector``  — recomputes its topics on a fixed ``interval``. Implement
  ``async collect() -> {topic: value}``.
* ``EventCollector`` — a long-running task driven by an external event source
  (a ``pactl subscribe`` stream, the i3 ipc socket, inotify, a D-Bus signal…).
  Implement ``async run()`` as an infinite loop that pushes updates with
  ``await self.store.set(topic, value)``.

Registration is a class decorator; the daemon auto-discovers every module in
the ``collectors/`` package at startup, so adding a collector is just dropping
a new file in that directory::

    from framework import PollCollector, collector

    @collector
    class Battery(PollCollector):
        name = "battery"
        topics = ("battery_percent",)
        interval = 5.0
        async def collect(self):
            return {"battery_percent": "87"}

Conventions that keep migration a pure command swap in common.yuck:

* A topic name is identical to the eww variable it feeds.
* The published value is exactly the string the legacy shell script printed
  (scalar / JSON / yuck-literal), so yuck logic never has to change.

Collectors MUST be non-blocking: shell out via ``util.run()`` / ``util.shell()``
(async subprocesses), never ``subprocess.run()``.
"""
from __future__ import annotations

import abc
from typing import Any, Optional

from store import StateStore


class Collector(abc.ABC):
    """Base class for all collectors."""

    #: unique id used in logs and by `ewwstate refresh <name>`
    name: str = ""
    #: topics this collector publishes (documentation + routing)
    topics: tuple[str, ...] = ()

    def __init__(self, store: StateStore):
        self.store = store

    async def setup(self) -> None:
        """Optional one-time initialisation (called once before running)."""

    async def teardown(self) -> None:
        """Optional cleanup (called when the collector task ends)."""


class PollCollector(Collector):
    """Recomputes its topics every ``interval`` seconds."""

    interval: float = 5.0
    #: delay before the very first collection (lets the daemon settle)
    initial_delay: float = 0.0

    @abc.abstractmethod
    async def collect(self) -> Optional[dict[str, Any]]:
        """Return ``{topic: value}`` (or None to publish nothing this round)."""


class EventCollector(Collector):
    """Long-running collector driven by an external event source."""

    @abc.abstractmethod
    async def run(self) -> None:
        """Await events forever; push updates via ``self.store.set``."""


# --------------------------------------------------------------------------
# Registry
# --------------------------------------------------------------------------
_REGISTRY: list[type[Collector]] = []


def collector(cls: type[Collector]) -> type[Collector]:
    """Class decorator: register a collector for auto-instantiation."""
    if not cls.name:
        cls.name = cls.__name__.lower()
    _REGISTRY.append(cls)
    return cls


def registered() -> list[type[Collector]]:
    return list(_REGISTRY)
