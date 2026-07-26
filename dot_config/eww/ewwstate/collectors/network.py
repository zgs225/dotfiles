"""Network collector.

Replaces the four network defpolls:

  network_status, wifi_on, wifi_name, wired_detail

``wifi_networks`` has been moved to ``collectors/wifi_scan.py`` (fully
event-driven via NM D-Bus — zero nmcli, zero polling).

A single ``collect()`` runs the nmcli queries concurrently and derives every
topic from one snapshot, instead of the legacy four-to-five independent nmcli
invocations per cycle.

The legacy filtering logic (network-common.sh) is reimplemented in Python:
exclude bridge/loopback/wifi-p2p/dummy types and the docker/br-/veth/virbr/lo
name patterns.

``wired_detail`` is a yuck-literal string, reproduced byte-for-byte from the
legacy scripts.

Legacy files kept (onclick optimistic updates): network-wifi-on.sh,
network-wifi-name.sh, network-wifi-networks.sh, network-common.sh.
Deletable (no onclick ref): network-status.sh, network-wired-detail.sh.
"""
from __future__ import annotations

import asyncio
import json
import re

from framework import PollCollector, collector
from util import run

_EXCLUDE_TYPES = {"bridge", "loopback", "wifi-p2p", "dummy", "tun"}
_EXCLUDE_NAME_RE = re.compile(r"^(docker[0-9]*|br-[0-9a-f]+|veth[0-9a-f]*|virbr[0-9]*|lo|p2p-)$")


def _real(name: str, typ: str) -> bool:
    if typ in _EXCLUDE_TYPES:
        return False
    if _EXCLUDE_NAME_RE.match(name):
        return False
    return True


def _esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def _parse_device_status(text: str):
    """Yield (device, type, state) from ``nmcli -t -f DEVICE,TYPE,STATE device status``."""
    for line in text.splitlines():
        parts = line.split(":")
        if len(parts) >= 3:
            yield parts[0], parts[1], parts[2]


def _parse_active_conns(text: str):
    """Yield (name, type, device, active) from ``nmcli -t -f NAME,TYPE,DEVICE,STATE connection show --active``."""
    for line in text.splitlines():
        parts = line.split(":")
        if len(parts) >= 4 and parts[0]:
            yield parts[0], parts[1], parts[2], parts[3] == "activated"


@collector
class Network(PollCollector):
    name = "network"
    topics = ("network_status", "wifi_on", "wifi_name", "wired_detail")
    interval = 2.0

    async def collect(self):
        dev_status, active_conns, wifi_radio = await asyncio.gather(
            run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status"], timeout=3.0),
            run(["nmcli", "-t", "-f", "NAME,TYPE,DEVICE,STATE", "connection", "show", "--active"], timeout=3.0),
            run(["nmcli", "radio", "wifi"], timeout=3.0),
        )

        # --- wifi_on ---
        wifi_on = "1" if "enabled" in wifi_radio else "0"

        # --- real active connections ---
        real_wifi = []   # (name, device)
        real_wired = []  # (name, device)
        for name, typ, device, active in _parse_active_conns(active_conns):
            if not _real(name, typ) or not active:
                continue
            if typ.startswith("802-11-wireless"):
                real_wifi.append((name, device))
            elif typ.startswith("802-3-ethernet"):
                real_wired.append((name, device))

        # --- wifi_name ---
        wifi_name = real_wifi[0][0] if real_wifi else "未连接"

        # --- network_status (wired first, then wifi, then none) ---
        # Replicate legacy: scan device status for a connected ethernet, then wifi.
        wired_dev = next((d for d, t, s in _parse_device_status(dev_status)
                          if _real(d, t) and t == "ethernet" and s == "connected"), None)
        wifi_dev = next((d for d, t, s in _parse_device_status(dev_status)
                         if _real(d, t) and t == "wifi" and s == "connected"), None)

        if wired_dev:
            # legacy does nmcli device show for the name; approximate with active conn name
            wname = next((n for n, dv in real_wired if dv == wired_dev), "以太网")
            network_status = json.dumps({"type": "wired", "name": wname, "icon": "󰈀"}, ensure_ascii=False)
        elif wifi_dev:
            wname = next((n for n, dv in real_wifi if dv == wifi_dev), "无线网")
            network_status = json.dumps({"type": "wifi", "name": wname, "icon": "󰤨"}, ensure_ascii=False)
        else:
            network_status = json.dumps({"type": "none", "name": "未连接", "icon": "󰤭"}, ensure_ascii=False)

        # --- wired_detail (yuck literal) ---
        if real_wired:
            name, device = real_wired[0]
            e_dev, e_name = _esc(device), _esc(name)
            wired_detail = (
                '(box :class "wired-list" :orientation "v" '
                '(box :class "wired-row wired-active" :orientation "h" :spacing 12 :valign "center" '
                f'(label :class "wired-icon" :text "󰈀") '
                f'(label :class "wired-name" :xalign 0 :hexpand true :text "{e_name}") '
                f'(label :class "wired-device" :text "{e_dev}")))'
            )
        else:
            wired_detail = '(box :class "wired-list" :orientation "v" (label :class "wired-empty" :xalign 0 :text "未接入有线网"))'

        return {
            "network_status": network_status,
            "wifi_on": wifi_on,
            "wifi_name": wifi_name,
            "wired_detail": wired_detail,
        }
