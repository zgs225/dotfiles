#!/usr/bin/env python3
"""Extract dominant colors from wezterm backdrop images and generate a Lua
palette file consumed by the tmux-theme switcher.

Usage:
    python3 scripts/gen-backdrop-palettes.py

Output:
    utils/backdrop_palettes.lua

Requires: ImageMagick 7 (magick) on PATH.
"""

import colorsys
import math
import re
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
BACKDROP_DIR = SCRIPT_DIR.parent / "backdrops"
OUTPUT_FILE = SCRIPT_DIR.parent / "utils" / "backdrop_palettes.lua"

NUM_COLORS = 32


def extract_colors(image_path: Path) -> list[tuple[int, int, int, int]]:
    """Return [(count, r, g, b), ...] sorted by pixel count descending."""
    result = subprocess.run(
        [
            "magick", str(image_path),
            "-alpha", "off",
            "-resize", "200x200",
            "-colors", str(NUM_COLORS),
            "-depth", "8",
            "-format", "%c",
            "histogram:info:-",
        ],
        capture_output=True, text=True, check=True,
    )
    colors = []
    for line in result.stdout.strip().splitlines():
        # Match RGB or RGBA tuples (alpha channel ignored)
        m = re.match(r"\s*(\d+):\s*\((\d+),(\d+),(\d+)(?:,\d+)?\)", line)
        if m:
            count = int(m.group(1))
            r, g, b = int(m.group(2)), int(m.group(3)), int(m.group(4))
            colors.append((count, r, g, b))
    colors.sort(key=lambda c: c[0], reverse=True)
    return colors


def rgb_to_hsl(r: int, g: int, b: int) -> tuple[float, float, float]:
    """Returns (h 0-360, s 0-100, l 0-100)."""
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return h * 360, s * 100, l * 100


def hsl_to_hex(h: float, s: float, l: float) -> str:
    """h 0-360, s 0-100, l 0-100 → #rrggbb"""
    r, g, b = colorsys.hls_to_rgb(h / 360, l / 100, s / 100)
    return f"#{int(r*255):02x}{int(g*255):02x}{int(b*255):02x}"


def hex_color(r: int, g: int, b: int) -> str:
    return f"#{r:02x}{g:02x}{b:02x}"


def ensure_readable(r: int, g: int, b: int, min_l: float = 50, min_s: float = 30) -> str:
    """Normalize a color into a readable accent: preserve hue, clamp lightness
    into a mid-tone band [min_l, min_l+12] (so it works as a block background
    with both light and dark text), and enforce a saturation floor.

    Crucially this *clamps* lightness rather than only raising it — a rice-paper
    cream (l~90) must be pulled DOWN into the mid-band, not left as-is."""
    h, s, l = rgb_to_hsl(r, g, b)
    l = max(min(l, min_l + 12), min_l)
    s = max(s, min_s)
    return hsl_to_hex(h, s, l)


def hue_distance(h1: float, h2: float) -> float:
    d = abs(h1 - h2) % 360
    return min(d, 360 - d)


def in_hue_range(h: float, lo: float, hi: float) -> bool:
    """Check if hue h is in the range [lo, hi] (wrapping around 360)."""
    if lo <= hi:
        return lo <= h <= hi
    else:
        return h >= lo or h <= hi


