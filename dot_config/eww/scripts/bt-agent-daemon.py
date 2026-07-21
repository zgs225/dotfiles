#!/usr/bin/env python3
"""Bluetooth pairing agent daemon for eww.

Registers as the default BlueZ agent (system bus, org.bluez.Agent1) and
exposes a session-bus control interface (org.eww.BtAgent) so that
bt-action.sh can trigger active pairing via D-Bus instead of spawning
bluetoothctl (which would register a competing agent).

All SSP authentication callbacks (DisplayPasskey, RequestConfirmation, etc.)
are routed to the eww bt-pair-dialog window.
"""

import signal
import subprocess
import sys
import threading

import dbus
import dbus.service
import dbus.exceptions
import dbus.mainloop.glib
from gi.repository import GLib

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
_sys_bus = dbus.SystemBus()
_session_bus = dbus.SessionBus()

BUS_NAME = "org.eww.BtAgent"
OBJ_PATH = "/org/eww/BtAgent"
IFACE = "org.eww.BtAgent"

AGENT_PATH = "/org/eww/BtAgent"
AGENT_IFACE = "org.bluez.Agent1"

BLUEZ_BUS = "org.bluez"
BLUEZ_PATH = "/org/bluez"
AGENT_MANAGER_IFACE = "org.bluez.AgentManager1"
DEVICE_IFACE = "org.bluez.Device1"

log_file = open("/tmp/eww-bt-agent.log", "a", buffering=1)


def log(msg):
    import datetime
    ts = datetime.datetime.now().strftime("%H:%M:%S")
    log_file.write(f"{ts} {msg}\n")


def eww(*args):
    try:
        subprocess.run(["eww"] + list(args), timeout=5,
                       capture_output=True)
    except Exception:
        pass


def esc(s):
    return s.replace('"', '\\"')


class PairState:
    def __init__(self):
        self.lock = threading.Lock()
        self.active = False
        self.response = None
        self.device_name = ""
        self.mac = ""

    def begin(self, mac, name):
        with self.lock:
            self.active = True
            self.response = None
            self.mac = mac
            self.device_name = name

    def respond(self, resp):
        with self.lock:
            if self.active:
                self.response = resp

    def end(self):
        with self.lock:
            self.active = False
            self.response = None

    def wait_response(self, timeout=60):
        import time
        deadline = time.time() + timeout
        while time.time() < deadline:
            with self.lock:
                if self.response is not None:
                    r = self.response
                    self.response = None
                    return r
            time.sleep(0.2)
        return None


state = PairState()


def show_dialog(code, device, ptype, hint):
    eww("update", f"bt_pair_code={esc(code)}")
    eww("update", f"bt_pair_device={esc(device)}")
    eww("update", f"bt_pair_type={ptype}")
    eww("update", f"bt_pair_hint={esc(hint)}")
    eww("open", "bt-pair-dialog")


def hide_dialog():
    eww("close", "bt-pair-dialog")
    eww("update", "bt_pair_code=")
    eww("update", "bt_pair_type=")


def notice(msg):
    eww("update", f"bt_notice={esc(msg)}")


def device_name_from_path(sys_bus, device_path):
    try:
        dev = sys_bus.get_object(BLUEZ_BUS, device_path)
        props = dbus.Interface(dev, "org.freedesktop.DBus.Properties")
        name = props.Get(DEVICE_IFACE, "Name")
        if name:
            return str(name)
        addr = props.Get(DEVICE_IFACE, "Address")
        return str(addr)
    except Exception:
        return device_path.split("/")[-1]


class BtControl(dbus.service.Object):
    """Session-bus control interface (org.eww.BtAgent).
    bt-action.sh calls PairDevice / RespondPair via dbus-send."""

    def __init__(self, session_bus):
        dbus.service.Object.__init__(self, session_bus, OBJ_PATH)

    @dbus.service.method(IFACE, in_signature="ss", out_signature="")
    def PairDevice(self, mac, label):
        log(f"PairDevice called: {mac} ({label})")
        threading.Thread(target=do_pair, args=(mac, label),
                         daemon=True).start()

    @dbus.service.method(IFACE, in_signature="s", out_signature="")
    def RespondPair(self, response):
        log(f"RespondPair: {response}")
        state.respond(str(response))
        if response == "no":
            hide_dialog()


