"""Async helpers for collectors.

Everything a collector needs to touch the outside world without ever blocking
the event loop: async subprocess wrappers and sysfs readers.
"""
from __future__ import annotations

import asyncio
import glob
from typing import Optional


async def run(cmd: list[str], timeout: Optional[float] = 5.0) -> str:
    """Run ``cmd`` asynchronously; return stripped stdout ('' on any failure)."""
    proc = None
    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        out, _ = await asyncio.wait_for(proc.communicate(), timeout)
        return out.decode(errors="replace").strip()
    except (FileNotFoundError, asyncio.TimeoutError, OSError):
        if proc is not None:
            try:
                proc.kill()
            except ProcessLookupError:
                pass
        return ""


async def shell(cmd: str, timeout: Optional[float] = 5.0) -> str:
    """Like :func:`run` but through ``/bin/sh -c`` (for pipelines / jq)."""
    proc = None
    try:
        proc = await asyncio.create_subprocess_shell(
            cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
        )
        out, _ = await asyncio.wait_for(proc.communicate(), timeout)
        return out.decode(errors="replace").strip()
    except (asyncio.TimeoutError, OSError):
        if proc is not None:
            try:
                proc.kill()
            except ProcessLookupError:
                pass
        return ""


def read_sysfs(path: str, default: str = "") -> str:
    """Read a single sysfs/procfs attribute, stripped ('' safe on failure)."""
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def sysfs_glob(pattern: str) -> list[str]:
    """Sorted glob over sysfs paths (e.g. ``/sys/class/power_supply/BAT*``)."""
    return sorted(glob.glob(pattern))


async def running(*names: str, timeout: float = 3.0) -> bool:
    """True if any exact process name is alive (async equivalent of
    ``pgrep -x <name>``). Uses the exit code, not stdout — pgrep prints
    nothing on a match, so :func:`run` cannot express this."""
    for name in names:
        proc = None
        try:
            proc = await asyncio.create_subprocess_exec(
                "pgrep", "-x", name,
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )
            rc = await asyncio.wait_for(proc.wait(), timeout)
            if rc == 0:
                return True
        except (FileNotFoundError, asyncio.TimeoutError, OSError):
            if proc is not None:
                try:
                    proc.kill()
                except ProcessLookupError:
                    pass
    return False