def build_palette(colors: list[tuple[int, int, int, int]]) -> dict[str, str]:
    if not colors:
        raise ValueError("No colors extracted")

    total_pixels = sum(c[0] for c in colors)

    annotated = []
    for count, r, g, b in colors:
        h, s, l = rgb_to_hsl(r, g, b)
        # Absolute chroma (max-min) is a far more reliable vividness measure
        # than HSL saturation, which inflates for near-white/near-black colors
        # (e.g. rice-paper cream #faeed3 has HSL-s ~80% but chroma only 39).
        chroma = max(r, g, b) - min(r, g, b)
        annotated.append({
            "count": count, "r": r, "g": g, "b": b,
            "h": h, "s": s, "l": l, "chroma": chroma,
            "ratio": count / total_pixels,
        })

    # -- bg: darkest color, darkened further in HSL
    darks = sorted(annotated, key=lambda c: c["l"])
    bg_src = darks[0]
    bg = hsl_to_hex(bg_src["h"], bg_src["s"] * 0.6, max(bg_src["l"] * 0.5, 3))

    # -- fg: lightest color; if nothing is truly light, synthesize
    lights = sorted(annotated, key=lambda c: c["l"], reverse=True)
    fg_src = lights[0]
    if fg_src["l"] < 45:
        fg = hsl_to_hex(bg_src["h"], 15, 78)
    else:
        fg = hsl_to_hex(fg_src["h"], min(fg_src["s"], 30), max(fg_src["l"], 75))

    # -- dim: mid-lightness, moderate saturation
    mids = [c for c in annotated if 15 < c["l"] < 60]
    if mids:
        dim_src = sorted(mids, key=lambda c: c["l"], reverse=True)[0]
        dim = hsl_to_hex(dim_src["h"], min(dim_src["s"], 25), max(dim_src["l"] + 15, 50))
    else:
        dim = hsl_to_hex(bg_src["h"], 12, 55)

    # -- accent scoring: absolute chroma is king; lightness gets a bell curve
    # centered on l=50 so near-white (rice paper) and near-black (ink) are
    # suppressed even if they happen to carry some hue. Pixel ratio is a weak
    # tie-breaker so a tiny vivid seal-red can still beat a large dull gray.
    def accent_score(c):
        chroma = c["chroma"]
        if chroma < 15:
            return 0
        bell = math.exp(-((c["l"] - 50) / 20.0) ** 2)
        return (chroma ** 1.3) * (c["ratio"] ** 0.25) * bell

    scored = sorted(annotated, key=accent_score, reverse=True)

    # Low threshold so muted ink-wash colors (e.g. moss green, chroma ~23) still
    # qualify — ensure_readable() will boost them into a vivid mid-tone. Rice-paper
    # cream is kept out by the lightness bell (score ~3.8), pure gray by the
    # chroma hard-floor above.
    MIN_ACCENT_SCORE = 12.0

    def pick(exclude_hues, min_score=MIN_ACCENT_SCORE, hue_range=None):
        """Pick best accent. If hue_range=(lo,hi) is given, only consider colors in that hue range."""
        for c in scored:
            if accent_score(c) < min_score:
                continue
            if any(hue_distance(c["h"], eh) < 30 for eh in exclude_hues):
                continue
            if hue_range and not in_hue_range(c["h"], hue_range[0], hue_range[1]):
                continue
            return c
        return None

    def synth(hue, s=52, l=55):
        """Synthesize a harmonious mid-tone accent at a given hue."""
        return hsl_to_hex(hue % 360, s, l)

    # Accent 1: most vivid (any hue)
    a1 = scored[0] if scored and accent_score(scored[0]) >= MIN_ACCENT_SCORE else None
    if a1:
        accent = ensure_readable(a1["r"], a1["g"], a1["b"], min_l=50, min_s=40)
        h1 = a1["h"]
    else:
        # No vivid color at all (pure ink wash) — fall back to a calm ink-blue
        accent = "#4a6b8a"
        h1 = 207

    used_hues = [h1]

    # Accent 2: different hue, else synthesize a triadic companion
    a2 = pick(used_hues)
    if a2:
        accent2 = ensure_readable(a2["r"], a2["g"], a2["b"], min_l=48, min_s=38)
        used_hues.append(a2["h"])
    else:
        accent2 = synth(h1 + 130)
        used_hues.append((h1 + 130) % 360)

    # Accent 3: yet another hue, else synthesize the third triadic point
    a3 = pick(used_hues)
    if a3:
        accent3 = ensure_readable(a3["r"], a3["g"], a3["b"], min_l=48, min_s=35)
    else:
        accent3 = synth(h1 + 230, s=48, l=55)

    # -- warm: a golden/amber tone (hue 20-60°), for bell indicators / message bg
    warm_src = pick([], hue_range=(20, 60))
    if warm_src:
        warm = ensure_readable(warm_src["r"], warm_src["g"], warm_src["b"], min_l=50, min_s=45)
    else:
        warm = hsl_to_hex(40, 65, 55)  # fallback golden

    # -- alert: a red/vivid tone (hue 340-20°), for current window / error indicators
    alert_src = pick([], hue_range=(340, 20))
    if alert_src:
        alert = ensure_readable(alert_src["r"], alert_src["g"], alert_src["b"], min_l=50, min_s=50)
    else:
        alert = hsl_to_hex(350, 70, 58)  # fallback vivid pink-red

    # -- border: slightly above bg in lightness
    border = hsl_to_hex(bg_src["h"], bg_src["s"] * 0.7, min(bg_src["l"] + 12, 30))

    return {
        "bg": bg,
        "fg": fg,
        "dim": dim,
        "accent": accent,
        "accent2": accent2,
        "accent3": accent3,
        "warm": warm,
        "alert": alert,
        "border": border,
    }


def main():
    if not BACKDROP_DIR.is_dir():
        print(f"Backdrop directory not found: {BACKDROP_DIR}", file=sys.stderr)
        sys.exit(1)

    images = sorted(
        p for p in BACKDROP_DIR.iterdir()
        if p.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp")
    )
    if not images:
        print("No backdrop images found.", file=sys.stderr)
        sys.exit(1)

    palettes: dict[str, dict[str, str]] = {}
    for img in images:
        print(f"Extracting: {img.name} ...", file=sys.stderr)
        colors = extract_colors(img)
        palettes[img.name] = build_palette(colors)

    # Generate Lua
    lines = [
        "-- Auto-generated by scripts/gen-backdrop-palettes.py",
        "-- Do not edit manually. Re-run after adding/removing backdrops.",
        "",
        "local palettes = {",
    ]
    for name, pal in palettes.items():
        lines.append(f'   ["{name}"] = {{')
        for role, hexval in pal.items():
            lines.append(f'      {role} = "{hexval}",')
        lines.append("   },")
    lines.append("}")
    lines.append("")
    lines.append("return palettes")
    lines.append("")

    OUTPUT_FILE.write_text("\n".join(lines))
    print(f"Written: {OUTPUT_FILE}", file=sys.stderr)

    for name, pal in palettes.items():
        print(f"\n  {name}:")
        for role, hexval in pal.items():
            print(f"    {role:>8s}  {hexval}")


if __name__ == "__main__":
    main()
