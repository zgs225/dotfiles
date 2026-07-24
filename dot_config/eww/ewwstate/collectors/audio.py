"""Audio collector (volume / mute / device lists).

Replaces the five defpolls that used to each shell out independently:

  volume, muted, audio_sinks, audio_sources, audio_devices

The legacy layout re-read PulseAudio up to *three* times per cycle
(audio-devices.sh internally re-ran audio-sinks.sh + audio-sources.sh, and the
two list defpolls ran them again). Here a single ``collect()`` takes ONE
concurrent snapshot of pactl/pamixer and derives all five topics from it.

Emitted values are byte/parse-equivalent to the legacy scripts:

* ``audio_sinks`` / ``audio_sources`` — JSON arrays ``[{name,friendly,active}]``
  with the same "Built-in Audio" → 内置扬声器 / 内置麦克风 mapping and the same
  ``.monitor`` exclusion on sources.
* ``audio_devices`` — the aggregate object
  ``{current_sink,current_sink_friendly,current_source,current_source_friendly,
  sinks,sources}``.
* ``volume`` / ``muted`` — the pamixer scalars.

All three legacy scripts are *kept*: audio-devices.sh is still called by
open-popup.sh for its instant audio-popup data, and it in turn calls
audio-sinks.sh / audio-sources.sh, so the whole onclick chain must resolve.
"""
from __future__ import annotations

import asyncio
import json
import re

from framework import PollCollector, collector
from util import run

_NAME_RE = re.compile(r"^\s*Name:\s*(.*)$")
_DESC_RE = re.compile(r"^\s*Description:\s*(.*)$")


def _parse_name_desc(text: str) -> list[tuple[str, str]]:
    """Replicate the legacy awk: pair each ``Name:`` with the following
    ``Description:`` line, in document order."""
    out: list[tuple[str, str]] = []
    name = ""
    for line in text.splitlines():
        m = _NAME_RE.match(line)
        if m:
            name = m.group(1).strip()
            continue
        m = _DESC_RE.match(line)
        if m and name:
            out.append((name, m.group(1).strip()))
            name = ""
    return out


def _friendly(desc: str, builtin_label: str, name: str) -> str:
    if "Built-in Audio" in desc:
        return builtin_label
    if desc:
        return desc
    return name


def _esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def _build_list(pairs: list[tuple[str, str]], current: str, builtin_label: str) -> list[dict]:
    items = []
    for name, desc in pairs:
        items.append({
            "name": name,
            "friendly": _friendly(desc, builtin_label, name),
            "active": name == current,
        })
    return items


def _list_json(items: list[dict]) -> str:
    # Match the legacy jq output exactly: compact, keys in name/friendly/active
    # order, booleans lowercase. Build by hand to guarantee key order.
    parts = []
    for it in items:
        parts.append(
            '{"name":%s,"friendly":%s,"active":%s}'
            % (json.dumps(it["name"], ensure_ascii=False),
               json.dumps(it["friendly"], ensure_ascii=False),
               "true" if it["active"] else "false")
        )
    return "[" + ",".join(parts) + "]"


@collector
class Audio(PollCollector):
    name = "audio"
    topics = ("volume", "muted", "audio_sinks", "audio_sources", "audio_devices")
    interval = 2.0

    async def collect(self):
        vol_raw, mute_raw, sinks_raw, sources_raw, def_sink, def_source = (
            await asyncio.gather(
                run(["pamixer", "--get-volume"], timeout=3.0),
                run(["pamixer", "--get-mute"], timeout=3.0),
                run(["pactl", "list", "sinks"], timeout=3.0),
                run(["pactl", "list", "sources"], timeout=3.0),
                run(["pactl", "get-default-sink"], timeout=3.0),
                run(["pactl", "get-default-source"], timeout=3.0),
            )
        )

        volume = vol_raw if vol_raw else "0"
        muted = mute_raw if mute_raw else "false"

        sink_pairs = _parse_name_desc(sinks_raw)
        src_pairs = [(n, d) for (n, d) in _parse_name_desc(sources_raw)
                     if not n.endswith(".monitor")]

        sinks = _build_list(sink_pairs, def_sink, "内置扬声器")
        sources = _build_list(src_pairs, def_source, "内置麦克风")

        sinks_json = _list_json(sinks)
        sources_json = _list_json(sources)

        cs_friendly = next((it["friendly"] for it in sinks if it["active"]), "")
        csrc_friendly = next((it["friendly"] for it in sources if it["active"]), "")

        devices = (
            '{"current_sink":%s,"current_sink_friendly":%s,'
            '"current_source":%s,"current_source_friendly":%s,'
            '"sinks":%s,"sources":%s}'
            % (
                json.dumps(def_sink, ensure_ascii=False),
                json.dumps(cs_friendly, ensure_ascii=False),
                json.dumps(def_source, ensure_ascii=False),
                json.dumps(csrc_friendly, ensure_ascii=False),
                sinks_json, sources_json,
            )
        )

        return {
            "volume": volume,
            "muted": muted,
            "audio_sinks": sinks_json,
            "audio_sources": sources_json,
            "audio_devices": devices,
        }
