#!/usr/bin/env bash
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

official_count=$(printf '%s' "$official_json" | jq 'length')
aur_count=$(printf '%s' "$aur_json" | jq 'length')
total=$((official_count + aur_count))

jq -n \
    --arg last_check "$now" \
    --argjson total "$total" \
    --argjson official_count "$official_count" \
    --argjson aur_count "$aur_count" \
    --argjson official "$official_json" \
    --argjson aur "$aur_json" \
    '{last_check:$last_check,total:$total,official_count:$official_count,aur_count:$aur_count,official:$official,aur:$aur,error:null}' \
    > "$CACHE_FILE.tmp"
mv "$CACHE_FILE.tmp" "$CACHE_FILE"
