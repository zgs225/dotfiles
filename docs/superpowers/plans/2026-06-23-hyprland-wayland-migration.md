# Hyprland + Wayland Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace i3/X11 desktop stack with Hyprland/Wayland in chezmoi dotfiles

**Architecture:** Remove all X11 configs (i3, polybar, rofi, dunst, picom, xinitrc, xprofile, set-dpi, lock). Add Hyprland WM + waybar + anyrun + mako + hyprpaper + swaylock configs. Update .zprofile to launch Hyprland on tty1. All configs use `.tmpl` Go templates with Catppuccin Mocha colors from `.chezmoi.yaml.tmpl`.

**Tech Stack:** Hyprland, waybar, anyrun, mako, hyprpaper, swaylock, grim + slurp, wl-clipboard, chezmoi Go templates, Catppuccin Mocha

## Global Constraints

- `.tmpl` Go templates for all configs with color substitution
- Catppuccin Mocha palette from `.chezmoi.yaml.tmpl` data block
- `dot_` prefix → `.` in `$HOME`, `dot_config/` → `~/.config/`
- `executable_` prefix → chezmoi makes file mode 755
- No OS-level configuration (AGENTS.md rule)
- User does NOT want files modified — plan is documentation only for now

---

### Task 1: Remove X11 Config Files

**Files:**
- Remove: `dot_config/i3/config.tmpl`
- Remove: `dot_config/i3/scripts/executable_powermenu`
- Remove: `dot_config/i3/scripts/executable_keyhint`
- Remove: `dot_config/polybar/config.ini.tmpl`
- Remove: `dot_config/polybar/executable_launch.sh`
- Remove: `dot_config/polybar/scripts/executable_fcitx5-status`
- Remove: `dot_config/rofi/config.rasi.tmpl`
- Remove: `dot_config/rofi/powermenu.rasi`
- Remove: `dot_config/rofi/keyhint.rasi`
- Remove: `dot_config/picom/picom.conf`
- Remove: `dot_config/dunst/dunstrc.tmpl`
- Remove: `dot_xinitrc`
- Remove: `dot_xprofile`
- Remove: `dot_bin/executable_set-dpi.sh`
- Remove: `dot_bin/executable_dpi-mode`
- Remove: `dot_local/share/bin/executable_lock.sh`

**Interfaces:**
- Consumes: nothing
- Produces: clean repo without X11 artifacts

- [ ] **Step 1: Remove all X11 files**

```bash
rm -r dot_config/i3/
rm -r dot_config/polybar/
rm -r dot_config/rofi/
rm -r dot_config/picom/
rm -r dot_config/dunst/
rm dot_xinitrc
rm dot_xprofile
rm dot_bin/executable_set-dpi.sh
rm dot_bin/executable_dpi-mode
rm dot_local/share/bin/executable_lock.sh
```

- [ ] **Step 2: Verify removal**

```bash
for f in dot_config/i3 dot_config/polybar dot_config/rofi dot_config/picom dot_config/dunst dot_xinitrc dot_xprofile dot_bin/executable_set-dpi.sh dot_bin/executable_dpi-mode dot_local/share/bin/executable_lock.sh; do
    if [ -e "$f" ]; then echo "STILL EXISTS: $f"; fi
done
```

Expected: No output.

- [ ] **Step 3: Commit**

```bash
git add -A dot_config/i3/ dot_config/polybar/ dot_config/rofi/ dot_config/picom/ dot_config/dunst/ dot_xinitrc dot_xprofile dot_bin/executable_set-dpi.sh dot_bin/executable_dpi-mode dot_local/share/bin/executable_lock.sh
git commit -m "refactor: remove i3/X11 desktop configs"
```

---

### Task 2: Update Chezmoi Configuration Files

**Files:**
- Modify: `.chezmoi.yaml.tmpl` — remove `useI3` variable
- Modify: `.chezmoiignore` — remove i3 conditional gate
- Modify: `dot_zprofile.tmpl` — replace startx with Hyprland

**Interfaces:**
- Consumes: removed X11 files (Task 1)
- Produces: updated chezmoi config that no longer references i3

- [ ] **Step 1: Remove `useI3` from `.chezmoi.yaml.tmpl`**

