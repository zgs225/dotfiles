#!/usr/bin/env bash
# Offline (no hardware) regression test for the multi-monitor lock screen.
#
# What it does
#   * Fakes `xrandr` (prepended to PATH) so `lock-render.py` sees a controlled
#     monitor layout and never talks to the real X server (--listmonitors,
#     --query and --current all answer from the same fixture).
#   * Renders the chezmoi template into a throwaway HOME (falling back to the
#     deployed ~/.config copy) and points HOME at a throwaway dir with a
#     synthetic blue/teal gradient wallpaper + `.fehbg`, so neither the real
#     ~/.cache nor the real /usr/share/backgrounds is touched.
#   * Runs `lock-render.py --lock-image OUT` for three layouts and asserts:
#       a) output canvas == monitor bounding box
#       b) no gray(163) (= i3lock's default background) anywhere on any monitor
#       c) every monitor region is non-uniform (a wallpaper got composited)
#       d) the cinnabar seal colour appears on the primary screen only
#       e) base cache filename carries the layout hash (F1 != F2)
#
# Layout fixtures (xrandr --listmonitors lines copied verbatim):
#   F1 right-attached : eDP-1 2560x1600+0+0 (primary) + DP-1-1 3840x2160+2560+0
#   F2 left-attached  : eDP-1 2560x1600+0+0 (primary) + DP-1-1 3840x2160+(-3840)+0
#                       NOTE: real xrandr may print the negative offset either as
#                       `+-3840+0` or as `-3840+0`; the parser must accept both.
#                       The fixture below uses the `+-3840+0` spelling.
#   F3 single screen  : eDP-1 2560x1600+0+0 (primary)
#
# Exit codes: 0 all assertions pass, 1 failures, 77 skipped (environment missing).
#
# Scope: this file lives under scripts/ (chezmoi-ignored, never deployed).

set -uo pipefail

# shellcheck disable=SC2034  # kept for callers/debugging
REPO_DIR=$(cd "$(dirname "$0")/../.." && pwd)
LIVE_PY=${LIVE_PY:-$HOME/.config/i3/scripts/lock-render.py}
PY=${PY:-$HOME/.local/share/mise/shims/python3}

if [[ ! -f $LIVE_PY ]]; then
    echo "SKIP: $LIVE_PY not found (lock renderer not deployed here)"
    exit 77
fi
if [[ ! -x $PY ]]; then
    echo "SKIP: python interpreter not found/executable: $PY"
    exit 77
fi
for dep in magick identify; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "SKIP: required tool missing: $dep"
        exit 77
    fi
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf '  PASS  %s\n' "$*"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$*"; }

assert_eq() { # label expected actual
    if [[ $2 == "$3" ]]; then
        ok "$1 == $3"
    else
        bad "$1: expected $2, got $3"
    fi
}

assert_true() { # label expr-result
    if [[ $2 -eq 0 ]]; then
        ok "$1"
    else
        bad "$1"
    fi
}

# ---------------------------------------------------------------------------
# Fake xrandr
# ---------------------------------------------------------------------------
mkdir -p "$TMP/bin"
cat > "$TMP/bin/xrandr" <<'FAKE_XRANDR'
#!/bin/sh
# Offline xrandr stand-in driven by $FAKE_MONITORS.
# --listmonitors : print the fixture verbatim.
# --query        : derive a classic `xrandr --query` view from the same fixture
#                  (one connected line per monitor) so the renderer's fallback
#                  path is exercised with consistent geometry too.
# --current      : print only the screen line, with `current W x H` set to the
#                  fixture bounding box. The renderer sizes its canvas from the
#                  X root geometry, so the fake has to answer this too.
# anything else  : print nothing, succeed.
case "${1:-}" in
--listmonitors)
    printf '%s\n' "${FAKE_MONITORS:-}"
    exit 0
    ;;
