"""WiFi network scanner — fully event-driven via NetworkManager D-Bus API.

Replaces the ``wifi_networks`` topic that was previously polled by
``collectors/network.py`` (``nmcli device wifi list --rescan no`` every 2s).

Architecture
------------
::

    NM D-Bus signals (system bus, jeepney)
      PropertiesChanged  (AccessPoints / LastScan)   ──┐
      AccessPointAdded / AccessPointRemoved            ├──▶ _refresh() ──▶ store.set("wifi_networks")
      Device.StateChanged (up / down / unavailable)   ─┘
      NM PropertiesChanged (WirelessEnabled)          ─┘

    asyncio timer (every RESCAN_INTERVAL)
      └──▶ RequestScan() ──▶ NM emits signals above ──▶ _refresh()

Zero ``nmcli`` processes.  Zero polling.  When NM is absent or the WiFi
device disappears the collector publishes a static fallback yuck-literal
and sleeps until the next health-check cycle.

The yuck-literal output is byte-for-byte identical to the legacy
``Network._build_wifi_networks()`` (including the ``/tmp/eww-wifi-connecting``
overlay with its 40s age guard), so ``common.yuck`` needs no changes.
"""
from __future__ import annotations

import asyncio
import logging
import os
import time
from typing import Any, Optional

from framework import EventCollector, collector

log = logging.getLogger("ewwstated.wifi_scan")

# ---------------------------------------------------------------------------
# Tunables
# ---------------------------------------------------------------------------
RESCAN_INTERVAL = 30.0        # seconds between RequestScan() calls
HEALTH_CHECK_INTERVAL = 10.0  # re-probe NM when disconnected / no device
NM_STARTUP_GRACE = 2.0        # wait for NM to appear on the bus at boot

# ---------------------------------------------------------------------------
# D-Bus constants
# ---------------------------------------------------------------------------
NM_BUS = "org.freedesktop.NetworkManager"
NM_ROOT = "/org/freedesktop/NetworkManager"
DBUS_PROPS = "org.freedesktop.DBus.Properties"
DBUS_BUS = "org.freedesktop.DBus"
DBUS_PATH = "/org/freedesktop/DBus"

# NM80211DeviceType.WIFI = 2
DEV_TYPE_WIFI = 2
# NM80211ApFlags.PRIVACY = 0x1
AP_FLAG_PRIVACY = 0x1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def _connecting_ssid() -> str:
    """Read the /tmp/eww-wifi-connecting overlay (40s age guard)."""
    cf = "/tmp/eww-wifi-connecting"
    try:
        age = int(time.time()) - int(os.path.getmtime(cf))
        if age < 40:
            with open(cf) as f:
                return f.read().strip()
    except OSError:
        pass
    return ""


def _signal_icon(sig: int) -> str:
    if sig >= 75:
        return "\U000F0928"  # 󰤨
    if sig >= 50:
        return "\U000F0925"  # 󰤥
    if sig >= 25:
        return "\U000F0922"  # 󰤢
    return "\U000F091F"      # 󰤟


def _build_wifi_networks(
    wifi_enabled: bool,
    connected_ssid: str,
    aps: list[dict[str, Any]],
) -> str:
    """Build the yuck-literal string — identical format to legacy."""
    if not wifi_enabled:
        return (
            '(box :class "wifi-list" :orientation "v" '
            '(label :class "wifi-off-hint" :xalign 0 :text "无线网已关闭"))'
        )

    connecting = _connecting_ssid()

    seen: set[str] = set()
    rows = ""
    count = 0
    for ap in aps:
        ssid = ap["ssid"]
        if not ssid or ssid in seen:
            continue
        seen.add(ssid)
        if count >= 6:
            break
        count += 1

        sig_val = ap["strength"]
        sig = _signal_icon(sig_val)
        secured = ap["secured"]
        lock = "\U000F033E" if secured else "\U000F093E"  # 󰌾 / 󰤾

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


_WIFI_OFF = (
    '(box :class "wifi-list" :orientation "v" '
    '(label :class "wifi-off-hint" :xalign 0 :text "无线网已关闭"))'
)
_NO_DEVICE = (
    '(box :class "wifi-list" :orientation "v" '
    '(label :class "wifi-off-hint" :xalign 0 :text "无无线网卡"))'
)
_NM_DOWN = (
    '(box :class "wifi-list" :orientation "v" '
    '(label :class "wifi-off-hint" :xalign 0 :text "NetworkManager 不可用"))'
)


# ---------------------------------------------------------------------------
# Collector
# ---------------------------------------------------------------------------