Edit `.chezmoi.yaml.tmpl` line 14 — remove the entire `useI3` line:

```yaml
  isMacOS: {{ eq .chezmoi.os "darwin" }}
  isLinux: {{ eq .chezmoi.os "linux" }}
  isWindows: {{ eq .chezmoi.os "windows" }}

  colors:
```

(Remove `  useI3: {{ lookPath "i3" | ne "" }}`)

- [ ] **Step 2: Update `.chezmoiignore`**

Edit `.chezmoiignore` — remove the i3 conditional block (lines 16-19):

Old:
```
{{ if not (and .isLinux .useI3) }}
.zprofile
.xinitrc
{{ end }}
```

New:
```
{{ if not .isLinux }}
.zprofile
{{ end }}
```

- [ ] **Step 3: Update `dot_zprofile.tmpl`**

Edit `dot_zprofile.tmpl` — replace startx with Hyprland launch:

Old:
```
{{ if and .isLinux .useI3 }}
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec startx
fi
{{ end }}
```

New:
```
{{ if .isLinux }}
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec Hyprland
fi
{{ end }}
```

- [ ] **Step 4: Commit**

```bash
git add .chezmoi.yaml.tmpl .chezmoiignore dot_zprofile.tmpl
git commit -m "refactor: update chezmoi config for Hyprland/Wayland"
```

---

### Task 3: Create Hyprland Config

**Files:**
- Create: `dot_config/hypr/hyprland.conf.tmpl`

**Interfaces:**
- Consumes: Catppuccin colors from `.chezmoi.yaml.tmpl` (`.colors.base`, `.colors.lavender`, `.colors.mauve`, `.colors.red`, `.colors.surface0`, `.colors.surface1`, `.colors.text`, `.colors.overlay0`, `.colors.green`, `.colors.flamingo`)
- Produces: `~/.config/hypr/hyprland.conf` with WM config, keybindings, autostart

- [ ] **Step 1: Create directory**

```bash
mkdir -p dot_config/hypr
```

- [ ] **Step 2: Write `dot_config/hypr/hyprland.conf.tmpl`**

```ini
# Hyprland config — Catppuccin Mocha
# Managed by chezmoi

# ── Variables ──────────────────────────────────
$mainMod = SUPER
$term = wezterm

# ── Monitor ────────────────────────────────────
monitor=,preferred,auto,1.5

# ── Autostart ──────────────────────────────────
exec-once = hyprpaper
exec-once = waybar
exec-once = mako
exec-once = fcitx5 -d
exec-once = sunshine
exec-once = nm-applet

# ── Environment ────────────────────────────────
env = GTK_IM_MODULE,fcitx
env = QT_IM_MODULE,fcitx
env = XMODIFIERS,@im=fcitx
env = SDL_IM_MODULE,fcitx

# ── Look & Feel ────────────────────────────────
general {
    gaps_in = 0
    gaps_out = 0
    border_size = 2
    col.active_border = rgb({{ .colors.lavender | replace "#" "" }})
    col.inactive_border = rgb({{ .colors.surface0 | replace "#" "" }})
    cursor_inactive_timeout = 0
    layout = dwindle
}

decoration {
    rounding = 0
    blur {
        enabled = false
    }
    shadow {
        enabled = false
    }
}

cursor {
    no_hardware_cursors = false
}

misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
    vfr = true
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
}

input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

gestures {
    workspace_swipe = false
}

# ── Keybindings ────────────────────────────────
# Launch terminal
bind = $mainMod, Return, exec, $term

# Launch anyrun
bind = $mainMod, Space, exec, anyrun

# Kill active window
bind = $mainMod, Q, killactive,

# Toggle floating
bind = $mainMod SHIFT, Space, togglefloating,

# Toggle fullscreen
bind = $mainMod, F, fullscreen, 0

# Split orientation
bind = $mainMod, minus, splitratio, 0.5
bind = $mainMod SHIFT, backslash, swapwindow,

# Focus movement (vim-style)
bind = $mainMod, H, movefocus, l
bind = $mainMod, J, movefocus, d
bind = $mainMod, K, movefocus, u
bind = $mainMod, L, movefocus, r

# Move windows
bind = $mainMod SHIFT, H, movewindow, l
bind = $mainMod SHIFT, J, movewindow, d
bind = $mainMod SHIFT, K, movewindow, u
bind = $mainMod SHIFT, L, movewindow, r

# Workspace navigation
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move windows to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Scratchpad
bind = $mainMod, S, togglespecialworkspace,
bind = $mainMod SHIFT, S, movetoworkspace, special

# Screenshots
bind = $mainMod SHIFT, 3, exec, ~/.local/share/bin/screenshot.sh full
bind = $mainMod SHIFT, 4, exec, ~/.local/share/bin/screenshot.sh select

# Lock screen
bind = $mainMod CTRL, L, exec, swaylock

# Power menu (wlogout)
bind = $mainMod SHIFT, E, exec, wlogout

# Reload Hyprland config
bind = $mainMod SHIFT, C, exec, hyprctl reload
```

