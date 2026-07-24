#!/usr/bin/env python3
"""ewwstate — client + daemon entry point for the eww state framework.

Usage:
  ewwstate daemon                 run the collector daemon (foreground)
  ewwstate get <topic> [fallback] print a topic's last collected value
  ewwstate listen <topic>         print value, then re-print on every change
  ewwstate dump                   print every topic and its value
  ewwstate status                 is the daemon alive?

``get`` reads the tmpfs mirror file directly — it never talks to the daemon and
never triggers collection, so it is instant and works even if the daemon is
down (printing ``fallback`` when no value exists yet).
"""
from __future__ import annotations

import os
import sys

# Make sibling modules importable regardless of the caller's CWD.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

USAGE = __doc__.strip()


def statedir() -> str:
    base = os.environ.get("XDG_RUNTIME_DIR") or os.path.expanduser("~/.cache/eww")
    d = os.path.join(base, "ewwstate")
    os.makedirs(d, exist_ok=True)
    return d


def _read_topic(topic: str) -> str | None:
    try:
        with open(os.path.join(statedir(), topic)) as f:
            return f.read().rstrip("\n")
    except OSError:
        return None


def cmd_get(topic: str, fallback: str = "") -> int:
    value = _read_topic(topic)
    # Emit fallback when the daemon hasn't produced this topic yet, so eww never
    # flashes a blank value during startup.
    sys.stdout.write(value if value not in (None, "") else fallback)
    sys.stdout.write("\n")
    return 0


def cmd_listen(topic: str) -> int:
    import shutil
    import subprocess

    def emit() -> None:
        v = _read_topic(topic)
        if v is not None:
            sys.stdout.write(v + "\n")
            sys.stdout.flush()

    emit()
    if not shutil.which("inotifywait"):
        return 0
    proc = subprocess.Popen(
        ["inotifywait", "-mq", "-e", "modify,close_write,moved_to,create", statedir()],
        stdout=subprocess.PIPE,
        text=True,
    )
    assert proc.stdout is not None
    for line in proc.stdout:
        # inotifywait prints "<dir> <EVENTS> <name>"; the name is last.
        if line.rstrip().split() and line.rstrip().split()[-1] == topic:
            emit()
    return 0


def cmd_dump() -> int:
    d = statedir()
    for name in sorted(os.listdir(d)):
        if name.startswith(".") or name.endswith((".pid", ".sock", ".flag")):
            continue
        value = _read_topic(name)
        print(f"{name} = {value}")
    return 0


def cmd_status() -> int:
    pidfile = os.path.join(statedir(), "ewwstated.pid")
    try:
        with open(pidfile) as f:
            pid = int(f.read().strip())
    except (OSError, ValueError):
        print("ewwstated: not running (no pidfile)")
        return 1
    try:
        os.kill(pid, 0)
    except OSError:
        print(f"ewwstated: stale pidfile ({pid} not alive)")
        return 1
    print(f"ewwstated: running (pid {pid})")
    return 0


def cmd_daemon() -> int:
    import asyncio
    import logging
    import signal

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        handlers=[logging.StreamHandler(sys.stderr)],
    )
    log = logging.getLogger("ewwstated")

    d = statedir()
    with open(os.path.join(d, "ewwstated.pid"), "w") as f:
        f.write(str(os.getpid()))

    import daemon

    async def _main() -> None:
        loop = asyncio.get_running_loop()
        stop = asyncio.Event()
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, stop.set)
        serve_task = asyncio.create_task(daemon.serve(d))
        await stop.wait()
        log.info("shutting down")
        serve_task.cancel()
        try:
            await serve_task
        except asyncio.CancelledError:
            pass

    try:
        asyncio.run(_main())
    finally:
        try:
            os.unlink(os.path.join(d, "ewwstated.pid"))
        except OSError:
            pass
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(USAGE)
        return 2
    cmd = argv[1]
    if cmd == "get" and len(argv) >= 3:
        return cmd_get(argv[2], argv[3] if len(argv) >= 4 else "")
    if cmd == "listen" and len(argv) >= 3:
        return cmd_listen(argv[2])
    if cmd == "dump":
        return cmd_dump()
    if cmd == "status":
        return cmd_status()
    if cmd == "daemon":
        return cmd_daemon()
    print(USAGE)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
