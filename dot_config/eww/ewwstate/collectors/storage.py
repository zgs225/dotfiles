"""Storage collector -- monitors mounted removable devices.

Publishes:
* ``storage_devices`` -- JSON array of mounted removable devices, consumed by
  the storage-popup ``(for dev in storage_devices ...)`` loop.  Each element
  carries its own icon glyphs (``icon`` / ``eject_icon`` / ``open_icon``) so
  the yuck template never has to hard-code a Private-Use-Area code point.
* ``storage_count``   -- integer string for the bar badge / ``:visible`` gate.
* ``storage_icon``    -- the bar USB glyph (also injected, never typed in yuck).

Data sources (all zero-fork, pure file reads + one ``os.statvfs``):

* ``/proc/mounts``                -- mount entries under ``/run/media/$USER/``
* ``/sys/class/block/<dev>``      -- resolve partition -> parent disk
* ``/sys/block/<disk>/removable`` -- removable flag (``1``)
* ``/sys/block/<disk>/device/``   -- vendor / model strings
* ``os.statvfs(mountpoint)``      -- capacity / usage

The collector is read-only: it never mounts, unmounts, or touches udev.
Mounting is thunar-volman's job; unmounting is the user-initiated
``storage-eject.sh`` script's job.

Icon code points are resolved once from the Nerd Font cmap via fonttools and
hard-pinned here as ``chr()`` literals -- never guess PUA values in yuck.
"""
from __future__ import annotations

import json
import os
from typing import Optional

from framework import PollCollector, collector
from util import read_sysfs

_USER = os.environ.get("USER", "")
_MEDIA_PREFIX = f"/run/media/{_USER}/"

# Nerd Font (md-*) glyphs, pinned from fontTools cmap dump.  Injected into the
# JSON so the yuck template stays free of hand-typed PUA characters.
_USB = chr(0xF0553)     # md-usb            -- device + bar icon
_EJECT = chr(0xF01EA)   # md-eject          -- safe-remove button
_OPEN = chr(0xF0770)    # md-folder_open    -- open-in-Thunar button


def _parent_disk(part_name: str) -> str:
    """Resolve a partition kernel name to its parent disk.

    ``sdb1`` -> ``sdb``, ``nvme0n1p1`` -> ``nvme0n1``.
    Uses the sysfs symlink: ``/sys/class/block/sdb1`` ->
    ``/sys/devices/.../sdb/sdb1``, so ``dirname(realpath)`` is the parent.
    """
    try:
        real = os.path.realpath(f"/sys/class/block/{part_name}")
        return os.path.basename(os.path.dirname(real))
    except OSError:
        if "nvme" in part_name:
            return part_name.rsplit("p", 1)[0]
        return part_name.rstrip("0123456789")


def _fmt_size(nbytes: float) -> str:
    if nbytes >= 1e12:
        return f"{nbytes / 1e12:.1f}T"
    if nbytes >= 1e9:
        return f"{nbytes / 1e9:.1f}G"
    return f"{nbytes / 1e6:.0f}M"


def _device_label(mountpoint: str, disk: str) -> str:
    """Best-effort human-readable device name."""
    vendor = read_sysfs(f"/sys/block/{disk}/device/vendor").strip()
    model = read_sysfs(f"/sys/block/{disk}/device/model").strip()
    if model:
        name = f"{vendor} {model}".strip() if vendor else model
        if name:
            return name
    return os.path.basename(mountpoint)


def _scan_mounts() -> list[dict]:
    """Parse ``/proc/mounts`` for removable devices under ``/run/media/$USER/``."""
    devices: list[dict] = []
    seen_mounts: set[str] = set()
    try:
        with open("/proc/mounts") as f:
            for line in f:
                parts = line.split()
                if len(parts) < 4:
                    continue
                dev_path, mountpoint, fstype = parts[0], parts[1], parts[2]
                if not mountpoint.startswith(_MEDIA_PREFIX):
                    continue
                if mountpoint in seen_mounts:
                    continue
                seen_mounts.add(mountpoint)

                part_name = os.path.basename(dev_path)
                disk = _parent_disk(part_name)

                removable = read_sysfs(f"/sys/block/{disk}/removable", "0")
                if removable != "1":
                    continue

                # Skip EFI / boot partitions (label heuristic)
                _label = os.path.basename(mountpoint).upper()
                if any(kw in _label for kw in ("EFI", "BOOT", "SYSTEM")):
                    continue

                try:
                    st = os.statvfs(mountpoint)
                    total = st.f_frsize * st.f_blocks
                    free = st.f_frsize * st.f_bavail
                    used = total - free
                    used_pct = int(used * 100 / total) if total > 0 else 0
                except OSError:
                    total, used, used_pct = 0, 0, 0

                devices.append({
                    "device": dev_path,
                    "disk": f"/dev/{disk}",
                    "label": _device_label(mountpoint, disk),
                    "mountpoint": mountpoint,
                    "fstype": fstype,
                    "size_str": _fmt_size(total),
                    "used_str": _fmt_size(used),
                    "used_pct": used_pct,
                    "icon": _USB,
                    "eject_icon": _EJECT,
                    "open_icon": _OPEN,
                })
    except OSError:
        pass
    return devices


@collector
class Storage(PollCollector):
    name = "storage"
    topics = ("storage_devices", "storage_count", "storage_icon")
    interval = 2.0

    async def collect(self) -> Optional[dict]:
        devices = _scan_mounts()
        return {
            "storage_devices": json.dumps(
                devices, ensure_ascii=False, separators=(",", ":")
            ),
            "storage_count": str(len(devices)),
            "storage_icon": _USB,
        }