- [ ] **Step 3: Commit**

```bash
git add dot_config/hypr/hyprland.conf.tmpl
git commit -m "feat: add Hyprland window manager config"
```

---

### Task 4: Create Hyprpaper Config

**Files:**
- Create: `dot_config/hypr/hyprpaper.conf.tmpl`

**Interfaces:**
- Consumes: Home directory path for wallpapers
- Produces: `~/.config/hypr/hyprpaper.conf`

- [ ] **Step 1: Write `dot_config/hypr/hyprpaper.conf.tmpl`**

```ini
preload = {{ .chezmoi.homeDir }}/.local/share/wallpapers/catppuccin-mocha.png
wallpaper = ,{{ .chezmoi.homeDir }}/.local/share/wallpapers/catppuccin-mocha.png
```

- [ ] **Step 2: Commit**

```bash
git add dot_config/hypr/hyprpaper.conf.tmpl
git commit -m "feat: add hyprpaper wallpaper config"
```

---

### Task 5: Create Waybar Config

**Files:**
- Create: `dot_config/waybar/config.tmpl`
- Create: `dot_config/waybar/style.css.tmpl`

**Interfaces:**
- Consumes: Catppuccin colors from `.chezmoi.yaml.tmpl`
- Produces: `~/.config/waybar/config` and `~/.config/waybar/style.css`

- [ ] **Step 1: Create directory**

```bash
mkdir -p dot_config/waybar
```

- [ ] **Step 2: Write `dot_config/waybar/config.tmpl`**

```jsonc
{
    "layer": "top",
    "position": "top",
    "height": 30,

    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["network", "battery", "tray"],

    "hyprland/workspaces": {
        "all-outputs": true,
        "format": "{icon}",
        "format-icons": {
            "1": "1",
            "2": "2",
            "3": "3",
            "4": "4",
            "5": "5",
            "6": "6",
            "7": "7",
            "8": "8",
            "9": "9",
            "10": "10"
        },
        "persistent-workspaces": {
            "*": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        }
    },

    "clock": {
        "format": "{:%Y-%m-%d %H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },

    "network": {
        "format-wifi": "{essid}",
        "format-ethernet": "{ipaddr}",
        "format-disconnected": "Disconnected",
        "tooltip-format": "{ifname} via {gwaddr}"
    },

    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{capacity}% {icon}",
        "format-icons": ["", "", "", "", ""]
    },

    "tray": {
        "icon-size": 16,
        "spacing": 4
    }
}
```

- [ ] **Step 3: Write `dot_config/waybar/style.css.tmpl`**

```css
* {
    font-family: "Noto Sans CJK SC", sans-serif;
    font-size: 13px;
    min-height: 0;
    border: none;
    border-radius: 0;
}

window#waybar {
    background-color: {{ .colors.base }};
    color: {{ .colors.text }};
}

#workspaces button {
    color: {{ .colors.overlay0 }};
    padding: 0 6px;
    background-color: transparent;
}

#workspaces button.active {
    color: {{ .colors.lavender }};
    background-color: {{ .colors.surface0 }};
}

#workspaces button:hover {
    background-color: {{ .colors.surface1 }};
    color: {{ .colors.text }};
}

#clock {
    color: {{ .colors.text }};
    padding: 0 12px;
}

#network {
    color: {{ .colors.teal }};
    padding: 0 8px;
}

#battery {
    color: {{ .colors.green }};
    padding: 0 8px;
}

#battery.warning {
    color: {{ .colors.peach }};
}

#battery.critical {
    color: {{ .colors.red }};
}

#tray {
    padding: 0 4px;
}
```

