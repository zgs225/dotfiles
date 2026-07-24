"""Power-panel info collector.

Replaces the defpoll of power-info.sh. Emits the same JSON object the legacy
script printed, consumed by power-popup.yuck as ``power_info.<field>``:

  {source, watts, percent, health, cycles, eta, eta_label, threshold,
   dgpu, dgpu_icon, dgpu_holders, icon_fullcharge}

Pure sysfs reads for the battery/AC/dGPU fields; the only subprocess is the
``lsof /dev/nvidia*`` call that lists dGPU holders, and that runs *only* while
the dGPU is active (never waking a suspended one) — exactly like the legacy
script. The legacy file is kept for the onclick optimistic update in
power-admin.sh.
"""
from __future__ import annotations

from framework import PollCollector, collector
from util import read_sysfs, shell

_B = "/sys/class/power_supply/BAT0"
_AC = "/sys/class/power_supply/AC0/online"
_DGPU = "/sys/bus/pci/devices/0000:01:00.0/power/runtime_status"

# Nerd-font PUA glyphs (identical code points to the legacy printf '\uXXXX').
ICON_DGPU_SLEEP = ""
ICON_DGPU_ACTIVE = ""
ICON_FULLCHARGE = ""


def _num(path: str) -> int:
    v = read_sysfs(path, "0")
    try:
        return int(v)
    except ValueError:
        return 0


def _esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


@collector
class PowerInfo(PollCollector):
    name = "powerinfo"
    topics = ("power_info",)
    interval = 3.0

    async def collect(self):
        source = "ac" if read_sysfs(_AC, "0") == "1" else "bat"
        status = read_sysfs(f"{_B}/status", "")
        power_uw = _num(f"{_B}/power_now")
        watts = f"{power_uw / 1e6:.1f}"
        percent = _num(f"{_B}/capacity")
        ef = _num(f"{_B}/energy_full")
        efd = _num(f"{_B}/energy_full_design")
        health = f"{ef * 100 / efd:.0f}" if efd > 0 else "--"
        cycles = _num(f"{_B}/cycle_count")
        en = _num(f"{_B}/energy_now")

        eta, eta_label = "--", "剩余"
        if status == "Discharging" and power_uw > 0:
            eta = f"{en / power_uw:.1f} h"
        elif status == "Charging" and power_uw > 0 and ef > en:
            eta = f"{(ef - en) / power_uw:.1f} h"
            eta_label = "充满"

        threshold = read_sysfs(f"{_B}/charge_control_end_threshold", "0")

        dgpu = read_sysfs(_DGPU, "unknown")
        dgpu_icon = ICON_DGPU_SLEEP if dgpu == "suspended" else ICON_DGPU_ACTIVE
        holders = ""
        if dgpu == "active":
            # Mirror the legacy pipeline; timeout-bounded so a stuck lsof can't
            # stall the collector.
            raw = await shell(
                "lsof /dev/nvidia* 2>/dev/null | awk 'NR>1 {print $1}' "
                "| sort -u | grep -v '^Xorg$' | head -3 | paste -sd, -",
                timeout=2.5,
            )
            holders = raw

        # Hand-built JSON in the exact key order / quoting of the legacy printf
        # template (percent & cycles unquoted ints; the rest quoted strings).
        json = (
            '{"source":"%s","watts":"%s","percent":%d,"health":"%s","cycles":%d,'
            '"eta":"%s","eta_label":"%s","threshold":"%s","dgpu":"%s",'
            '"dgpu_icon":"%s","dgpu_holders":"%s","icon_fullcharge":"%s"}'
            % (
                source, watts, percent, _esc(health), cycles,
                _esc(eta), _esc(eta_label), _esc(threshold), _esc(dgpu),
                dgpu_icon, _esc(holders), ICON_FULLCHARGE,
            )
        )
        return {"power_info": json}
