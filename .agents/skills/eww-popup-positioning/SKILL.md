---
name: eww-popup-positioning
description: Use when eww popups are misaligned with bar icons, flush against screen edges, or opening in the wrong location on X11
---

# Eww Popup Positioning

## Overview

Position eww popups relative to their clicked bar components and verify the result with X11 tools. This keeps popups on screen, aligned to the triggering icon, and at a consistent distance from screen edges.

## When to Use

- A popup is flush against the left or right screen edge.
- A popup opens far from the bar icon that triggered it.
- You want a popup to open below its icon instead of anchoring to a screen edge.
- The bar uses eww 0.5.0 on X11 inside a chezmoi-managed dotfiles repo.

## Core Pattern

1. **Change chezmoi source files**, not `~/.config/eww/` directly. Render with `chezmoi apply`.
2. **Make each popup's `defwindow` accept absolute coordinates** via `[pos_x pos_y]` and `anchor "top left"`.
3. **Compute position at open time** in `open-popup.sh` using `xdotool getmouselocation`, template-derived component widths, and popup widths.
4. **Prefer expanding right** from the component's left edge; fall back to expanding left from the component's right edge when there is not enough room to keep a right-edge gap.
5. **Restart eww through the window manager** with `i3-msg exec --no-startup-id ~/.config/eww/scripts/launch.sh`, never by calling `launch.sh` directly.
6. **Verify one component at a time** with `wmctrl -l -G` and `maim` screenshots before moving to the next.

## Quick Reference

| Task | Command |
|------|---------|
| Mouse position | `xdotool getmouselocation --shell` |
| Screen size | `xdotool getdisplaygeometry --shell` |
| Window position | `wmctrl -l -G` |
| Screenshot | `maim /tmp/popup-verify.png` |
| Restart eww | `i3-msg exec --no-startup-id ~/.config/eww/scripts/launch.sh` |
| Open popup with dynamic position | `eww open <name> --arg pos_x=...px --arg pos_y=...px` |

## Implementation

In `open-popup.sh` (templated via chezmoi):

```bash
compute_popup_left() {
  local mouse_x="$1" component_width="$2" popup_width="$3" screen_w="$4"
  local icon_left=$((mouse_x - component_width / 2))
  local icon_right=$((mouse_x + component_width / 2))

  # Prefer right expansion with a right-edge gap
  if [ $((icon_left + popup_width + RIGHT_GAP)) -le "$screen_w" ]; then
    echo "$icon_left"
  else
    # Fall back to expanding left from the component's right edge
    local left=$((icon_right - popup_width))
    [ "$left" -lt 0 ] && left=0
    echo "$left"
  fi
}
```

For icon-only components, use `iconSize + 12` as the component width. For text components like a time/calendar button, estimate the button width from the template font sizes.

## Common Mistakes

- Calling `launch.sh` directly. It starts `eww daemon` and can hang the calling shell; use `i3-msg exec` instead.
- Editing files under `~/.config/eww/` directly. They will be overwritten by the next `chezmoi apply`.
- Changing multiple popups at once and only testing at the end. eww positioning is fragile; verify each popup after its change.
- Using `eww reload` for geometry changes. Popup geometry is bound at open time; restart the daemon.
- Assuming `anchor "top right"` geometry offsets work as expected. Use `anchor "top left"` with absolute coordinates and `--arg` overrides.
