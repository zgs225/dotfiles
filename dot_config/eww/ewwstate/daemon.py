"""The daemon core: discover collectors and run each as a supervised task.

Every collector runs in its own asyncio task. A crash is contained — the
supervisor restarts that one collector with exponential backoff while all the
others keep running. Collection latency is isolated per collector, and none of
it can block the store's read path.
"""
from __future__ import annotations

import asyncio
import importlib
import logging
import pkgutil
import time

from framework import Collector, EventCollector, PollCollector, registered
from store import StateStore

log = logging.getLogger("ewwstated")


def discover_collectors() -> None:
    """Import every module in the ``collectors/`` package.

    Importing runs each module's ``@collector`` decorators, populating the
    registry. Auto-discovery means a new collector needs no wiring elsewhere.
    """
    import collectors as pkg

    for mod in pkgutil.iter_modules(pkg.__path__):
        importlib.import_module(f"collectors.{mod.name}")


async def _run_poll(coll: PollCollector) -> None:
    if coll.initial_delay:
        await asyncio.sleep(coll.initial_delay)
    while True:
        t0 = time.monotonic()
        try:
            result = await coll.collect()
            for topic, value in (result or {}).items():
                await coll.store.set(topic, value)
        except asyncio.CancelledError:
            raise
        except Exception:
            log.exception("collector %r: collect() failed", coll.name)
        # Sleep for the remainder of the interval (floor avoids a hot loop if a
        # collection overruns its interval).
        elapsed = time.monotonic() - t0
        await asyncio.sleep(max(0.05, coll.interval - elapsed))


async def _run_event(coll: EventCollector) -> None:
    await coll.run()


async def _supervised(coll: Collector) -> None:
    """Run one collector forever, restarting it on crash with backoff."""
    backoff = 1.0
    while True:
        try:
            await coll.setup()
            if isinstance(coll, PollCollector):
                await _run_poll(coll)
            elif isinstance(coll, EventCollector):
                await _run_event(coll)
            else:
                log.error("collector %r is neither Poll nor Event; dropping", coll.name)
                return
        except asyncio.CancelledError:
            raise
        except Exception:
            log.exception(
                "collector %r crashed; restarting in %.1fs", coll.name, backoff
            )
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, 30.0)
        finally:
            try:
                await coll.teardown()
            except Exception:
                log.exception("collector %r: teardown() failed", coll.name)


async def serve(statedir: str) -> None:
    store = StateStore(statedir)
    discover_collectors()
    colls = [cls(store) for cls in registered()]
    log.info(
        "starting %d collector(s): %s",
        len(colls),
        ", ".join(c.name for c in colls) or "<none>",
    )
    tasks = [asyncio.create_task(_supervised(c), name=c.name) for c in colls]
    try:
        await asyncio.gather(*tasks)
    finally:
        for t in tasks:
            t.cancel()