- [ ] **Step 4: Commit**

```bash
git add dot_config/waybar/
git commit -m "feat: add waybar status bar config"
```

---

### Task 6: Create Anyrun Config

**Files:**
- Create: `dot_config/anyrun/config.tmpl`
- Create: `dot_config/anyrun/style.css.tmpl`

**Interfaces:**
- Consumes: Catppuccin colors from `.chezmoi.yaml.tmpl`
- Produces: `~/.config/anyrun/config.toml` (note: chezmoi strips `.tmpl`, file must be renamed; anyrun expects `.toml` not `.tmpl` — alternatively, chezmoi can manage `config.ron`)

**Note:** Anyrun uses TOML for its config file. The chezmoi `.tmpl` extension will produce `config` (no extension) unless handled. Use `config.ron` format instead, which is anyrun's alternative config format.

- [ ] **Step 1: Create directory**

```bash
mkdir -p dot_config/anyrun
```

- [ ] **Step 2: Write `dot_config/anyrun/config.ron.tmpl`**

```ron
Config {
    width: Relative(0.35),
    max_entries: 10,
    position: Top,
    hide_icons: false,
    hide_plugin_info: true,
    close_on_click: true,
    plugins: [
        "libanyrun_applications.so",
    ],
}
```

- [ ] **Step 3: Write `dot_config/anyrun/style.css.tmpl`**

```css
* {
    all: unset;
    font-family: "Noto Sans CJK SC", sans-serif;
    font-size: 14px;
}

#window {
    background-color: transparent;
}

#main {
    background-color: {{ .colors.base }};
    border: 2px solid {{ .colors.lavender }};
    border-radius: 4px;
    padding: 8px;
}

#input {
    margin: 0;
    padding: 4px 8px;
    background-color: {{ .colors.surface0 }};
    color: {{ .colors.text }};
    border: none;
}

#input placeholder {
    color: {{ .colors.overlay0 }};
}

#entry {
    padding: 4px 8px;
    color: {{ .colors.text }};
}

#entry:selected {
    background-color: {{ .colors.surface0 }};
    color: {{ .colors.lavender }};
}

#plugin {
    margin: 0;
}
```

- [ ] **Step 4: Commit**

```bash
git add dot_config/anyrun/
git commit -m "feat: add anyrun launcher config"
```

---

### Task 7: Create Mako Config

**Files:**
- Create: `dot_config/mako/config.tmpl`

**Interfaces:**
- Consumes: Catppuccin colors from `.chezmoi.yaml.tmpl`
- Produces: `~/.config/mako/config`

- [ ] **Step 1: Create directory**

```bash
mkdir -p dot_config/mako
```

- [ ] **Step 2: Write `dot_config/mako/config.tmpl`**

```ini
font=Noto Sans CJK SC 10
margin=10,20,10,20
padding=8
width=300
height=120
max-visible=5
default-timeout=5000
sort=+time
anchor=top-right
ignore-timeout=0
border-size=2
border-radius=4
background-color={{ .colors.base }}
text-color={{ .colors.text }}
border-color={{ .colors.lavender }}
progress-color=over {{ .colors.surface1 }}

[urgency=low]
background-color={{ .colors.base }}
text-color={{ .colors.text }}
timeout=3000

[urgency=normal]
background-color={{ .colors.surface0 }}
text-color={{ .colors.text }}
timeout=5000

[urgency=critical]
background-color={{ .colors.red }}
text-color={{ .colors.base }}
timeout=0
```

- [ ] **Step 3: Commit**

```bash
git add dot_config/mako/config.tmpl
git commit -m "feat: add mako notification daemon config"
```

---

### Task 8: Create Swaylock Config

**Files:**
- Create: `dot_config/swaylock/config.tmpl`

**Interfaces:**
- Consumes: Catppuccin colors from `.chezmoi.yaml.tmpl`
- Produces: `~/.config/swaylock/config`

