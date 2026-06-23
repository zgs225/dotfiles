# Design: Wayland + Hyprland Desktop Migration

**Date:** 2026-06-23
**Status:** Approved
**Scope:** Full replacement of i3/X11 desktop with Hyprland/Wayland

## Overview

Replace the current i3/X11 desktop stack with a Hyprland/Wayland stack. This is a **full replacement** — X11 configs are removed, not kept as fallback. The chezmoi dotfiles patterns (`.tmpl` templates, Catppuccin Mocha color palette, same directory structure) are preserved.

## Component Mapping

| X11 Component | Wayland Replacement | Config Path |
|---|---|---|
| i3 (wm) | **Hyprland** | `dot_config/hypr/hyprland.conf.tmpl` |
| polybar (bar) | **waybar** | `dot_config/waybar/config.tmpl` + `style.css.tmpl` |
| rofi (launcher) | **anyrun** | `dot_config/anyrun/config.tmpl` + `style.css.tmpl` |
| dunst (notifications) | **mako** | `dot_config/mako/config.tmpl` |
| picom (compositor) | **none** — Hyprland built-in | — |
| feh (wallpaper) | **hyprpaper** | `dot_config/hypr/hyprpaper.conf.tmpl` |
| maim (screenshot) | **grim + slurp** | updated `dot_local/share/bin/executable_screenshot.sh` |
| i3lock (lock) | **swaylock** | `dot_config/swaylock/config.tmpl` |
| xsel/xclip (clipboard) | **wl-clipboard** | already handled in `dot_tmux.conf` |
| rofi powermenu | **wlogout** | `dot_bin/executable_wlogout` or script |
| set-dpi.sh / dpi-mode | **none** — Hyprland native `monitor=` scaling | — |

## Files to Remove

- `dot_config/i3/` — i3 config, scripts (keyhint, powermenu)
- `dot_config/polybar/` — polybar config, launcher, fcitx5-status script
- `dot_config/rofi/` — rofi config, powermenu/keyhint themes
- `dot_config/picom/` — picom compositor config
- `dot_config/dunst/` — dunst notification config
- `dot_xinitrc` — X session startup
- `dot_xprofile` — X environment variables (fcitx5 IM modules)
- `dot_bin/executable_set-dpi.sh` — xrandr-based DPI detection
- `dot_bin/executable_dpi-mode` — xrdb DPI query
- `dot_local/share/bin/executable_lock.sh` — i3lock wrapper

## Files to Add

- `dot_config/hypr/hyprland.conf.tmpl` — main Hyprland config
- `dot_config/hypr/hyprpaper.conf.tmpl` — wallpaper daemon config
- `dot_config/waybar/config.tmpl` — bar layout and modules
- `dot_config/waybar/style.css.tmpl` — bar theming
- `dot_config/anyrun/config.tmpl` — launcher config
- `dot_config/anyrun/style.css.tmpl` — launcher theming
- `dot_config/mako/config.tmpl` — notification daemon config
- `dot_config/swaylock/config.tmpl` — lock screen config

## Files to Update

- `dot_zprofile.tmpl` — change `exec startx` to `exec Hyprland`, remove `useI3` gate
- `.chezmoiignore` — remove i3/useI3 conditional gate
- `.chezmoi.yaml.tmpl` — remove `useI3` variable
- `dot_local/share/bin/executable_screenshot.sh` — `maim` → `grim + slurp`

## Session Startup Chain

```
tty1 login → .zprofile (exec Hyprland) → hyprland.conf exec-once
```

Hyprland `exec-once` directives (in order):
1. `hyprpaper` — wallpaper
2. `waybar` — status bar
3. `mako` — notifications
4. `fcitx5 -d` — input method
5. `sunshine` — game streaming
6. `nm-applet` — network manager tray

Anyrun is not autostarted; it is bound to `$mainMod + Space` hotkey.

## DPI / Scaling

Hyprland handles fractional scaling natively via `monitor=` directive in `hyprland.conf.tmpl`. No more xrandr/xrdb scripts or `/tmp/` file generation. Scaling is set per-monitor:

```
monitor=,preferred,auto,1.5
```

## Keybindings

Preserve muscle memory from i3 where possible:
- `$mainMod` = Super (replaces Alt/Mod1)
- `$mainMod + Space` = anyrun launcher (was `$mod+d` for rofi)
- `$mainMod + Return` = terminal (wezterm)
- `$mainMod + Ctrl + l` = swaylock (was i3lock)
- `$mainMod + Shift + q` = kill window (was i3)
- Vim-style hjkl navigation
- 10 workspaces with Nerd Font icons

## Chezmoi Patterns Preserved

- `.tmpl` Go templates for all configs
- Catppuccin Mocha color palette from `.chezmoi.yaml.tmpl` data block
- `dot_` prefix → `.` in `$HOME`
- `executable_` prefix → mode 755
- `dot_config/` → `~/.config/`
- No OS-level configuration (AGENTS.md rule)
