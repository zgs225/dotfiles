"""Power-profile collector (TLP tlpctl).

Replaces the defpoll ``power-profile.sh get``. The legacy script is *kept* for
its ``set`` / ``cycle`` onclick actions (which also do the optimistic
``eww update power_profile=…``); only the polling read moves here.

Emits the same JSON object as ``power-profile.sh get``:
  {mode, profile, source, icon, label, icon_auto, icon_powersave, icon_performance}

mode ∈ {auto, powersave, performance, unavailable}.
"""
from __future__ import annotations

from framework import PollCollector, collector
from util import read_sysfs, run

_AC = "/sys/class/power_supply/AC0/online"

ICON_AUTO = ""
ICON_POWERSAVE = ""
ICON_PERFORMANCE = ""
ICON_UNKNOWN = ""


def _on_ac() -> bool:
    return read_sysfs(_AC, "0") == "1"


def _source_default() -> str:
    return "balanced" if _on_ac() else "power-saver"


def _mode_of(profile: str) -> str:
    if profile == _source_default():
        return "auto"
    if profile == "power-saver":
        return "powersave"
    if profile == "performance":
        return "performance"
    return "auto"


@collector
class PowerProfile(PollCollector):
    name = "powerprofile"
    topics = ("power_profile",)
    interval = 3.0

    async def collect(self):
        tlpctl = await run(["tlpctl", "get"], timeout=3.0)
        if not tlpctl:
            # tlpctl missing → unavailable (matches legacy cmd_get).
            return {"power_profile": self._json("unavailable", "", "", ICON_UNKNOWN, "电源")}

        profile = tlpctl.splitlines()[0].strip() if tlpctl else ""
        mode = _mode_of(profile)
        src = "ac" if _on_ac() else "bat"

        if mode == "auto":
            icon, label = ICON_AUTO, "自动"
        elif mode == "powersave":
            icon, label = ICON_POWERSAVE, "省电"
        elif mode == "performance":
            icon, label = ICON_PERFORMANCE, "性能"
        else:
            icon, label = ICON_UNKNOWN, "电源"

        return {"power_profile": self._json(mode, profile, src, icon, label)}

    @staticmethod
    def _json(mode: str, profile: str, src: str, icon: str, label: str) -> str:
        return (
            '{"mode":"%s","profile":"%s","source":"%s","icon":"%s","label":"%s",'
            '"icon_auto":"%s","icon_powersave":"%s","icon_performance":"%s"}'
            % (mode, profile, src, icon, label, ICON_AUTO, ICON_POWERSAVE, ICON_PERFORMANCE)
        )