class BluezAgent(dbus.service.Object):
    """System-bus agent (org.bluez.Agent1).
    bluetoothd calls these callbacks during SSP authentication."""

    def __init__(self, sys_bus):
        self.sys_bus = sys_bus
        dbus.service.Object.__init__(self, sys_bus, AGENT_PATH)

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self):
        log("Agent released")

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        log(f"RequestPinCode: {device} — rejecting")
        raise dbus.exceptions.DBusException(
            "org.bluez.Error.Rejected",
            "Pin code pairing not supported by eww agent")

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        name = device_name_from_path(self.sys_bus, device)
        log(f"DisplayPinCode: {name} = {pincode}")
        show_dialog(pincode, name, "display", "请在设备上输入此 PIN")

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        log(f"RequestPasskey: {device} — rejecting")
        raise dbus.exceptions.DBusException(
            "org.bluez.Error.Rejected",
            "Passkey entry not supported by eww agent")

    @dbus.service.method(AGENT_IFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        name = device_name_from_path(self.sys_bus, device)
        code = f"{passkey:06d}"
        log(f"DisplayPasskey: {name} = {code} (entered={entered})")
        if not state.active:
            state.begin(str(device), name)
        show_dialog(code, name, "display",
                    "请在键盘上输入此配对码")

    @dbus.service.method(AGENT_IFACE, in_signature="ou", out_signature="",
                         async_callbacks=("cb_ok", "cb_err"))
    def RequestConfirmation(self, device, passkey, cb_ok=None, cb_err=None):
        name = device_name_from_path(self.sys_bus, device)
        code = f"{passkey:06d}"
        log(f"RequestConfirmation: {name} = {code}")
        state.begin(str(device), name)
        show_dialog(code, name, "confirm",
                    "此配对码是否与设备显示的一致？")
        threading.Thread(target=self._wait_confirm,
                         args=(cb_ok, cb_err, name), daemon=True).start()

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        name = device_name_from_path(self.sys_bus, device)
        log(f"RequestAuthorization: {name} — auto-accept")

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        name = device_name_from_path(self.sys_bus, device)
        log(f"AuthorizeService: {name} uuid={uuid} — auto-accept")

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self):
        log("Cancel — closing dialog")
        hide_dialog()
        state.end()

    def _wait_confirm(self, cb_ok, cb_err, name):
        resp = state.wait_response(timeout=60)
        state.end()
        if resp == "yes":
            hide_dialog()
            log(f"Confirmation accepted for {name}")
            if cb_ok:
                cb_ok()
        else:
            hide_dialog()
            log(f"Confirmation rejected for {name} (resp={resp})")
            if cb_err:
                cb_err(dbus.exceptions.DBusException(
                    "org.bluez.Error.Rejected", "User rejected pairing"))


def do_pair(mac, label):
    state.begin(mac, label)
    notice(f"正在与 {label} 配对...")
    try:
        root = _sys_bus.get_object(BLUEZ_BUS, "/")
        mgr = dbus.Interface(root, "org.freedesktop.DBus.ObjectManager")
        objects = mgr.GetManagedObjects()
        device_path = None
        for path, ifaces in objects.items():
            if DEVICE_IFACE in ifaces:
                addr = ifaces[DEVICE_IFACE].get("Address", "")
                if str(addr) == mac:
                    device_path = path
                    break

        if not device_path:
            notice(f"未找到设备 {label}")
            state.end()
            return

        dev = _sys_bus.get_object(BLUEZ_BUS, device_path)
        dev_iface = dbus.Interface(dev, DEVICE_IFACE)

        def on_pair_ok():
            log(f"Pair successful: {label}")
            try:
                props = dbus.Interface(dev, "org.freedesktop.DBus.Properties")
                props.Set(DEVICE_IFACE, "Trusted", dbus.Boolean(True))
                dev_iface.Connect(timeout=10)
            except Exception:
                pass
            notice("")
            hide_dialog()
            state.end()

        def on_pair_err(e):
            err = str(e)
            log(f"Pair error: {err}")
            if "AuthenticationFailed" in err or "AuthenticationRejected" in err or "AuthenticationCanceled" in err:
                notice(f"配对被拒绝 — 请同时在 {label} 上忘记此电脑，然后重试")
            elif "AlreadyExists" in err:
                notice("")
                log(f"Already paired: {label}")
            else:
                notice(f"配对失败：{err}")
            hide_dialog()
            state.end()

        dev_iface.Pair(reply_handler=on_pair_ok, error_handler=on_pair_err,
                       timeout=60)

    except Exception as e:
        log(f"Pair exception: {e}")
        notice(f"配对失败：{e}")
        hide_dialog()
        state.end()


def register_agent(sys_bus):
    obj = sys_bus.get_object(BLUEZ_BUS, BLUEZ_PATH)
    mgr = dbus.Interface(obj, AGENT_MANAGER_IFACE)
    mgr.RegisterAgent(AGENT_PATH, "DisplayYesNo")
    mgr.RequestDefaultAgent(AGENT_PATH)
    log("Registered as default BlueZ agent (DisplayYesNo)")


def main():
    signal.signal(signal.SIGTERM, lambda *_: GLib.idle_add(loop.quit))
    signal.signal(signal.SIGINT, lambda *_: GLib.idle_add(loop.quit))

    global loop
    loop = GLib.MainLoop()

    _session_bus.request_name(BUS_NAME)
    log(f"Session bus name acquired: {BUS_NAME}")

    control = BtControl(_session_bus)
    agent = BluezAgent(_sys_bus)
    register_agent(_sys_bus)

    log("Daemon running")
    try:
        loop.run()
    except KeyboardInterrupt:
        pass
    finally:
        try:
            obj = _sys_bus.get_object(BLUEZ_BUS, BLUEZ_PATH)
            mgr = dbus.Interface(obj, AGENT_MANAGER_IFACE)
            mgr.UnregisterAgent(AGENT_PATH)
            log("Agent unregistered")
        except Exception:
            pass
        log("Daemon stopped")


if __name__ == "__main__":
    main()