@collector
class WifiScan(EventCollector):
    """Event-driven WiFi AP scanner via NetworkManager D-Bus (jeepney)."""

    name = "wifi_scan"
    topics = ("wifi_networks",)

    async def run(self) -> None:
        """Main loop: connect → subscribe → react to signals forever."""
        while True:
            try:
                await self._session()
            except asyncio.CancelledError:
                raise
            except Exception:
                log.exception("wifi_scan: session failed; retrying in %.0fs",
                              HEALTH_CHECK_INTERVAL)
                await self.store.set("wifi_networks", _NM_DOWN)
                await asyncio.sleep(HEALTH_CHECK_INTERVAL)

    # -- one D-Bus session (lives until NM dies or an error occurs) ---------

    async def _session(self) -> None:
        from jeepney.io.asyncio import open_dbus_router
        from jeepney import (
            DBusAddress, HeaderFields, MatchRule, MessageType,
            new_method_call,
        )

        await asyncio.sleep(NM_STARTUP_GRACE)

        async with open_dbus_router(bus="SYSTEM") as router:
            # -- verify NM is on the bus ------------------------------------
            nm_addr = DBusAddress(NM_ROOT, bus_name=NM_BUS, interface=NM_BUS)
            try:
                body = await asyncio.wait_for(
                    self._call(router, nm_addr, "GetDevices"), timeout=5)
            except Exception:
                log.warning("wifi_scan: NM not reachable")
                await self.store.set("wifi_networks", _NM_DOWN)
                await asyncio.sleep(HEALTH_CHECK_INTERVAL)
                return

            devices: list[str] = body[0]

            # -- find the WiFi device (DeviceType == 2) ---------------------
            wifi_dev: Optional[str] = None
            for dev in devices:
                dev_addr = DBusAddress(dev, bus_name=NM_BUS,
                                       interface=f"{NM_BUS}.Device")
                try:
                    dtype = await self._get_prop(router, dev_addr, "DeviceType")
                except Exception:
                    continue
                if dtype == DEV_TYPE_WIFI:
                    wifi_dev = dev
                    break

            if wifi_dev is None:
                log.info("wifi_scan: no WiFi device found")
                await self.store.set("wifi_networks", _NO_DEVICE)
                # Sleep and re-check (USB adapter may be plugged later)
                await asyncio.sleep(HEALTH_CHECK_INTERVAL)
                return

            log.info("wifi_scan: using device %s", wifi_dev)

            # -- subscribe to signals ---------------------------------------
            rules = [
                # AP list / scan results changed
                MatchRule(type="signal", interface=DBUS_PROPS,
                          member="PropertiesChanged", path=wifi_dev),
                # Individual AP appear / disappear
                MatchRule(type="signal",
                          interface=f"{NM_BUS}.Device.Wireless",
                          path=wifi_dev),
                # Device state (connected / disconnected / unavailable)
                MatchRule(type="signal",
                          interface=f"{NM_BUS}.Device",
                          member="StateChanged", path=wifi_dev),
                # NM global WirelessEnabled toggle
                MatchRule(type="signal", interface=DBUS_PROPS,
                          member="PropertiesChanged", path=NM_ROOT),
            ]
            queues: list[asyncio.Queue] = []
            for rule in rules:
                await self._add_match(router, rule)
                fh = router.filter(rule, bufsize=64)
                queues.append(fh.queue)

            # -- initial read -----------------------------------------------
            await self._refresh(router, wifi_dev)

            # -- event loop: signals + periodic rescan ----------------------
            rescan_timer = asyncio.get_event_loop().time() + RESCAN_INTERVAL
            wifi_addr = DBusAddress(wifi_dev, bus_name=NM_BUS,
                                    interface=f"{NM_BUS}.Device.Wireless")

            while True:
                # Wait for the next signal or rescan deadline
                now = asyncio.get_event_loop().time()
                timeout = max(0.5, rescan_timer - now)

                got_signal = False
                for q in queues:
                    try:
                        q.get_nowait()
                        got_signal = True
                    except asyncio.QueueEmpty:
                        pass

                if not got_signal:
                    # Block-wait on the first queue that gets a message
                    wait_tasks = [asyncio.create_task(q.get()) for q in queues]
                    try:
                        done, _ = await asyncio.wait(
                            wait_tasks, timeout=timeout,
                            return_when=asyncio.FIRST_COMPLETED)
                        if done:
                            got_signal = True
                    finally:
                        for t in wait_tasks:
                            t.cancel()
                            try:
                                await t
                            except asyncio.CancelledError:
                                pass

                now = asyncio.get_event_loop().time()
                if now >= rescan_timer:
                    rescan_timer = now + RESCAN_INTERVAL
                    try:
                        await asyncio.wait_for(
                            self._call(router, wifi_addr, "RequestScan",
                                       "a{sv}", ({},)),
                            timeout=5)
                    except Exception:
                        log.debug("wifi_scan: RequestScan failed (rate-limited?)")

                if got_signal:
                    # Drain any remaining queued signals (coalesce)
                    for q in queues:
                        while not q.empty():
                            try:
                                q.get_nowait()
                            except asyncio.QueueEmpty:
                                break
                    await self._refresh(router, wifi_dev)

    # -- D-Bus helpers ------------------------------------------------------

    @staticmethod
    async def _call(router, addr, method, sig="", args=(), timeout=5):
        from jeepney import new_method_call, MessageType
        msg = new_method_call(addr, method, sig, args)
        reply = await asyncio.wait_for(
            router.send_and_get_reply(msg), timeout)
        if reply.header.message_type == MessageType.error:
            raise RuntimeError(f"D-Bus error: {reply.body}")
        return reply.body

    @staticmethod
    async def _get_prop(router, addr, prop, timeout=5):
        """Read a D-Bus property; returns the unwrapped variant value."""
        props_addr = addr.with_interface(DBUS_PROPS)
        body = await WifiScan._call(
            router, props_addr, "Get", "ss", (addr.interface, prop), timeout)
        return body[0][1]  # (signature, value) → value

    @staticmethod
    async def _add_match(router, rule) -> None:
        from jeepney import DBusAddress, new_method_call
        addr = DBusAddress(DBUS_PATH, bus_name=DBUS_BUS, interface=DBUS_BUS)
        msg = new_method_call(addr, "AddMatch", "s", (rule.serialise(),))
        await asyncio.wait_for(router.send_and_get_reply(msg), timeout=5)

    # -- AP list reader -----------------------------------------------------

    async def _refresh(self, router, wifi_dev: str) -> None:
        """Re-read the AP list via D-Bus and publish wifi_networks."""
        from jeepney import DBusAddress

        try:
            # WiFi enabled?
            nm_addr = DBusAddress(NM_ROOT, bus_name=NM_BUS, interface=NM_BUS)
            wifi_enabled = await self._get_prop(router, nm_addr,
                                                "WirelessEnabled")

            if not wifi_enabled:
                await self.store.set("wifi_networks", _WIFI_OFF)
                return

            # Connected SSID (ActiveAccessPoint → Ssid)
            wifi_addr = DBusAddress(wifi_dev, bus_name=NM_BUS,
                                    interface=f"{NM_BUS}.Device.Wireless")
            connected_ssid = ""
            try:
                active_ap = await self._get_prop(router, wifi_addr,
                                                 "ActiveAccessPoint")
                if active_ap and active_ap != "/":
                    ap_addr = DBusAddress(active_ap, bus_name=NM_BUS,
                                          interface=f"{NM_BUS}.AccessPoint")
                    raw = await self._get_prop(router, ap_addr, "Ssid")
                    connected_ssid = bytes(raw).decode(errors="replace")
            except Exception:
                pass

            # AP list
            body = await self._call(router, wifi_addr, "GetAccessPoints")
            ap_paths: list[str] = body[0]

            aps: list[dict[str, Any]] = []
            for ap_path in ap_paths:
                ap_addr = DBusAddress(ap_path, bus_name=NM_BUS,
                                      interface=f"{NM_BUS}.AccessPoint")
                try:
                    raw_ssid, strength, flags, wpa, rsn = await asyncio.gather(
                        self._get_prop(router, ap_addr, "Ssid"),
                        self._get_prop(router, ap_addr, "Strength"),
                        self._get_prop(router, ap_addr, "Flags"),
                        self._get_prop(router, ap_addr, "WpaFlags"),
                        self._get_prop(router, ap_addr, "RsnFlags"),
                    )
                except Exception:
                    continue
                ssid = bytes(raw_ssid).decode(errors="replace")
                secured = bool(flags & AP_FLAG_PRIVACY) or bool(wpa) or bool(rsn)
                aps.append({
                    "ssid": ssid,
                    "strength": int(strength),
                    "secured": secured,
                })

            # Sort by signal strength descending (NM doesn't guarantee order)
            aps.sort(key=lambda a: a["strength"], reverse=True)

            yuck = _build_wifi_networks(True, connected_ssid, aps)
            await self.store.set("wifi_networks", yuck)

        except asyncio.CancelledError:
            raise
        except Exception:
            log.exception("wifi_scan: _refresh failed")