--query|--current)
    printf '%s\n' "${FAKE_MONITORS:-}" | awk -v mode="${1:-}" '
        /^[[:space:]]*[0-9]+:/ {
            flags = $2; geom = $3; name = $4
            prim = (index(flags, "*") > 0) ? " primary" : ""
            line = geom
            gsub(/\/[0-9]+/, "", line)   # strip "/344" "/215" refresh parts
            gsub(/\+-/, "-", line)       # "+-3840" -> "-3840"
            n = split(line, p, /[x+]/)
            w = p[1] + 0; h = p[2] + 0; x = p[3] + 0; y = p[4] + 0
            if (cnt == 0) { minx = x; miny = y; maxx = x + w; maxy = y + h }
            if (x < minx) minx = x
            if (y < miny) miny = y
            if (x + w > maxx) maxx = x + w
            if (y + h > maxy) maxy = y + h
            names[cnt] = name; prims[cnt] = prim
            ws[cnt] = w; hs[cnt] = h; xs[cnt] = x; ys[cnt] = y
            cnt++
        }
        END {
            printf "Screen 0: minimum 8 x 8, current %d x %d, maximum 32767 x 32767\n", \
                maxx - minx, maxy - miny
            if (mode == "--query") {
                for (i = 0; i < cnt; i++)
                    printf "%s connected%s %dx%d+%d+%d\n", \
                        names[i], prims[i], ws[i], hs[i], xs[i], ys[i]
            }
        }'
    exit 0
    ;;
*)
    exit 0
    ;;
esac
FAKE_XRANDR
chmod +x "$TMP/bin/xrandr"

# ---------------------------------------------------------------------------
# Fake HOME + wallpaper
# ---------------------------------------------------------------------------
FAKEHOME="$TMP/home"
mkdir -p "$FAKEHOME/.config/i3/scripts"

# Source under test: prefer rendering the chezmoi template (the repo's real
# source of truth), fall back to the deployed copy when chezmoi is missing or
# the template cannot be rendered.
TEMPLATE="$REPO_DIR/dot_config/i3/scripts/lock-render.py.tmpl"
RENDERED="$FAKEHOME/.config/i3/scripts/lock-render.py"
RENDER_SRC=""
if command -v chezmoi >/dev/null 2>&1 && [[ -f $TEMPLATE ]]; then
    if (cd "$REPO_DIR" && chezmoi execute-template < "$TEMPLATE") \
        > "$RENDERED" 2>"$TMP/template.err" && [[ -s $RENDERED ]]; then
        RENDER_SRC="chezmoi execute-template $TEMPLATE (repo template)"
    else
        printf '  note  template render failed, falling back to %s\n' "$LIVE_PY"
        sed 's/^/        /' "$TMP/template.err"
        : > "$RENDERED"
    fi
fi
if [[ -z $RENDER_SRC ]]; then
    cp "$LIVE_PY" "$RENDERED"
    RENDER_SRC="deployed copy $LIVE_PY"
fi
chmod +x "$RENDERED"
printf 'renderer source: %s\n' "$RENDER_SRC"
if diff -q "$RENDERED" "$LIVE_PY" >/dev/null 2>&1; then
    printf '                matches deployed %s\n' "$LIVE_PY"
else
    printf '                DIFFERS from deployed %s (template ahead of ~/.config; run chezmoi apply)\n' \
        "$LIVE_PY"
fi
# poem list is read relative to the script; copy it so the renderer behaves
# exactly like the deployed one instead of falling back to a placeholder.
if [[ -f $(dirname "$LIVE_PY")/lock-poems.txt ]]; then
    cp "$(dirname "$LIVE_PY")/lock-poems.txt" "$FAKEHOME/.config/i3/scripts/lock-poems.txt"
fi

# Blue -> teal gradient: no point in it lands within +-3 of (163,163,163), so a
# gray(163) hit can only mean "i3lock background showing through".
if ! magick -size 2560x1600 gradient:'#1b3b6f-#7fd1c1' "$FAKEHOME/wall.png"; then
    echo "SKIP: failed to generate test wallpaper with magick"
    exit 77
