# Picom Glassmorphism Design

**Date:** 2026-07-06
**Scope:** `dot_config/picom/picom.conf`

## Goal

Transform the picom compositor config from a basic shadow/blur setup into a cohesive glassmorphism design: frosted glass windows, soft floating shadows, rounded corners, and snappy animations — inspired by macOS Sonoma / Windows 11 Mica aesthetics.

## Approach

Full glassmorphism (Option A): push all visual parameters toward the modern end of the spectrum, using picom v13's native rounded corner support and the efficient dual_kawase blur backend.

## Design

### Shadows — Floating Window Effect

| Parameter | Current | New |
|-----------|---------|-----|
| `shadow-radius` | 8 | 25 |
| `shadow-offset-x` | -4 | -15 |
| `shadow-offset-y` | -4 | -15 |
| `shadow-opacity` | 0.25 | 0.15 |
| `shadow-clipping` | (unset) | true |

**Shadow excludes** (add to existing list):
- `class_g = 'slop'`

The large radius + low opacity creates a soft ambient glow rather than a harsh drop shadow. `shadow-clipping` prevents shadow artifacts outside rounded corners.

### Rounded Corners

| Parameter | Current | New |
|-----------|---------|-----|
| `corner-radius` | 0 | 10 |
| `detect-rounded-corners` | false | true |

**Rounded corners exclude:**
- `class_g = 'slop'`
- `window_type = 'dock'`
- `window_type = 'desktop'`

**Corner radius rules:**
- `"0:class_g = 'Rofi'"` — Rofi applies its own rounding via CSS theme

10px is large enough to feel distinctly modern without cutting significantly into window content.

### Blur & Opacity — Frosted Glass

| Parameter | Current | New |
|-----------|---------|-----|
| `blur-strength` | 5 | 8 |
| `inactive-opacity` | 0.90 | 0.85 |
| `frame-opacity` | 0.9 | 0.80 |

**Blur excludes** (add to existing list):
- `class_g = 'slop'` (already present)

**Opacity rules** (add to existing list):
- `"85:class_g = 'WezTerm'"` — frosted terminal is a signature glassmorphism look

The blur + lower frame opacity creates the "frosted glass pane" look. Inactive windows become semi-transparent frosted panels; the active window stays crisp and readable.

### Animations & Misc

| Parameter | Current | New |
|-----------|---------|-----|
| `fade-in-step` | 0.03 | 0.06 |
| `fade-out-step` | 0.03 | 0.06 |
| `fade-delta` | 4 | 4 |
| `unredir-if-possible` | (unset) | false |

Snappier fades mean windows open in ~17 frames instead of ~33. `unredir-if-possible = false` prevents screen tearing with rounded corners + blur during fullscreen apps.

## What Does Not Change

- `backend = "glx"` — efficient, supports all required features
- `vsync = true` — prevents tearing
- `blur-method = "dual_kawase"` — most efficient blur algorithm
- `active-opacity = 1.0` — active window stays fully readable
- Existing blur/shadow excludes for Polybar, i3bar, Dunst
- `wintypes` block — tooltip/dock/dnd/popup/dropdown menu settings

## Risks

- **GPU load:** blur strength 8 + rounded corners + shadows is the heaviest configuration. dual_kawase is efficient, but on very old GPUs this may cause visible lag. Mitigate by reducing blur-strength to 6 if needed.
- **Shadow clipping:** `shadow-clipping = true` is relatively new. If it causes visual artifacts, remove it.
- **Rofi double-rounding:** If Rofi's CSS theme changes, the `corner-radius-rules` exclusion may need updating.

## Full Target Config

```conf
# Picom compositor config — glassmorphism

backend = "glx";
vsync = true;

# Shadows — soft floating effect
shadow = true;
shadow-radius = 25;
shadow-offset-x = -15;
shadow-offset-y = -15;
shadow-opacity = 0.15;
shadow-clipping = true;
shadow-exclude = [
    "class_g = 'Polybar'",
    "class_g = 'i3bar'",
    "name = 'Notification'",
    "class_g = 'Dunst'",
    "class_g = 'slop'",
];

# Fading — snappy
fading = true;
fade-in-step = 0.06;
fade-out-step = 0.06;
fade-delta = 4;

# Opacity — frosted glass layering
inactive-opacity = 0.85;
active-opacity = 1.0;
frame-opacity = 0.80;
inactive-opacity-override = false;

opacity-rule = [
    "90:class_g = 'i3bar'",
    "90:class_g = 'Polybar'",
    "100:class_g = 'Rofi'",
    "85:class_g = 'WezTerm'",
];

# Blur — heavy frosted glass
blur-background = true;
blur-method = "dual_kawase";
blur-strength = 8;
blur-background-frame = false;
blur-background-fixed = false;

blur-background-exclude = [
    "class_g = 'Polybar'",
    "class_g = 'i3bar'",
    "class_g = 'Dunst'",
    "class_g = 'slop'",
    "window_type = 'dock'",
    "window_type = 'desktop'",
];

# Rounded corners
corner-radius = 10;
detect-rounded-corners = true;

rounded-corners-exclude = [
    "class_g = 'slop'",
    "window_type = 'dock'",
    "window_type = 'desktop'",
];

corner-radius-rules = [
    "0:class_g = 'Rofi'",
];

# Misc
unredir-if-possible = false;
no-fading-openclose = false;
no-fading-destroyed-argb = true;
detect-client-opacity = true;
detect-transient = true;

# Window type settings
wintypes:
{
    tooltip = { fade = true; shadow = true; opacity = 0.90; focus = true; full-shadow = false; };
    dock = { shadow = false; };
    dnd = { shadow = false; };
    popup_menu = { opacity = 0.95; };
    dropdown_menu = { opacity = 0.95; };
};
```
