#!/bin/bash
set -uo pipefail

CACHE_DIR="$HOME/.cache/eww"
CACHE_FILE="$CACHE_DIR/updates.json"
CHECKING_FILE="$CACHE_DIR/updates.checking"
mkdir -p "$CACHE_DIR"

touch "$CHECKING_FILE"
trap 'rm -f "$CHECKING_FILE"' EXIT

now=$(date +'%Y-%m-%d %H:%M')

get_official() {
    if command -v checkupdates >/dev/null 2>&1; then
        timeout 120 checkupdates 2>/dev/null || true
    else
        pacman -Qu 2>/dev/null || true
    fi
}

get_aur() {
    if command -v paru >/dev/null 2>&1; then
        timeout 120 paru -Qua 2>/dev/null || true
    fi
}

# Local packages repacked outside both the repos and the AUR (currently just
# arto-bin, from eos-bootstrap's tasks/arto.yml). The helper prints a
# checkupdates-style line only when an upgrade is pending, and stays silent
# when it is up to date or offline.
get_extra() {
    if command -v arto-check-update >/dev/null 2>&1; then
        timeout 30 arto-check-update 2>/dev/null || true
    fi
}

parse_lines() {
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        name=$(printf '%s' "$line" | awk '{print $1}')
        old=$(printf '%s' "$line" | awk '{print $2}')
        new=$(printf '%s' "$line" | awk '{print $4}')
        jq -n --arg name "$name" --arg old "$old" --arg new "$new" \
            '{name:$name,old:$old,new:$new}'
    done
}

official_json=$(get_official | parse_lines | jq -s '.')
aur_json=$(get_aur | parse_lines | jq -s '.')
extra_json=$(get_extra | parse_lines | jq -s '.')

official_count=$(printf '%s' "$official_json" | jq 'length')
aur_count=$(printf '%s' "$aur_json" | jq 'length')
extra_count=$(printf '%s' "$extra_json" | jq 'length')
total=$((official_count + aur_count + extra_count))

jq -n \
    --arg last_check "$now" \
    --argjson total "$total" \
    --argjson official_count "$official_count" \
    --argjson aur_count "$aur_count" \
    --argjson extra_count "$extra_count" \
    --argjson official "$official_json" \
    --argjson aur "$aur_json" \
    --argjson extra "$extra_json" \
    '{last_check:$last_check,total:$total,official_count:$official_count,aur_count:$aur_count,extra_count:$extra_count,official:$official,aur:$aur,extra:$extra,error:null}' \
    > "$CACHE_FILE.tmp"
mv "$CACHE_FILE.tmp" "$CACHE_FILE"