fi
printf '#!/bin/sh\nfeh --no-fehbg --bg-fill %s\n' "'$FAKEHOME/wall.png'" \
    > "$FAKEHOME/.fehbg"

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
FIX_NAMES=(
    "F1-dual-right"
    "F2-dual-left"
    "F3-single"
)
FIX_EXPECT_CANVAS=(
    "6400x2160"
    "6400x2160"
    "2560x1600"
)
FIX_MONITORS=(
    $'Monitors: 2\n 0: +*eDP-1 2560/344x1600/215+0+0  eDP-1\n 1: +DP-1-1 3840/619x2160/348+2560+0  DP-1-1'
    $'Monitors: 2\n 0: +*eDP-1 2560/344x1600/215+0+0  eDP-1\n 1: +DP-1-1 3840/619x2160/348+-3840+0  DP-1-1'
    $'Monitors: 1\n 0: +*eDP-1 2560/344x1600/215+0+0  eDP-1'
)

# Sanity: the fake must shadow any real xrandr, otherwise geometry would be
# whatever this machine happens to have attached.
FAKE_XRANDR_PATH=$(PATH="$TMP/bin:$PATH" command -v xrandr)
assert_eq "fake xrandr shadows real xrandr" "$TMP/bin/xrandr" "$FAKE_XRANDR_PATH"

# ---------------------------------------------------------------------------
# Monitor parsing (same grammar the renderer has to understand)
#   " 1: +DP-1-1 3840/619x2160/348+-3840+0  DP-1-1"
#   group1 = flags (+/*), group2 = name, group3 = w, group4 = h,
#   group5 = x (may be "+-3840" or "-3840"), group6 = y
# ---------------------------------------------------------------------------
MON_NAME=()
MON_X=()
MON_Y=()
MON_W=()
MON_H=()
MON_PRIMARY=()
MINX=0
MINY=0
VW=0
VH=0

