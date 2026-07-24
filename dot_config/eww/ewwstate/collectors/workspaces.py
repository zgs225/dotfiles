"""Workspace collector — EventCollector via i3 IPC.

Replaces the 500ms defpoll that shelled out to ``workspaces.sh`` (i3-msg +
jq per poll). Subscribes to i3 ``workspace`` events on the IPC socket and
pushes a yuck-literal on every change — zero polling.

The yuck-literal is identical to what workspaces.sh produced: a ``(box
:class "ws-list" …)`` wrapping ``(eventbox … :onclick "i3-msg workspace N"
(label :class "ws-seal <state>" :text "<stem>"))`` per workspace.

workspaces.sh is **deleted** after migration (no onclick references — the
onclick is inline in the yuck-literal itself).
"""
from __future__ import annotations

import asyncio
import glob
import json
import os
import struct
from typing import Optional

from framework import EventCollector, collector

# ── i3 IPC protocol constants ────────────────────────────────────────────
_MAGIC = b"i3-ipc"
_HEADER = struct.Struct("<6sII")  # magic(6) + payload_len(4) + type(4)

_MSG_GET_WORKSPACES = 1
_MSG_SUBSCRIBE = 2
_EVENT_BIT = 0x80000000  # i3 event messages have the high bit set

# Ten Heavenly Stems for workspace 1-10
_STEMS = "甲乙丙丁戊己庚辛壬癸"


def _stem(num: int) -> str:
    if 1 <= num <= 10:
        return _STEMS[num - 1]
    return str(num)


def _build_yuck(workspaces: list[dict]) -> str:
    """Build the yuck-literal from i3 get_workspaces JSON."""
    # Defensive: a mis-framed message could hand us a dict; never crash.
    if not isinstance(workspaces, list) or not workspaces:
        return "(box)"

    # Sort by num (copy to avoid mutating caller's list)
    workspaces = sorted(workspaces, key=lambda w: w.get("num", 0))

    seals: list[str] = []
    for ws in workspaces:
        num = ws["num"]
        if ws.get("focused"):
            state = "active"
        elif ws.get("urgent"):
            state = "urgent"
        elif ws.get("nodes") and len(ws["nodes"]) > 0:
            state = "occupied"
        else:
            state = "idle"
        glyph = _stem(num)
        seals.append(
            f'(eventbox :class "ws-seal-wrap" :halign "center" '
            f':valign "center" :vexpand false '
            f':onclick "i3-msg workspace {num}" '
            f'(label :class "ws-seal {state}" :halign "center" '
            f':valign "center" :text "{glyph}"))'
        )

    return ('(box :class "ws-list" :halign "center" :valign "center" '
            ':vexpand false :spacing 8 ' + "".join(seals) + ")")


def _find_socket() -> Optional[str]:
    """Locate the i3 IPC socket."""
    sock = os.environ.get("I3SOCK")
    if sock and os.path.exists(sock):
        return sock
    uid = os.getuid()
    candidates = glob.glob(f"/run/user/{uid}/i3/ipc-socket.*")
    if candidates:
        return candidates[0]
    # fallback
    candidates = glob.glob("/tmp/i3-*/ipc-socket.*")
    return candidates[0] if candidates else None


async def _i3_recv(reader: asyncio.StreamReader) -> tuple[int, bytes]:
    """Read one i3 IPC message; return (msg_type, payload)."""
    header = await reader.readexactly(_HEADER.size)
    magic, length, msg_type = _HEADER.unpack(header)
    if magic != _MAGIC:
        raise RuntimeError(f"bad i3 magic: {magic!r}")
    payload = await reader.readexactly(length) if length else b""
    return msg_type, payload


async def _i3_send(writer: asyncio.StreamWriter, msg_type: int,
                   payload: bytes = b"") -> None:
    writer.write(_HEADER.pack(_MAGIC, len(payload), msg_type) + payload)
    await writer.drain()


@collector
class Workspaces(EventCollector):
    name = "workspaces"
    topics = ("workspaces",)

    async def run(self) -> None:
        sock_path = _find_socket()
        if not sock_path:
            # No i3 socket — publish empty and sleep forever
            await self.store.set("workspaces", "(box)")
            await asyncio.sleep(3600)
            return

        while True:
            try:
                reader, writer = await asyncio.open_unix_connection(sock_path)

                # Subscribe to workspace events (reply type 2 is ignored by
                # the pump below — it is neither an event nor a pending req).
                sub_payload = json.dumps(["workspace"]).encode()
                await _i3_send(writer, _MSG_SUBSCRIBE, sub_payload)

                # Proper message pump: i3 can deliver a workspace *event*
                # (payload = dict) before our get_workspaces *reply*
                # (payload = list). The naive "send then read one" pattern
                # mis-aligns and feeds the dict into _build_yuck. Instead we
                # track outstanding requests and dispatch by msg_type:
                #   high bit set        -> event  (request a fresh snapshot)
                #   == GET_WORKSPACES   -> reply  (publish, if pending)
                #   anything else       -> ignore (e.g. subscribe reply)
                pending = False

                async def _request() -> None:
                    nonlocal pending
                    if not pending:
                        await _i3_send(writer, _MSG_GET_WORKSPACES)
                        pending = True

                await _request()  # initial fetch

                while True:
                    msg_type, payload = await _i3_recv(reader)
                    if msg_type & _EVENT_BIT:
                        await _request()  # coalesced re-fetch
                    elif msg_type == _MSG_GET_WORKSPACES and pending:
                        pending = False
                        try:
                            ws_list = json.loads(payload)
                        except (json.JSONDecodeError, ValueError):
                            continue
                        await self.store.set(
                            "workspaces", _build_yuck(ws_list))

            except (ConnectionRefusedError, FileNotFoundError, OSError,
                    asyncio.IncompleteReadError, RuntimeError):
                # i3 restarted or socket gone — back off and retry
                await self.store.set("workspaces", "(box)")
                await asyncio.sleep(2)
                sock_path = _find_socket()
                if not sock_path:
                    await asyncio.sleep(5)
