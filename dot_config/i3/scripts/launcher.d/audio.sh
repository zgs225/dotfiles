#!/usr/bin/env bash

# audio — 音频输入/输出设备管理模块
# 前缀：audio。列出输出设备（含 HDMI/DP profile）和输入设备，点击切换。

register_module audio "audio" plain "" "音频"

audio_init() {
    printf '\0prompt\x1f音频\n'
    printf '\0no-custom\x1ftrue\n'

    if ! command -v pactl >/dev/null 2>&1; then
        msg_row "未安装 pactl (pulseaudio-utils)" dialog-error
        return 0
    fi

    /usr/bin/python3 <<'PYEOF'
import json, subprocess

def pactl_json(*args):
    try:
        r = subprocess.run(["pactl", "--format=json"] + list(args),
                           capture_output=True, text=True, timeout=3)
        return json.loads(r.stdout) if r.stdout.strip() else []
    except Exception:
        return []

def pactl_str(*args):
    try:
        r = subprocess.run(["pactl"] + list(args),
                           capture_output=True, text=True, timeout=3)
        return r.stdout.strip()
    except Exception:
        return ""

cards = pactl_json("list", "cards")
sinks = pactl_json("list", "sinks")
sources = pactl_json("list", "sources")
def_sink = pactl_str("get-default-sink")
def_source = pactl_str("get-default-source")

# Build port product name map: profile_suffix -> product_name
port_names = {}
for card in cards:
    for _pn, port in card.get("ports", {}).items():
        if port.get("type") not in ("HDMI", "DP"):
            continue
        product = port.get("properties", {}).get("device.product.name", "")
        if not product:
            continue
        for pname in port.get("profiles", []):
            suffix = pname.split(":", 1)[-1].split("+")[0]
            port_names[suffix] = product

def friendly_sink(name, desc):
    if "Built-in Audio" in desc:
        if "HDMI" in desc or "DisplayPort" in desc:
            suffix = name.rsplit(".", 1)[-1]
            return port_names.get(suffix, desc)
        return "内置扬声器"
    return desc or name

def friendly_source(name, desc):
    if "Built-in Audio" in desc:
        return "内置麦克风"
    return desc or name

def sel(text, icon, info):
    print(text + "\0icon\x1f" + icon + "\x1finfo\x1f" + info)

def label(text):
    print(text + "\0icon\x1f\x1fnonselectable\x1ftrue")

# ── Output devices ──
label("输出设备")

for s in sinks:
    name = s.get("name", "")
    desc = s.get("description", "")
    friendly = friendly_sink(name, desc)
    active = name == def_sink
    mark = "✓ " if active else "  "
    icon = "audio-card" if active else "audio-card"
    sel(f"{mark}{friendly}", icon, f"sink:{name}")

# Available-but-inactive card profiles (all output port types)
OUT_TYPES = {"Speaker", "Headphones", "HDMI", "DP"}
for card in cards:
    card_name = card.get("name", "")
    active_profile = card.get("active_profile", "")
    profiles = card.get("profiles", {})
    seen = set()
    active_out = active_profile.split("+")[0] if active_profile else ""
    for _pn, port in card.get("ports", {}).items():
        pt = port.get("type", "")
        if pt not in OUT_TYPES:
            continue
        if port.get("availability", "") == "not available":
            continue
        if active_profile in set(port.get("profiles", [])):
            continue
        if pt in ("HDMI", "DP"):
            friendly = port.get("properties", {}).get("device.product.name", "") or port.get("description", "")
        else:
            friendly = "内置扬声器"
        best, best_sc = "", -1
        for pname in port.get("profiles", []):
            if pname in seen or pname == active_profile:
                continue
            if pname.split("+")[0] == active_out:
                continue
            pi = profiles.get(pname, {})
            if not pi.get("available") or pi.get("sinks", 0) < 1:
                continue
            out_part = pname.split("+")[0]
            sc = (2 if "stereo" in out_part else 0) + (1 if "+input:" in pname else 0)
            if sc > best_sc:
                best, best_sc = pname, sc
        if best:
            seen.add(best)
            sel(f"  {friendly}", "audio-card", f"profile:{best}:{card_name}")

# ── Input devices ──
label("输入设备")

for s in sources:
    name = s.get("name", "")
    if name.endswith(".monitor"):
        continue
    desc = s.get("description", "")
    friendly = friendly_source(name, desc)
    active = name == def_source
    mark = "✓ " if active else "  "
    sel(f"{mark}{friendly}", "audio-input-microphone", f"source:{name}")

PYEOF
}

audio_select() {
    local info="${ROFI_INFO:-}"
    case "$info" in
        sink:*)
            local name="${info#sink:}"
            setsid -f bash -c '
                old_vol=$(pamixer --get-volume 2>/dev/null)
                pactl set-default-sink "$1" 2>/dev/null
                [ -n "$old_vol" ] && pamixer --set-volume "$old_vol" 2>/dev/null
                pamixer -u 2>/dev/null
                notify-send "音频" "输出已切换" 2>/dev/null
            ' _ "$name" >/dev/null 2>&1
            ;;
        source:*)
            local name="${info#source:}"
            setsid -f bash -c '
                pactl set-default-source "$1" 2>/dev/null
                notify-send "音频" "输入已切换" 2>/dev/null
            ' _ "$name" >/dev/null 2>&1
            ;;
        profile:*)
            local rest="${info#profile:}"
            # Profile names contain colons (e.g. output:hdmi-stereo+input:analog-stereo)
            # but card names never do (alsa_card.pci-XXXX_XX_XX.X), so split on
            # the LAST colon.
            local profile="${rest%:*}"
            local card="${rest##*:}"
            setsid -f bash -c '
                old_vol=$(pamixer --get-volume 2>/dev/null)
                pactl set-card-profile "$2" "$1" 2>/dev/null
                for _ in 1 2 3 4 5 6 7 8; do
                    sleep 0.25
                    new_sink=$(pactl list sinks short 2>/dev/null | awk "{print \$2}" | head -1)
                    [ -n "$new_sink" ] && break
                done
                if [ -n "$new_sink" ]; then
                    pactl set-default-sink "$new_sink" 2>/dev/null
                    [ -n "$old_vol" ] && pamixer --set-volume "$old_vol" 2>/dev/null
                    pamixer -u 2>/dev/null
                fi
                notify-send "音频" "输出已切换" 2>/dev/null
            ' _ "$profile" "$card" >/dev/null 2>&1
            ;;
    esac
}
