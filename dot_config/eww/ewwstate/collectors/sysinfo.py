"""System-info collector (profile card).

Replaces sysinfo.sh. Emits the same JSON object consumed by profile-card.yuck
as ``sysinfo.<field>``:

  {host, uptime, cpu, mem_used, mem_total, mem_pct, disk_used, disk_total,
   disk_pct, temp, temp_pct}

The legacy script sampled /proc/stat with a *blocking* ``sleep 0.25`` and ran
free/df/sensors/hostnamectl serially — every 3s poll held a process for a
quarter second plus the serial subprocesses. Here the CPU sample uses a
non-blocking ``asyncio.sleep`` and the four external commands run concurrently
via ``asyncio.gather``, so the whole collection yields the event loop the
entire time.

Pure-Python reads: /proc/uptime, /proc/stat. Subprocesses (concurrent):
hostnamectl, free, df, sensors (with a /sys thermal fallback).
"""
from __future__ import annotations

import asyncio
import re

from framework import PollCollector, collector
from util import read_sysfs, run


def _hkib(k: int) -> str:
    g = k / 1048576
    return f"{g:.1f}G" if g >= 1 else f"{k // 1024}M"


def _uptime_str(up_s: int) -> str:
    d, rem = divmod(up_s, 86400)
    h, rem = divmod(rem, 3600)
    m = rem // 60
    if d > 0:
        return f"{d}d {h}h"
    if h > 0:
        return f"{h}h {m}m"
    return f"{m}m"


def _cpu_from_stat(line: str) -> tuple[int, int]:
    """Return (total, idle) jiffies from a ``cpu ...`` /proc/stat line."""
    fields = list(map(int, line.split()[1:]))
    return sum(fields), fields[3]


def _parse_free(text: str) -> tuple[int, int]:
    """(used_kb, total_kb) from ``free -k`` output (Mem: row, cols 3 & 2)."""
    for line in text.splitlines():
        if line.startswith("Mem:"):
            parts = line.split()
            return int(parts[2]), int(parts[1])
    return 0, 0


def _parse_df(text: str) -> tuple[str, str, int]:
    """(used, size, pct) from ``df -h --output=used,size,pcent /`` row 2."""
    lines = [l for l in text.splitlines() if l.strip()]
    if len(lines) >= 2:
        parts = lines[1].split()
        if len(parts) >= 3:
            return parts[0], parts[1], int(parts[2].replace("%", "") or 0)
    return "0", "0", 0


_TEMP_RE = re.compile(r"Package id 0:|Tctl:|Tdie:")


def _parse_sensors(text: str) -> int | None:
    for line in text.splitlines():
        if _TEMP_RE.search(line):
            # awk -F'[+.]' '{print $2}' on e.g. "  +44.0°C  ..."
            parts = re.split(r"[+.]", line)
            if len(parts) >= 2:
                try:
                    return int(parts[1])
                except ValueError:
                    return None
    return None


@collector
class Sysinfo(PollCollector):
    name = "sysinfo"
    topics = ("sysinfo",)
    interval = 3.0

    async def collect(self):
        # --- CPU sample: two /proc/stat reads around a non-blocking sleep ---
        with open("/proc/stat") as f:
            line_a = f.readline()
        total_a, idle_a = _cpu_from_stat(line_a)
        await asyncio.sleep(0.25)
        with open("/proc/stat") as f:
            line_b = f.readline()
        total_b, idle_b = _cpu_from_stat(line_b)
        dt = total_b - total_a
        di = idle_b - idle_a
        cpu = (100 * (dt - di) // dt) if dt > 0 else 0
        cpu = max(0, min(100, cpu))

        # --- uptime (pure) ---
        up_raw = read_sysfs("/proc/uptime", "0").split()[0]
        try:
            up_s = int(float(up_raw))
        except ValueError:
            up_s = 0

        # --- concurrent external commands ---
        host_raw, free_raw, df_raw, sensors_raw = await asyncio.gather(
            run(["hostnamectl", "hostname"], timeout=3.0),
            run(["free", "-k"], timeout=3.0),
            run(["df", "-h", "--output=used,size,pcent", "/"], timeout=3.0),
            run(["sensors"], timeout=3.0),
        )

        if host_raw:
            host = host_raw
        else:
            host = read_sysfs("/etc/hostname", "linux") or "linux"

        mem_used_kb, mem_total_kb = _parse_free(free_raw)
        mem_pct = (100 * mem_used_kb // mem_total_kb) if mem_total_kb > 0 else 0
        mem_used, mem_total = _hkib(mem_used_kb), _hkib(mem_total_kb)

        disk_used, disk_total, disk_pct = _parse_df(df_raw)

        temp = _parse_sensors(sensors_raw)
        if temp is None:
            t = read_sysfs("/sys/class/thermal/thermal_zone0/temp", "0")
            try:
                temp = int(t) // 1000
            except ValueError:
                temp = 0
        temp_pct = min(100, temp)

        json = (
            '{"host":"%s","uptime":"%s","cpu":%d,"mem_used":"%s","mem_total":"%s",'
            '"mem_pct":%d,"disk_used":"%s","disk_total":"%s","disk_pct":%d,'
            '"temp":%d,"temp_pct":%d}'
            % (
                host, _uptime_str(up_s), cpu, mem_used, mem_total, mem_pct,
                disk_used, disk_total, disk_pct, temp, temp_pct,
            )
        )
        return {"sysinfo": json}
