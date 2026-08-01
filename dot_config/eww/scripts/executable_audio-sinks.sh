#!/usr/bin/env bash
# Output devices as a JSON array. Friendly name = real Description, except the
# generic on-board "Built-in Audio" which we map to a localized label.
# HDMI/DP sinks that also say "Built-in Audio" get the monitor product name
# (e.g. "DELL U2720QM") from the card port properties instead.
# Also appends available-but-inactive card profiles (e.g. HDMI/DP monitor
# speakers sharing the same sound card) as type=profile entries.

current=$(pactl get-default-sink 2>/dev/null || echo "")

# Build port product name map: profile_suffix → product_name
# e.g. hdmi-stereo → DELL U2720QM
declare -A PORT_NAMES
while IFS=$'\t' read -r suffix product; do
    [ -n "$suffix" ] && PORT_NAMES["$suffix"]="$product"
done < <(pactl --format=json list cards 2>/dev/null | python3 -c "
import json, sys
try: cards = json.load(sys.stdin)
except Exception: sys.exit(0)
for card in cards:
    for _pn, port in card.get('ports', {}).items():
        if port.get('type') not in ('HDMI', 'DP'): continue
        product = port.get('properties', {}).get('device.product.name', '')
        if not product: continue
        for pname in port.get('profiles', []):
            suffix = pname.split(':', 1)[-1].split('+')[0]
            print(suffix + '\t' + product)
" 2>/dev/null)

json="[]"
while IFS=$'\t' read -r name desc; do
    [ -z "$name" ] && continue
    if [[ "$desc" == *"Built-in Audio"* ]]; then
        if [[ "$desc" == *"HDMI"* || "$desc" == *"DisplayPort"* ]]; then
            suffix="${name##*.}"
            friendly="${PORT_NAMES[$suffix]:-$desc}"
        else
            friendly="内置扬声器"
        fi
    elif [ -n "$desc" ]; then
        friendly="$desc"
    else
        friendly="$name"
    fi
    active=false
    [ "$name" = "$current" ] && active=true
    json=$(printf '%s' "$json" | jq -c --arg n "$name" --arg f "$friendly" --argjson a "$active" \
        '. + [{"name":$n,"friendly":$f,"active":$a,"type":"sink","card":""}]')
done < <(pactl list sinks 2>/dev/null | awk '
    /^[[:space:]]*Name:[[:space:]]*/        { sub(/^[[:space:]]*Name:[[:space:]]*/, ""); name=$0 }
    /^[[:space:]]*Description:[[:space:]]*/ { sub(/^[[:space:]]*Description:[[:space:]]*/, ""); print name "\t" $0; name="" }
')

# Append available-but-inactive card output profiles (all output port types)
profiles_json=$(pactl --format=json list cards 2>/dev/null | python3 -c "
import json, sys
try:
    cards = json.load(sys.stdin)
except Exception:
    sys.exit(0)
OUT_TYPES = {'Speaker', 'Headphones', 'HDMI', 'DP'}
out = []
for card in cards:
    active = card.get('active_profile', '')
    profiles = card.get('profiles', {})
    seen = set()
    active_out = active.split('+')[0] if active else ''
    for _pn, port in card.get('ports', {}).items():
        pt = port.get('type', '')
        if pt not in OUT_TYPES: continue
        if port.get('availability', '') == 'not available': continue
        if active in set(port.get('profiles', [])): continue
        if pt in ('HDMI', 'DP'):
            friendly = port.get('properties', {}).get('device.product.name', '') or port.get('description', '')
        else:
            friendly = '内置扬声器'
        best, best_sc = '', -1
        for pname in port.get('profiles', []):
            if pname in seen or pname == active: continue
            if pname.split('+')[0] == active_out: continue
            pi = profiles.get(pname, {})
            if not pi.get('available') or pi.get('sinks', 0) < 1: continue
            out_part = pname.split('+')[0]
            sc = (2 if 'stereo' in out_part else 0) + (1 if '+input:' in pname else 0)
            if sc > best_sc: best, best_sc = pname, sc
        if best:
            seen.add(best)
            out.append({'name': best, 'friendly': friendly, 'active': False,
                        'type': 'profile', 'card': card.get('name', '')})
print(json.dumps(out, ensure_ascii=False, separators=(',', ':')))
" 2>/dev/null) || profiles_json="[]"
[ -z "$profiles_json" ] && profiles_json="[]"

# Merge sinks + profiles
printf '%s' "$json" | jq -c --argjson p "$profiles_json" '. + $p'
