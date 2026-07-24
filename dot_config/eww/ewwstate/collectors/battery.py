"""Battery collector.

Replaces battery-percent.sh / battery-charging.sh / battery-icon.sh, which each
re-read the same sysfs attributes independently. One collection now publishes
all three topics. Pure sysfs reads — no subprocesses.
"""
from __future__ import annotations

from framework import PollCollector, collector
from util import read_sysfs, sysfs_glob


def _icon(percent: int, charging: bool) -> str:
    if charging:
        return "󰂄"
    if percent >= 90:
        return "󰁹"
    if percent >= 70:
        return "󰂁"
    if percent >= 50:
        return "󰁾"
    if percent >= 30:
        return "󰁼"
    if percent >= 15:
        return "󰁺"
    return "󰂃"


@collector
class Battery(PollCollector):
    name = "battery"
    topics = ("battery_percent", "battery_charging", "battery_icon")
    interval = 5.0

    async def collect(self):
        caps = sysfs_glob("/sys/class/power_supply/BAT*/capacity")
        if not caps:
            # No battery (desktop): match the legacy scripts' defaults.
            return {
                "battery_percent": "100",
                "battery_charging": "false",
                "battery_icon": "󰁹",
            }
        cap_path = caps[0]
        base = cap_path.rsplit("/", 1)[0]
        try:
            percent = int(read_sysfs(cap_path, "100"))
        except ValueError:
            percent = 100
        status = read_sysfs(f"{base}/status", "Unknown")
        charging = status in ("Charging", "Full")
        return {
            "battery_percent": str(percent),
            "battery_charging": "true" if charging else "false",
            "battery_icon": _icon(percent, charging),
        }
