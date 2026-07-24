"""Network collector.

Replaces the five network defpolls:

  network_status, wifi_on, wifi_name, wifi_networks, wired_detail

A single ``collect()`` runs the nmcli queries concurrently and derives every
topic from one snapshot, instead of the legacy four-to-five independent nmcli
invocations per cycle.

The legacy filtering logic (network-common.sh) is reimplemented in Python:
exclude bridge/loopback/wifi-p2p/dummy types and the docker/br-/veth/virbr/lo
name patterns.

``wifi_networks`` / ``wired_detail`` are yuck-literal strings (they embed
onclick handlers into wifi-connect.sh), reproduced byte-for-byte from the
legacy scripts — including the ``/tmp/eww-wifi-connecting`` "connecting…"
overlay with its 40s age guard.

Legacy files kept (onclick optimistic updates): network-wifi-on.sh,
network-wifi-name.sh, network-wifi-networks.sh, network-common.sh.
Deletable (no onclick ref): network-status.sh, network-wired-detail.sh.
"""
from __future__ import annotations

import asyncio
import json
import os
import re
import time

from framework import PollCollector, collector
from util import run, shell

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
    topics = ("network_status", "wifi_on", "wifi_name", "wifi_networks", "wired_detail")
    interval = 2.0

    async def collect(self):
        dev_status, active_conns, wifi_radio, wifi_list = await asyncio.gather(
            run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status"], timeout=3.0),
            run(["nmcli", "-t", "-f", "NAME,TYPE,DEVICE,STATE", "connection", "show", "--active"], timeout=3.0),
            run(["nmcli", "radio", "wifi"], timeout=3.0),
            run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"], timeout=3.0),
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

        # --- wifi_networks (yuck literal) ---
        wifi_networks = self._build_wifi_networks(wifi_on, wifi_name, wifi_list)

        return {
            "network_status": network_status,
            "wifi_on": wifi_on,
            "wifi_name": wifi_name,
            "wifi_networks": wifi_networks,
            "wired_detail": wired_detail,
        }

    @staticmethod
    def _build_wifi_networks(wifi_on: str, connected_ssid: str, wifi_list: str) -> str:
        if wifi_on != "1":
            return '(box :class "wifi-list" :orientation "v" (label :class "wifi-off-hint" :xalign 0 :text "无线网已关闭"))'

        # connecting overlay (40s age guard), same as legacy
        connecting = ""
        cf = "/tmp/eww-wifi-connecting"
        try:
            age = int(time.time()) - int(os.path.getmtime(cf))
            if age < 40:
                with open(cf) as f:
                    connecting = f.read().strip()
        except OSError:
            pass

        seen: set[str] = set()
        rows = ""
        count = 0
        for line in wifi_list.splitlines():
            parts = line.split(":")
            if len(parts) < 4:
                continue
            in_use, ssid, signal_s, security = parts[0], parts[1], parts[2], parts[3]
            if not ssid or ssid in seen:
                continue
            seen.add(ssid)
            if count >= 6:
                break
            count += 1

            try:
                sig_val = int(signal_s)
            except ValueError:
                sig_val = 0
            sig = "󰤨" if sig_val >= 75 else "󰤥" if sig_val >= 50 else "󰤢" if sig_val >= 25 else "󰤟"

            secured = bool(re.search(r"WPA|WEP|802", security))
            lock = "󰌾" if secured else "󰤾"

            e_ssid = _esc(ssid)

            if ssid == connected_ssid:
                dot = '(box :class "wifi-dot wifi-dot-on" :valign "center")'
                rowcls = "wifi-network connected"
            elif connecting and ssid == connecting:
                dot = '(box :class "wifi-dot" :valign "center")'
                rowcls = "wifi-network connecting"
            else:
                dot = '(box :class "wifi-dot" :valign "center")'
                rowcls = "wifi-network"

            if connecting and ssid == connecting:
                tailw = '(label :class "wifi-signal" :text "连接中…")'
            else:
                lockw = f'(label :class "wifi-lock" :text "{lock}")' if secured else ""
                tailw = f'{lockw}(label :class "wifi-signal" :text "{sig}")'

            rows += (
                f'(button :class "{rowcls}" :onclick "~/.config/eww/scripts/wifi-connect.sh \'{e_ssid}\'"'
                f'(box :orientation "h" :spacing 10 :space-evenly false {dot}'
                f'(label :class "wifi-ssid" :xalign 0 :hexpand true :limit-width 20 :text "{e_ssid}")'
                f'{tailw}))'
            )

        if not rows:
            rows = '(label :class "wifi-off-hint" :xalign 0 :text "未发现网络")'
        return f'(box :class "wifi-list" :orientation "v" :spacing 2 {rows})'
