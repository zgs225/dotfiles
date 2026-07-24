"""Weather collector.

Replaces weather.sh (curl wttr.in + jq + 30-min /tmp cache). Uses async
aiohttp-free approach: ``util.shell`` with curl, then json.parse in Python.
Retains the 30-min file cache at /tmp/eww_weather.json for resilience.

Emits JSON: ``{"temp":"NN°C","desc":"…","lohi":"NN° / NN°"}``
"""
from __future__ import annotations

import json
import os
import time

from framework import PollCollector, collector
from util import shell

_CACHE = "/tmp/eww_weather.json"
_MAX_AGE = 1800  # 30 min

_FALLBACK = json.dumps(
    {"temp": "--°C", "desc": "暂无数据", "lohi": "--° / --°"},
    ensure_ascii=False,
)


def _read_cache() -> str | None:
    try:
        age = time.time() - os.path.getmtime(_CACHE)
        if age < _MAX_AGE:
            with open(_CACHE) as f:
                data = f.read().strip()
            if data:
                return data
    except OSError:
        pass
    return None


def _write_cache(data: str) -> None:
    try:
        with open(_CACHE, "w") as f:
            f.write(data)
    except OSError:
        pass


@collector
class Weather(PollCollector):
    name = "weather"
    topics = ("weather",)
    interval = 900.0  # 15 min

    async def collect(self):
        # Check cache first
        cached = _read_cache()
        if cached:
            return {"weather": cached}

        # Fetch from wttr.in
        raw = await shell(
            'curl -fsm 6 "https://wttr.in/?format=j1" 2>/dev/null',
            timeout=10.0,
        )
        if not raw:
            return {"weather": _FALLBACK}

        try:
            data = json.loads(raw)
            cc = data["current_condition"][0]
            w = data["weather"][0]
            result = json.dumps({
                "temp": cc["temp_C"] + "°C",
                "desc": cc["weatherDesc"][0]["value"],
                "lohi": w["mintempC"] + "° / " + w["maxtempC"] + "°",
            }, ensure_ascii=False)
            _write_cache(result)
            return {"weather": result}
        except (json.JSONDecodeError, KeyError, IndexError, TypeError):
            return {"weather": _FALLBACK}