parse_monitors() { # fixture-string
    local fixture=$1 line flags name w h xs ys
    local re='^[[:space:]]*[0-9]+:[[:space:]]+([+*]+)([^[:space:]]+)[[:space:]]+([0-9]+)/[0-9]+x([0-9]+)/[0-9]+([-+][-0-9]+)([-+][-0-9]+)'
    MON_NAME=(); MON_X=(); MON_Y=(); MON_W=(); MON_H=(); MON_PRIMARY=()
    while IFS= read -r line; do
        [[ $line =~ $re ]] || continue
        flags=${BASH_REMATCH[1]}
        name=${BASH_REMATCH[2]}
        w=${BASH_REMATCH[3]}
        h=${BASH_REMATCH[4]}
        xs=${BASH_REMATCH[5]//+/} # "+-3840" -> "-3840"; "+2560" -> "2560"
        ys=${BASH_REMATCH[6]//+/}
        MON_NAME+=("$name")
        MON_W+=("$w")
        MON_H+=("$h")
        MON_X+=("$((xs))")
        MON_Y+=("$((ys))")
        if [[ $flags == *"*"* ]]; then MON_PRIMARY+=("1"); else MON_PRIMARY+=("0"); fi
    done <<< "$fixture"

    local i minx=0 miny=0 maxx=0 maxy=0
    for i in "${!MON_NAME[@]}"; do
        ((i == 0)) && { minx=${MON_X[$i]}; miny=${MON_Y[$i]}; }
        ((MON_X[i] < minx)) && minx=${MON_X[$i]}
        ((MON_Y[i] < miny)) && miny=${MON_Y[$i]}
        ((MON_X[i] + MON_W[i] > maxx)) && maxx=$((MON_X[i] + MON_W[i]))
        ((MON_Y[i] + MON_H[i] > maxy)) && maxy=$((MON_Y[i] + MON_H[i]))
    done
    MINX=$minx; MINY=$miny
    VW=$((maxx - minx)); VH=$((maxy - miny))
}

# ---------------------------------------------------------------------------
# Image helpers
# ---------------------------------------------------------------------------
PX_R=0
PX_G=0
PX_B=0

parse_pixel() { # "srgb(31,64,115)" | "gray(163)" | "srgb(11.9%,25%,44.6%)"
    read -r PX_R PX_G PX_B < <(printf '%s\n' "$1" | awk '
        {
            pct = (index($0, "%") > 0)
            n = 0; r = 0; g = 0; b = 0; s = $0
            while (match(s, /[0-9]+(\.[0-9]+)?/)) {
                v = substr(s, RSTART, RLENGTH) + 0
                s = substr(s, RSTART + RLENGTH)
                n++
                if (n == 1) r = v
                else if (n == 2) g = v
                else if (n == 3) b = v
            }
            if (n == 1) { g = r; b = r }
            if (pct) { r *= 2.55; g *= 2.55; b *= 2.55 }
            printf "%.2f %.2f %.2f\n", r, g, b
        }')
}

near_gray163() { # r g b -> 0 when all channels are within +-3 of 163
    awk -v r="$1" -v g="$2" -v b="$3" 'BEGIN {
        dr = r - 163; if (dr < 0) dr = -dr
        dg = g - 163; if (dg < 0) dg = -dg
        db = b - 163; if (db < 0) db = -db
        exit !(dr <= 3 && dg <= 3 && db <= 3)
    }'
}

seal_count() { # img x y w h -> pixels close to the seal colour
    local img=$1 x=$2 y=$3 w=$4 h=$5 patch
    patch="$TMP/patch-$RANDOM.png"
    if ! magick "$img" -crop "${w}x${h}+${x}+${y}" +repage "$patch" 2>/dev/null; then
        printf '0\n'
        return
    fi
    magick "$patch" -fuzz 18% -fill white -opaque "#$SEAL_HEX" \
        -fill black +opaque white -format '%[fx:mean*w*h]' info: 2>/dev/null
    rm -f "$patch"
}

region_inside() { # x y w h cw ch -> 0 when the whole region fits the canvas
    local x=$1 y=$2 w=$3 h=$4 cw=$5 ch=$6
    ((x >= 0 && y >= 0 && x + w <= cw && y + h <= ch))
}

# ---------------------------------------------------------------------------
# Seal colour, taken from the script under test
# ---------------------------------------------------------------------------
SEAL_HEX=$(sed -n 's/^SEAL_COLOR = "#\([0-9A-Fa-f]\{6\}\)".*/\1/p' \
    "$FAKEHOME/.config/i3/scripts/lock-render.py" | head -1 | tr 'A-F' 'a-f')
if [[ -z $SEAL_HEX ]]; then
    bad "could not find SEAL_COLOR in $RENDERED"
    SEAL_HEX="a0522d"
else
    ok "seal colour from script under test: #$SEAL_HEX"
fi

# ---------------------------------------------------------------------------
# Run fixtures
# ---------------------------------------------------------------------------
BASE_F1=()

for idx in "${!FIX_NAMES[@]}"; do
    name=${FIX_NAMES[$idx]}
    expect_canvas=${FIX_EXPECT_CANVAS[$idx]}
    fixture=${FIX_MONITORS[$idx]}
    out="$TMP/out-$name.jpg"

    printf '\n=== %s (expect canvas %s) ===\n' "$name" "$expect_canvas"
    printf '%s\n' "$fixture" | sed 's/^/    /'

    parse_monitors "$fixture"
    assert_eq "[$name] fixture monitor count" \
        "$(printf '%s\n' "$fixture" | grep -c '^ *[0-9]\+:')" "${#MON_NAME[@]}"
    assert_eq "[$name] fixture bounding box (parsed)" "$expect_canvas" "${VW}x${VH}"

    if ! env HOME="$FAKEHOME" PATH="$TMP/bin:$PATH" FAKE_MONITORS="$fixture" \
        "$PY" "$RENDERED" \
        --lock-image "$out" >"$TMP/run-$name.log" 2>&1; then
        bad "[$name] renderer exited non-zero (see log below)"
        sed 's/^/        /' "$TMP/run-$name.log"
        continue
    fi
    if [[ ! -s $out ]]; then
        bad "[$name] no output image at $out"
        continue
    fi

    # a) canvas size == bounding box of all monitors
    got_canvas=$(identify -format '%wx%h' "$out" 2>/dev/null)
    assert_eq "[$name] canvas size" "$expect_canvas" "$got_canvas"

    canvas_w=${got_canvas%x*}
    canvas_h=${got_canvas#*x}

    for m in "${!MON_NAME[@]}"; do
        rx=$((MON_X[m] - MINX))
        ry=$((MON_Y[m] - MINY))
        rw=${MON_W[$m]}
        rh=${MON_H[$m]}
        label="[$name] ${MON_NAME[$m]} ${rw}x${rh}+${rx}+${ry}"

        # b) no gray(163) at four inset corners + centre
        if ! region_inside "$rx" "$ry" "$rw" "$rh" "$canvas_w" "$canvas_h"; then
            bad "$label region outside ${canvas_w}x${canvas_h} canvas (grey/blank area)"
            continue
        fi
        pts=(
            "$((rx + 20)),$((ry + 20))"
            "$((rx + rw - 21)),$((ry + 20))"
            "$((rx + 20)),$((ry + rh - 21))"
            "$((rx + rw - 21)),$((ry + rh - 21))"
            "$((rx + rw / 2)),$((ry + rh / 2))"
        )
        for pt in "${pts[@]}"; do
            IFS=, read -r sx sy <<< "$pt"
            px=$(magick "$out" -format "%[pixel:p{$sx,$sy}]" info: 2>/dev/null)
            if [[ -z $px ]]; then
                bad "$label could not sample pixel at ($sx,$sy)"
                continue
            fi
            parse_pixel "$px"
            if near_gray163 "$PX_R" "$PX_G" "$PX_B"; then
                bad "$label pixel($sx,$sy)=$px is gray(163) (uncovered canvas)"
            else
                ok "$label pixel($sx,$sy)=$px not gray(163)"
            fi
        done

        # c) region is not a flat fill: 200x200 centre patch must vary
        cx=$((rx + rw / 2 - 100))
        cy=$((ry + rh / 2 - 100))
        sd=$(magick "$out" -crop "200x200+${cx}+${cy}" +repage \
            -format '%[fx:standard_deviation]' info: 2>/dev/null)
        if [[ -z $sd ]]; then
            bad "$label could not compute standard deviation"
        else
            assert_true "$label 200x200 patch standard_deviation=$sd > 0.01" \
                "$(awk -v s="$sd" 'BEGIN { exit !(s + 0 > 0.01) }'; echo $?)"
        fi

        # d) cinnabar seal only on the primary screen
        cnt=$(seal_count "$out" "$rx" "$ry" "$rw" "$rh")
        cnt=${cnt:-0}
        if [[ ${MON_PRIMARY[$m]} == 1 ]]; then
            assert_true "$label seal-colour pixels=$cnt > 100" \
                "$(awk -v c="$cnt" 'BEGIN { exit !(c + 0 > 100) }'; echo $?)"
        else
            assert_true "$label seal-colour pixels=$cnt == 0" \
                "$(awk -v c="$cnt" 'BEGIN { exit !(c + 0 == 0) }'; echo $?)"
        fi
    done

    # e) base cache: one file per (wallpaper, layout) with the layout hash suffix
    mapfile -t bases < <(ls "$FAKEHOME"/.cache/lockscreen/base-*.png 2>/dev/null)
    if ((${#bases[@]} == 0)); then
        bad "[$name] no base-*.png cache files under $FAKEHOME/.cache/lockscreen"
    else
        for b in "${bases[@]}"; do
            bn=$(basename "$b")
            if [[ $bn =~ ^base-[0-9a-f]+-[0-9a-f]{8}\.png$ ]]; then
                ok "[$name] base cache name matches base-<wallpaper-hash>-<layout-hash8>: $bn"
            else
                bad "[$name] base cache name lacks layout hash: $bn"
            fi
        done
        if ((idx == 0)); then
            BASE_F1=("${bases[@]##*/}")
        elif ((idx == 1)); then
            new_layout=0
            for b in "${bases[@]}"; do
                bn=${b##*/}
                [[ $bn =~ ^base-[0-9a-f]+-[0-9a-f]{8}\.png$ ]] || continue
                skip=0
                for old in "${BASE_F1[@]}"; do
                    [[ $bn == "$old" ]] && skip=1
                done
                ((skip == 0)) && new_layout=1
            done
            assert_true "[$name] layout hash changed base cache name vs F1 (${BASE_F1[*]:-none})" \
                "$((new_layout == 1 ? 0 : 1))"
        fi
    fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n===== SUMMARY =====\n'
printf 'PASS: %d  FAIL: %d\n' "$PASS" "$FAIL"
if ((FAIL > 0)); then
    exit 1
fi
exit 0
