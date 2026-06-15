# i3 Software Stack Design

**Date:** 2026-06-15
**Status:** Draft

## Overview

Configure the full i3wm desktop environment as chezmoi-managed dotfiles, using Catppuccin Mocha as the unified color scheme across all components.

## Context

- **Platform:** Arch Linux
- **Window manager:** Standard i3-wm (not i3-gaps)
- **dotfiles manager:** chezmoi (config files only, no package management)
- **Auto-launch:** Already configured — `dot_xinitrc` execs i3, `dot_zprofile.tmpl` auto-starts X on tty1

## Color Scheme

**Catppuccin Mocha** — official 26-color palette defined in `.chezmoi.yaml.tmpl` under `data.colors`. All templated config files reference these values via `{{ .colors.<name> }}`.

## File Structure

```
dot_config/
├── i3/
│   └── config.tmpl              # i3 main config
├── polybar/
│   ├── config.ini.tmpl         # bar + module config
│   └── launch.sh               # startup script (multi-monitor aware)
├── rofi/
│   └── config.rasi.tmpl        # launcher config
├── dunst/
│   └── dunstrc.tmpl            # notification daemon config
├── picom/
│   └── picom.conf              # compositor config (static, no template)
├── gtk-3.0/
│   └── settings.ini.tmpl       # GTK3 theme settings
├── gtk-4.0/
│   └── settings.ini.tmpl       # GTK4 theme settings

dot_local/share/
├── wallpapers/
│   └── default.jpg             # default wallpaper
└── bin/
    └── lock.sh                 # i3lock wrapper script
```

### Existing files to update

| File | Change |
|------|--------|
| `.chezmoi.yaml.tmpl` | Add `data.colors` with Catppuccin Mocha palette |

## Component Design

### 1. i3 Configuration (`dot_config/i3/config.tmpl`)

| Aspect | Decision |
|--------|----------|
| Mod key | Mod4 (Super) |
| Font | pango:Noto Sans CJK SC 10 |
| Workspaces | 1-10, no custom names |
| Window borders | 2px, colors from Catppuccin palette |
| Gaps | None (standard i3) |
| Floating modifier | $mod+Shift+Space |
| Focus | Mouse follows focus disabled; focus follows mouse enabled |

**Keybindings:**
| Binding | Action |
|---------|--------|
| $mod+Return | Launch terminal (wezterm) |
| $mod+d | Rofi drun (app launcher) |
| $mod+Tab | Rofi window switcher |
| $mod+Shift+q | Kill focused window |
| $mod+Shift+l | Lock screen (lock.sh) |
| $mod+Shift+e | Exit i3 prompt |
| $mod+r | Resize mode |
| Print | Screenshot full screen (maim ~/Pictures/screenshots/) |
| Shift+Print | Screenshot selection (maim -s ~/Pictures/screenshots/) |
| $mod+Shift+c | Reload i3 config |
| $mod+Shift+r | Restart i3 in-place |

**Autostart (via `exec_always`):**
1. `feh --randomize --bg-fill ~/.local/share/wallpapers/` — set wallpaper
2. `picom --config ~/.config/picom/picom.conf` — compositor
3. `~/.config/polybar/launch.sh` — status bar
4. `dunst` — notification daemon

### 2. Polybar (`dot_config/polybar/`)

- Single bar at top of screen
- Height: 30px
- Font: Noto Sans CJK SC 10
- Icons: Unicode symbols (no external icon font required)

**Modules (left to right):**
1. `i3` — workspace indicator
2. `xwindow` — focused window title
3. `cpu` — CPU usage
4. `memory` — memory usage
5. `network` — network (NetworkManager-based)
6. `pulseaudio` — volume (PulseAudio/PipeWire)
7. `battery` — battery status (auto-hidden on desktop)
8. `date` — date and time

**`launch.sh`:** Kills existing polybar instances, detects monitors via `polybar --list-monitors`, launches one bar per monitor.

