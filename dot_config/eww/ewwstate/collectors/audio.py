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

  ``audio_sinks`` additionally includes *profile entries*: available-but-
  inactive card output profiles (e.g. HDMI/DP monitor speakers that share the
  same sound card as the analog output).  These have ``"type":"profile"`` and a
  non-empty ``"card"`` field; real sinks have ``"type":"sink"`` and ``"card":""``.
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


def _friendly(desc: str, builtin_label: str, name: str,
              port_names: dict[str, str] | None = None) -> str:
    if "Built-in Audio" in desc:
        # HDMI/DP sinks also say "Built-in Audio" — use port product name
        if port_names and ("HDMI" in desc or "DisplayPort" in desc):
            suffix = name.rsplit(".", 1)[-1]  # e.g. "hdmi-stereo"
            product = port_names.get(suffix, "")
            if product:
                return product
        return builtin_label
    if desc:
        return desc
    return name


def _esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def _build_list(pairs: list[tuple[str, str]], current: str, builtin_label: str,
                port_names: dict[str, str] | None = None) -> list[dict]:
    items = []
    for name, desc in pairs:
        items.append({
            "name": name,
            "friendly": _friendly(desc, builtin_label, name, port_names),
            "active": name == current,
            "type": "sink",
            "card": "",
        })
    return items


def _profile_score(profile_name: str) -> int:
    """Score a card profile for selection: prefer stereo output + input.

    Only the *output* part (before ``+``) is checked for ``stereo`` so that
    ``output:hdmi-surround+input:analog-stereo`` does NOT get a stereo bonus
    from the input side.
    """
    output_part = profile_name.split("+")[0]
    score = 0
    if "stereo" in output_part:
        score += 2
    if "+input:" in profile_name:
        score += 1
    return score


def _build_port_name_map(cards_json: str) -> dict[str, str]:
    """Map output-profile suffix (e.g. ``hdmi-stereo``) to port product name.

    Used by ``_friendly`` to give HDMI/DP sinks a human-readable name
    (e.g. ``DELL U2720QM``) instead of the generic ``内置扬声器``.
    """
    try:
        cards = json.loads(cards_json)
    except (json.JSONDecodeError, ValueError):
        return {}
    if not isinstance(cards, list):
        return {}
    result: dict[str, str] = {}
    for card in cards:
        for _pn, port in card.get("ports", {}).items():
            if port.get("type") not in ("HDMI", "DP"):
                continue
            product = port.get("properties", {}).get("device.product.name", "")
            if not product:
                continue
            for pname in port.get("profiles", []):
                # "output:hdmi-stereo+input:analog-stereo" → "hdmi-stereo"
                suffix = pname.split(":", 1)[-1].split("+")[0]
                result[suffix] = product
    return result


_OUTPUT_PORT_TYPES = {"Speaker", "Headphones", "HDMI", "DP"}
_BUILTIN_OUTPUT_LABEL = "内置扬声器"


def _port_available(avail: str) -> bool:
    """True for 'available' and 'availability unknown' (speakers), false for 'not available'."""
    return avail != "not available"


def parse_card_profiles(cards_json: str) -> list[dict]:
    """Parse ``pactl --format=json list cards`` output.

    Returns profile-switch entries for available-but-inactive output profiles.
    Covers ALL output port types (Speaker, Headphones, HDMI, DP) so that
    switching works in both directions: analog→HDMI and HDMI→analog.

    Each entry: ``{"name": <profile>, "friendly": <display name>,
    "active": false, "type": "profile", "card": <card name>}``.
    """
    try:
        cards = json.loads(cards_json)
    except (json.JSONDecodeError, ValueError):
        return []
    if not isinstance(cards, list):
        return []

    results: list[dict] = []
    for card in cards:
        card_name = card.get("name", "")
        active_profile = card.get("active_profile", "")
        profiles = card.get("profiles", {})
        ports = card.get("ports", {})

        # Extract the output part of the active profile to filter variants
        # e.g. "output:hdmi-stereo" → exclude "output:hdmi-stereo+input:..."
        active_output = active_profile.split("+")[0] if active_profile else ""

        seen_profiles: set[str] = set()

        for _port_name, port in ports.items():
            port_type = port.get("type", "")
            if port_type not in _OUTPUT_PORT_TYPES:
                continue
            if not _port_available(port.get("availability", "")):
                continue
            # If the active profile already covers this port, skip it
            port_profiles = set(port.get("profiles", []))
            if active_profile in port_profiles:
                continue

            # Friendly name: product name for HDMI/DP, builtin label for analog
            if port_type in ("HDMI", "DP"):
                props = port.get("properties", {})
                friendly = props.get("device.product.name", "") or port.get("description", "")
            else:
                friendly = _BUILTIN_OUTPUT_LABEL

            # Find the best available output profile for this port
            best = ""
            best_score = -1
            for pname in port.get("profiles", []):
                if pname in seen_profiles or pname == active_profile:
                    continue
                # Skip variants of the active output (e.g. +input: combos)
                if pname.split("+")[0] == active_output:
                    continue
                pinfo = profiles.get(pname, {})
                if not pinfo.get("available", False):
                    continue
                if pinfo.get("sinks", 0) < 1:
                    continue
                sc = _profile_score(pname)
                if sc > best_score:
                    best = pname
                    best_score = sc

            if best:
                seen_profiles.add(best)
                results.append({
                    "name": best,
                    "friendly": friendly,
                    "active": False,
                    "type": "profile",
                    "card": card_name,
                })

    return results


def _list_json(items: list[dict]) -> str:
    # Compact JSON, keys in name/friendly/active/type/card order, booleans
    # lowercase. Build by hand to guarantee key order.
    parts = []
    for it in items:
        parts.append(
            '{"name":%s,"friendly":%s,"active":%s,"type":%s,"card":%s}'
            % (json.dumps(it["name"], ensure_ascii=False),
               json.dumps(it["friendly"], ensure_ascii=False),
               "true" if it["active"] else "false",
               json.dumps(it.get("type", "sink"), ensure_ascii=False),
               json.dumps(it.get("card", ""), ensure_ascii=False))
        )
    return "[" + ",".join(parts) + "]"


@collector
class Audio(PollCollector):
    name = "audio"
    topics = ("volume", "muted", "audio_sinks", "audio_sources", "audio_devices")
    interval = 2.0

    async def collect(self):
        (vol_raw, mute_raw, sinks_raw, sources_raw,
         def_sink, def_source, cards_raw) = await asyncio.gather(
            run(["pamixer", "--get-volume"], timeout=3.0),
            run(["pamixer", "--get-mute"], timeout=3.0),
            run(["pactl", "list", "sinks"], timeout=3.0),
            run(["pactl", "list", "sources"], timeout=3.0),
            run(["pactl", "get-default-sink"], timeout=3.0),
            run(["pactl", "get-default-source"], timeout=3.0),
            run(["pactl", "--format=json", "list", "cards"], timeout=3.0),
        )

        volume = vol_raw if vol_raw else "0"
        muted = mute_raw if mute_raw else "false"

        sink_pairs = _parse_name_desc(sinks_raw)
        src_pairs = [(n, d) for (n, d) in _parse_name_desc(sources_raw)
                     if not n.endswith(".monitor")]

        port_names = _build_port_name_map(cards_raw)
        sinks = _build_list(sink_pairs, def_sink, "内置扬声器", port_names)
        # Append available-but-inactive card profiles (e.g. HDMI monitor)
        sinks.extend(parse_card_profiles(cards_raw))
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
