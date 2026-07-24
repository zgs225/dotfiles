"""Bluetooth collector.

Replaces the three bluetooth defpolls:

  bt_on, bt_discoverable, bt_devices

The legacy layout ran ``bluetoothctl show`` three times per cycle (bt-on.sh,
bt-discoverable-on.sh, and the head of bt-devices.sh); here one ``show`` call
feeds bt_on + bt_discoverable + the powered-gate for bt_devices.

``bt_devices`` is a yuck-literal string with per-device onclick handlers into
bt-action.sh, reproduced from the legacy script (icon map, battery %, the
connected/paired/trusted/stale state machine, paired-then-other ordering).
The legacy "scan while the popup is open" side effect (wmctrl probe →
bt-scan.sh on/off) is preserved verbatim inside the collector.

All three legacy scripts are *kept* for onclick optimistic updates
(toggle-bt.sh, toggle-airplane.sh, toggle-bt-discoverable.sh, bt-action.sh).
"""
from __future__ import annotations

import asyncio
import re

from framework import PollCollector, collector
from util import run, shell

_ICON_MAP = {
    "audio-headphones": "󰋋", "audio-headset": "󰋎", "audio-card": "󰓃",
    "audio-input-microphone": "󰍬", "input-keyboard": "󰌌", "input-mouse": "󰍽",
    "input-gaming": "󰊴", "input-tablet": "󰓶", "phone": "󰄜", "modem": "󰄜",
    "computer": "󰍹", "display": "󰍹", "camera-photo": "󰄀", "camera-video": "󰕧",
    "printer": "󰐪", "scanner": "󰐫",
}
_NO_BATTERY = {"phone", "modem", "computer", "display"}


def _esc(s: str) -> str:
    return s.replace('"', '\\"')


def _parse_show(text: str) -> tuple[bool, bool]:
    powered = "Powered: yes" in text
    discoverable = "Discoverable: yes" in text
    return powered, discoverable


def _parse_devices(text: str) -> list[tuple[str, str]]:
    """``bluetoothctl devices`` → [(mac, name), ...]."""
    out = []
    for line in text.splitlines():
        # "Device AA:BB:.. Name with spaces"
        m = re.match(r"Device\s+([0-9A-F:]{17})\s*(.*)$", line.strip())
        if m:
            out.append((m.group(1), m.group(2).strip()))
    return out


def _parse_info(text: str) -> dict:
    def grab(key: str) -> str:
        m = re.search(rf"^\s*{key}:\s*(.*)$", text, re.M)
        return m.group(1).strip() if m else ""
    return {
        "connected": grab("Connected") == "yes",
        "paired": bool(re.search(r"(Paired|Bonded):\s*yes", text)),
        "trusted": grab("Trusted") == "yes",
        "icon": grab("Icon"),
        "battery": (re.search(r"Battery Percentage:.*\((\d+)\)", text) or [None, ""])[1],
    }


@collector
class Bluetooth(PollCollector):
    name = "bluetooth"
    topics = ("bt_on", "bt_discoverable", "bt_devices")
    interval = 2.0

    async def collect(self):
        show_raw = await run(["bluetoothctl", "show"], timeout=3.0)
        powered, discoverable = _parse_show(show_raw)

        if not powered:
            return {
                "bt_on": "0",
                "bt_discoverable": "0",
                "bt_devices": '(box :class "bt-list" :orientation "v" (label :class "bt-hint" :xalign 0 :text "蓝牙已关闭"))',
            }

        # scan-on-open side effect (verbatim legacy logic)
        wmctrl_raw = await run(["wmctrl", "-l"], timeout=3.0)
        popup_open = "bluetooth-popup" in wmctrl_raw
        await run([f"{_SCRIPTS}/bt-scan.sh", "on" if popup_open else "off"], timeout=3.0)

        devs_raw = await run(["bluetoothctl", "devices"], timeout=3.0)
        devs = _parse_devices(devs_raw)

        # filter unnamed / mac-as-name, then fetch info concurrently (order kept)
        filtered = [(mac, name) for mac, name in devs
                    if name and name != mac.replace(":", "-")]
        infos = await asyncio.gather(
            *(run(["bluetoothctl", "info", mac], timeout=3.0) for mac, _ in filtered)
        )

        paired_rows, other_rows = "", ""
        for (mac, name), info_raw in zip(filtered, infos):
            info = _parse_info(info_raw)
            icon_name = info["icon"]
            dev_icon = _ICON_MAP.get(icon_name, "󰂯")

            if info["connected"]:
                rowcls, primary_act = "bt-device connected", "disconnect"
            elif info["paired"]:
                rowcls, primary_act = "bt-device", "connect"
            elif info["trusted"]:
                rowcls, primary_act = "bt-device stale", "connect"
            else:
                rowcls, primary_act = "bt-device", "pair"

            battery_pct = "" if icon_name in _NO_BATTERY else info["battery"]
            e_name = _esc(name)

            row = (
                f'(eventbox :class "{rowcls}" :cursor "pointer"'
                f' :onclick "~/.config/eww/scripts/bt-action.sh {primary_act} {mac}"'
                f'(box :orientation "h" :spacing 10 :valign "center" :space-evenly false'
                f'(label :class "bt-dev-icon" :text "{dev_icon}")'
                f'(label :class "bt-dev-name" :xalign 0 :limit-width 16 :hexpand true :text "{e_name}")'
            )
            if battery_pct:
                row += f'(label :class "bt-battery" :text "{battery_pct}%")'
            row += (
                f'(button :class "bt-act bt-danger" :tooltip "忘记"'
                f' :onclick "~/.config/eww/scripts/bt-action.sh forget {mac}"'
                f'(label :class "bt-act-icon" :text "󰆴"))))'
            )

            if info["connected"] or info["paired"] or info["trusted"]:
                paired_rows += row
            else:
                other_rows += row

        rows = paired_rows + other_rows
        if not rows:
            discovering = "Discovering: yes" in show_raw
            hint = "扫描中…" if discovering else "未发现设备"
            rows = f'(label :class "bt-hint" :xalign 0 :text "{hint}")'

        return {
            "bt_on": "1",
            "bt_discoverable": "1" if discoverable else "0",
            "bt_devices": f'(box :class "bt-list" :orientation "v" :spacing 2 {rows})',
        }


_SCRIPTS = "/home/yuez/.config/eww/scripts"