### 3. Rofi (`dot_config/rofi/config.rasi.tmpl`)

- Mode: drun (application launcher)
- Theme: Catppuccin Mocha rofi theme (adapted from official port)
- Window switcher: separate mode bound to $mod+Tab
- Font: Noto Sans CJK SC 12
- Icon theme: Papirus

### 4. Dunst (`dot_config/dunst/dunstrc.tmpl`)

- Position: top-right
- Font: Noto Sans CJK SC 10
- Timeout: 5 seconds
- Max notifications visible: 3
- Colors: Catppuccin Mocha for low/normal/critical urgency
- Geometry: 300x5-20+20 (width 300, 20px offset from top-right)

### 5. Picom (`dot_config/picom/picom.conf`)

- Backend: glx (or xrender fallback)
- VSync: true
- Fading: windows and menus, 200ms
- Shadows: enabled, subtle
- Blur: disabled (performance)
- Rounded corners: disabled
- Transparency: 90% for inactive windows
- Exclude: i3bar/polybar from shadows and fading

### 6. i3lock (`dot_local/share/bin/lock.sh`)

Shell script that calls `i3lock` with Catppuccin Mocha colors:
- Inside color, ring color, key highlight, backspace highlight
- Take screenshot with maim, blur with ImageMagick, use as lock background

### 7. GTK Theme (`dot_config/gtk-3.0/settings.ini.tmpl`, `dot_config/gtk-4.0/settings.ini.tmpl`)

- Theme: Catppuccin-Mocha-Standard-Lavender-Dark
- Icon theme: Papirus-Dark
- Font: Noto Sans CJK SC 10
- Cursor: Adwaita (default)

### 8. Wallpaper

- Single default wallpaper stored at `~/.local/share/wallpapers/default.jpg`
- feh randomly selects from the directory at startup
- Users can add more wallpapers to the directory manually

## chezmoi Template Strategy

- `.tmpl` suffix used for files that need color substitution
- Static files (picom.conf, launch.sh, lock.sh) use `run_` prefix or are treated as scripts
- `picom.conf` is static because colors are not referenced by picom itself
- `launch.sh` and `lock.sh` are executable scripts stored in `dot_local/share/bin/`

## Non-Goals

- Package installation (handled outside chezmoi)
- arandr screenlayout scripts (generated per-machine via arandr GUI, could optionally be symlinked)
- lxappearance config (used interactively, writes to GTK settings)
- Multi-monitor specific configurations beyond polybar launch detection
- Keyboard layout configuration (handled via `localectl` or `setxkbmap` per-machine)

## Catppuccin Mocha Palette

The following 26 colors are defined in `data.colors`:

| Variable | Hex | Usage |
|----------|-----|-------|
| `rosewater` | #f5e0dc | subtle accent |
| `flamingo` | #f2cdcd | |
| `pink` | #f5c2e7 | |
| `mauve` | #cba6f7 | |
| `red` | #f38ba8 | errors, critical |
| `maroon` | #eba0ac | |
| `peach` | #fab387 | |
| `yellow` | #f9e2af | warnings |
| `green` | #a6e3a1 | success, battery full |
| `teal` | #94e2d5 | |
| `sky` | #89dceb | |
| `sapphire` | #74c7ec | |
| `blue` | #89b4fa | links, info |
| `lavender` | #b4befe | accent primary |
| `text` | #cdd6f4 | primary text |
| `subtext1` | #bac2de | secondary text |
| `subtext0` | #a6adc8 | muted text |
| `overlay2` | #9399b2 | |
| `overlay1` | #7f849c | |
| `overlay0` | #6c7086 | |
| `surface2` | #585b70 | |
| `surface1` | #45475a | |
| `surface0` | #313244 | |
| `base` | #1e1e2e | main background |
| `mantle` | #181825 | darker bg |
| `crust` | #11111b | darkest bg |
