# Picom v13 Rules Migration — popup-scrim Blur Fix

> Status: DRAFT — pending implementation
> Created: 2026-07-25
> Related: `dot_config/picom/picom.conf`, `dot_config/eww/components/popup-scrim.yuck.tmpl`

---

## 1. Problem

The eww `popup-scrim` window (a fullscreen transparent click-catcher opened behind popups)
causes picom to apply background blur to everything beneath it. The scrim's CSS background is
`transparent` (ARGB alpha=0), so it should be invisible — but picom v13's `blur-background`
pass treats it as a semi-transparent window and blurs the desktop/terminals behind it.

The existing `blur-background-exclude` rule for the scrim **does not work** in picom v13.
This was verified by isolation experiments (2026-07-25):

- With `inactive-opacity` temporarily set to 1.0 (eliminating WezTerm's own unfocused blur),
  opening a popup (scrim appears) still produces ~5.5% pixel difference vs. the focused
  baseline — confirming the scrim itself triggers a blur pass.
- Changing the scrim's `opacity-rule` from `1` (1%) to `100` (100%) made no difference.
- Changing `blur-background-exclude` condition format (`name =`, `name *=`, combined
  `class_g && name`) made no difference.

Root cause: picom v13 man page lists `--blur-background-exclude` as **superseded** by the
`rules` system. The old-style exclude list is silently ignored.

---

## 2. Goal

Make the popup-scrim window completely invisible to picom's blur pass — no background blur
behind the scrim, while all other windows (popups, terminals, etc.) retain their blur as
designed.

---

## 3. Constraint: picom v13 Forces Full Migration

Picom v13's man page states:

> If window rules option is used, none of the above options will have any effect.

The "above options" include **all** per-window overrides currently in use:

- `shadow-exclude`
- `blur-background-exclude`
- `rounded-corners-exclude`
- `corner-radius-rules`
- `opacity-rule`
- `inactive-opacity` / `active-opacity` / `inactive-opacity-override`
- `wintypes`

There is no way to fix the scrim blur without enabling `rules`, and enabling `rules`
silently disables all old-style per-window options. Therefore the migration must convert
**every** per-window override to the `rules` format in a single atomic change.

---

## 4. Technical Plan

### 4.1 Direct 1:1 translations (no behavior change)

| Old-style option | Condition | Rules equivalent |
|---|---|---|
| `shadow-exclude` | `name = 'Eww - bar'` | `shadow = false` |
| `shadow-exclude` | `name = 'Eww - popup-scrim'` | `shadow = false` |
| `shadow-exclude` | `name = 'Notification'` | `shadow = false` |
| `shadow-exclude` | `class_g = 'slop'` | `shadow = false` |
| `blur-background-exclude` | `name = 'Eww - popup-scrim'` | `blur-background = false` |
| `blur-background-exclude` | `class_g = 'slop'` | `blur-background = false` |
| `blur-background-exclude` | `window_type = 'desktop'` | `blur-background = false` |
| `rounded-corners-exclude` | `name = 'Eww - popup-scrim'` | `corner-radius = 0` |
| `rounded-corners-exclude` | `name = 'Eww - bar'` | `corner-radius = 0` |
| `rounded-corners-exclude` | `class_g = 'slop'` | `corner-radius = 0` |
| `rounded-corners-exclude` | `window_type = 'desktop'` | `corner-radius = 0` |
| `corner-radius-rules` | `class_g = 'Rofi'` | `corner-radius = 0` |
| `opacity-rule` | `name = 'Eww - popup-scrim'` | `opacity = 0.01` |
| `opacity-rule` | `name = 'Eww - bar'` | `opacity = 1.0` |
| `opacity-rule` | `class_g = 'Rofi'` | `opacity = 1.0` |
| `opacity-rule` | `class_g = 'WezTerm'` | `opacity = 0.85` |
| `opacity-rule` | `class_g = 'Dunst'` | `opacity = 1.0` |
| `wintypes` | `dock` | `shadow = false` |
| `wintypes` | `dnd` | `shadow = false` |
| `wintypes` | `popup_menu` | `opacity = 1.0` |
| `wintypes` | `dropdown_menu` | `opacity = 1.0` |
| `wintypes` | `tooltip` | `opacity = 0.90; full-shadow = false` |

### 4.2 Focus-based opacity (replaces inactive-opacity / active-opacity)

```
{ match = "focused";  opacity = 0.85; }
{ match = "!focused"; opacity = 0.70; }
```

### 4.3 New rule: fullscreen corner-radius fix

```
{ match = "fullscreen"; corner-radius = 0; }
```

This compensates for picom v13's behavioral change when `rules` is enabled (see Risk #1).

### 4.4 Rule ordering discipline

Rules are applied top-to-bottom; later matches **override** earlier ones for the same
property. The order must be:

1. General defaults (focused/!focused opacity)
2. Window-type defaults (tooltip, dock, dnd, popup_menu, dropdown_menu)
3. Desktop wallpaper exclusions
4. Tool-specific exclusions (slop, Dunst, Rofi, WezTerm)
5. Eww-specific rules (bar, scrim)
6. Fullscreen override (must come after corner-radius rules)

---

## 5. Risks

### 5.1 HIGH — Fullscreen windows gain rounded corners

Picom v13 man page:

> When the window rules option is used, the compositor will also behave somewhat
> differently in certain cases. One such case is that fullscreen windows will no longer
> have their rounded corners disabled by default.

**Impact**: Fullscreen games, videos, terminals would get 5px rounded corners — four
notches at screen corners, visually jarring.

**Mitigation**: Explicit `fullscreen → corner-radius = 0` rule (section 4.3). Must be
placed after any rule that sets corner-radius, so it takes final precedence.

**Verification**: Open a fullscreen WezTerm or video player, screenshot corners.

### 5.2 MEDIUM — Rule order errors cause silent opacity override

Old-style `opacity-rule` uses first-match-wins. Rules use last-match-wins. If a specific
rule (e.g. WezTerm 0.85) is placed **after** a general rule (e.g. !focused 0.70), the
general rule would override the specific one for unfocused WezTerm.

**Current impact**: None — the 5 existing opacity-rule conditions are mutually exclusive.

**Future risk**: Any new rule added without attention to ordering could silently break
opacity for existing windows.

**Mitigation**: Strict ordering discipline (section 4.4). Comment each rule with its
purpose.

### 5.3 LOW — Window self-set opacity overridden

Old-style `inactive-opacity-override = false` means picom respects `_NET_WM_WINDOW_OPACITY`
set by applications. Rules have no equivalent — an explicit `opacity` in a matching rule
unconditionally overrides the window property.

**Current impact**: Verified via xprop that WezTerm does NOT set `_NET_WM_WINDOW_OPACITY`.
No application on the current desktop is known to set it.

**Future risk**: If an application sets custom transparency, it will be overridden by the
focused/!focused rules.

**Mitigation**: No perfect compensation exists in the rules system. Accept the semantic
narrowing. If needed in the future, add per-application rules with higher priority.

### 5.4 LOW — Tooltip `focus = true` semantic lost

Old-style `wintypes` tooltip entry had `focus = true`, which made picom treat tooltip
windows as focusable (affecting inactive-opacity judgment). Rules have no `focus` key.

**Current impact**: Tooltip opacity is explicitly set to 0.90 in the rules, which overrides
the focused/!focused general rules (if placed after them). The original purpose of
`focus = true` was to prevent tooltips from being dimmed by inactive-opacity — the explicit
opacity achieves the same effect.

**Mitigation**: Ensure tooltip rule is placed after focused/!focused rules.

### 5.5 LOW — Focused detection default change

`mark-wmwin-focused` and `mark-ovredir-focused` control how picom determines window focus.
Current config uses old-style defaults. The rules system may change these defaults.

**Current impact**: Key windows (bar, popups, Rofi, Dunst) all have explicit opacity rules
that override focus-based opacity, so they are unaffected by focus detection changes.

**Mitigation**: Monitor for unexpected opacity changes on override-redirect windows (rofi,
dmenu, eww popups) after migration.

---

## 6. Verification Plan

After migration, run each check in order. All must pass before committing.

### 6.1 Scrim blur eliminated (the primary goal)

```bash
# Isolated test: set inactive-opacity=1.0 temporarily to remove WezTerm's own blur
# Capture focused baseline
maim -g 600x300+200+500 /tmp/baseline.png

# Open popup (scrim appears)
~/.config/eww/scripts/open-popup.sh control-center; sleep 1
maim -g 600x300+200+500 /tmp/with-scrim.png
~/.config/eww/scripts/open-popup.sh close

# Pixel diff should be ~0 (was ~5.5% before fix)
magick /tmp/baseline.png /tmp/with-scrim.png -compose difference -composite \
  -format "mean-diff=%[fx:mean]\n" info:
# Expected: mean-diff < 0.01
```

### 6.2 Popup blur still works

```bash
# Open popup, visually confirm frosted glass behind the popup panel
~/.config/eww/scripts/open-popup.sh control-center; sleep 1
maim /tmp/popup-blur.png
# Eyeball: popup area should show blurred background through glass
```

### 6.3 Bar unchanged

```bash
# Bar should be fully opaque, no shadow, no rounded corners
maim -g 2560x64+0+0 /tmp/bar.png
# Eyeball: solid dark bar, sharp edges, no corner rounding
```

### 6.4 Terminal opacity

```bash
# WezTerm focused: ~85% opacity
# WezTerm unfocused: ~70% opacity
# Visual comparison with pre-migration screenshots
```

### 6.5 Fullscreen corner-radius

```bash
# Open WezTerm fullscreen (or any app)
# Screenshot corners — must be square, no 5px rounding
```

### 6.6 Shadow exclusions

```bash
# Bar: no shadow (check edges against wallpaper)
# Scrim: no shadow
# Dunst notifications: no shadow
# slop selection: no shadow
```

### 6.7 Rofi

```bash
# Launch rofi — must be fully opaque, no rounded corners (self-drawn)
rofi -show drun
```

### 6.8 Picom warnings

```bash
# Restart picom with stderr capture
kill $(pgrep -x picom); sleep 1
picom --config ~/.config/picom/picom.conf 2>/tmp/picom-warn.log & disown; sleep 2
cat /tmp/picom-warn.log
# Expected: empty (no "superseded" or "deprecated" warnings)
```

### 6.9 SCSS purity (unrelated but cheap)

```bash
LC_ALL=C grep -rPn '[^\x00-\x7F]' ~/.config/eww/styles/*.scss
# Expected: no output
```

---

## 7. Rollback

If any verification fails and cannot be quickly fixed:

```bash
# Revert picom config to pre-migration version
git checkout HEAD~1 -- dot_config/picom/picom.conf
chezmoi apply --force
kill $(pgrep -x picom); sleep 1
picom --config ~/.config/picom/picom.conf & disown
```

The migration is a single-file change (`dot_config/picom/picom.conf`), so rollback is
trivial.

---

## 8. Non-goals

- Migrating to picom v13's animation system (`animations` block). Out of scope.
- Changing blur strength, shadow parameters, or fade timing. These are global options
  unaffected by the migration.
- Adding new visual effects. This is a pure bug-fix migration.