- [ ] **Step 1: Create directory**

```bash
mkdir -p dot_config/swaylock
```

- [ ] **Step 2: Write `dot_config/swaylock/config.tmpl`**

```ini
color={{ .colors.base }}
inside-color={{ .colors.base }}66
ring-color={{ .colors.lavender }}
line-color=00000000
key-hl-color={{ .colors.green }}
bs-hl-color={{ .colors.red }}
separator-color=00000000
inside-ver-color={{ .colors.base }}66
ring-ver-color={{ .colors.blue }}
inside-wrong-color={{ .colors.base }}66
ring-wrong-color={{ .colors.red }}
ring-width=5
radius=100
indicator-radius=120
font="Noto Sans CJK SC"
font-size=48
text-color={{ .colors.text }}
line-uses-ring=false
ignore-empty-password=true
show-failed-attempts=true
```

- [ ] **Step 3: Commit**

```bash
git add dot_config/swaylock/config.tmpl
git commit -m "feat: add swaylock screen lock config"
```

---

### Task 9: Update Screenshot Script

**Files:**
- Modify: `dot_local/share/bin/executable_screenshot.sh` — replace maim with grim+slurp

**Interfaces:**
- Consumes: existing screenshot.sh structure
- Produces: updated Wayland-native screenshot script

- [ ] **Step 1: Edit `dot_local/share/bin/executable_screenshot.sh`**

Replace the entire content:

```bash
#!/usr/bin/env bash

set -euo pipefail

dir="${SCREENSHOT_DIR:-$HOME/Pictures/screenshots}"
mkdir -p "$dir"

timestamp=$(date +%Y%m%d-%H%M%S)

case "${1:-full}" in
    select)
        grim -g "$(slurp)" "$dir/$timestamp.png"
        ;;
    full)
        grim "$dir/$timestamp.png"
        ;;
    *)
        echo "Usage: screenshot.sh [full|select]" >&2
        exit 1
        ;;
esac
```

- [ ] **Step 2: Commit**

```bash
git add dot_local/share/bin/executable_screenshot.sh
git commit -m "refactor: update screenshot script to grim+slurp for Wayland"
```

---

### Task 10: Final Verification and Commit

**Files:**
- All files from Tasks 1-9

**Interfaces:**
- Consumes: all prior tasks
- Produces: verified complete migration

- [ ] **Step 1: Verify repo structure — expected files exist**

```bash
# New files should exist
for f in \
    dot_config/hypr/hyprland.conf.tmpl \
    dot_config/hypr/hyprpaper.conf.tmpl \
    dot_config/waybar/config.tmpl \
    dot_config/waybar/style.css.tmpl \
    dot_config/anyrun/config.ron.tmpl \
    dot_config/anyrun/style.css.tmpl \
    dot_config/mako/config.tmpl \
    dot_config/swaylock/config.tmpl \
    dot_zprofile.tmpl \
    .chezmoiignore \
    .chezmoi.yaml.tmpl \
    dot_local/share/bin/executable_screenshot.sh; do
    if [ ! -e "$f" ]; then echo "MISSING: $f"; fi
done
```

- [ ] **Step 2: Verify old X11 files are gone**

```bash
for f in \
    dot_config/i3 \
    dot_config/polybar \
    dot_config/rofi \
    dot_config/picom \
    dot_config/dunst \
    dot_xinitrc \
    dot_xprofile \
    dot_bin/executable_set-dpi.sh \
    dot_bin/executable_dpi-mode \
    dot_local/share/bin/executable_lock.sh; do
    if [ -e "$f" ]; then echo "STILL EXISTS: $f"; fi
done
```

Expected: No output.

- [ ] **Step 3: Verify `.chezmoi.yaml.tmpl` has no `useI3`**

```bash
grep -c useI3 .chezmoi.yaml.tmpl
```

Expected: 0

- [ ] **Step 4: Verify `.chezmoiignore` has no `useI3`**

```bash
grep -c useI3 .chezmoiignore
```

Expected: 0

- [ ] **Step 5: Final commit (if needed)**

```bash
git status
# Only commit if there are uncommitted changes
```
