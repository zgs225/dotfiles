# i3 Software Stack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure the full i3wm desktop environment (i3, polybar, rofi, dunst, picom, GTK, i3lock, wallpaper) using Catppuccin Mocha unified color scheme as chezmoi-managed dotfiles.

**Architecture:** Each component gets its own config file under `dot_config/` or `dot_local/`. Colors are defined once in `.chezmoi.yaml.tmpl` under `data.colors` using the Catppuccin Mocha 26-color palette. All config files that need colors use `.tmpl` suffix and reference `{{ .colors.<name> }}`.

**Tech Stack:** chezmoi templates, i3-wm, polybar, rofi, dunst, picom, feh, i3lock, maim, ImageMagick
**Target:** Arch Linux with standard i3-wm, Noto Sans CJK SC, Papirus icons

---

### Task 1: Add Catppuccin Mocha Color Data

**Files:**
- Modify: `.chezmoi.yaml.tmpl`

- [ ] **Step 1: Add color palette to chezmoi data**

Insert the `colors:` block into the `data:` section of `.chezmoi.yaml.tmpl`, after `useI3`:

```yaml
  colors:
    rosewater: "#f5e0dc"
    flamingo:  "#f2cdcd"
    pink:      "#f5c2e7"
    mauve:     "#cba6f7"
    red:       "#f38ba8"
    maroon:    "#eba0ac"
    peach:     "#fab387"
    yellow:    "#f9e2af"
    green:     "#a6e3a1"
    teal:      "#94e2d5"
    sky:       "#89dceb"
    sapphire:  "#74c7ec"
    blue:      "#89b4fa"
    lavender:  "#b4befe"
    text:      "#cdd6f4"
    subtext1:  "#bac2de"
    subtext0:  "#a6adc8"
    overlay2:  "#9399b2"
    overlay1:  "#7f849c"
    overlay0:  "#6c7086"
    surface2:  "#585b70"
    surface1:  "#45475a"
    surface0:  "#313244"
    base:      "#1e1e2e"
    mantle:    "#181825"
    crust:     "#11111b"
```

- [ ] **Step 2: Validate chezmoi template parsing**

```bash
chezmoi execute-template '{{ .colors.base }}'
```

Expected: `#1e1e2e`

- [ ] **Step 3: Commit**

```bash
git add .chezmoi.yaml.tmpl
git commit -m "feat: add Catppuccin Mocha color palette to chezmoi data"
```

---

### Task 2: i3 Window Manager Config

**Files:**
- Create: `dot_config/i3/config.tmpl`

- [ ] **Step 1: Create i3 config directory**

```bash
mkdir -p dot_config/i3
```

- [ ] **Step 2: Write i3 config template**

Write `dot_config/i3/config.tmpl`:

```
# i3 config — Catppuccin Mocha
# Managed by chezmoi

set $mod Mod4
set $term wezterm

# Font for window titles
font pango:Noto Sans CJK SC 10

# Gap size (standard i3 — no gaps, only window border)
default_border pixel 2
default_floating_border pixel 2
hide_edge_borders smart

# Colors (Catppuccin Mocha)
#                          border   bg       text     indicator  child_border
client.focused            {{ .colors.lavender }} {{ .colors.lavender }} {{ .colors.base }}    {{ .colors.mauve }}    {{ .colors.lavender }}
client.focused_inactive   {{ .colors.surface0 }} {{ .colors.surface0 }} {{ .colors.text }}    {{ .colors.overlay0 }} {{ .colors.surface0 }}
client.unfocused          {{ .colors.surface0 }} {{ .colors.base }}    {{ .colors.text }}    {{ .colors.overlay0 }} {{ .colors.surface0 }}
client.urgent             {{ .colors.red }}      {{ .colors.red }}      {{ .colors.base }}    {{ .colors.red }}      {{ .colors.red }}
client.placeholder        {{ .colors.surface0 }} {{ .colors.base }}    {{ .colors.text }}    {{ .colors.overlay0 }} {{ .colors.surface0 }}
client.background         {{ .colors.base }}

# i3bar colors (fallback — polybar replaces this)
bar {
    colors {
        background {{ .colors.base }}
        statusline {{ .colors.text }}
        separator  {{ .colors.overlay0 }}
        focused_workspace  {{ .colors.lavender }} {{ .colors.lavender }} {{ .colors.base }}
        active_workspace   {{ .colors.surface1 }} {{ .colors.surface1 }} {{ .colors.text }}
        inactive_workspace {{ .colors.surface0 }} {{ .colors.surface0 }} {{ .colors.text }}
        urgent_workspace   {{ .colors.red }}      {{ .colors.red }}      {{ .colors.base }}
    }
}

# Focus follows mouse, but mouse click doesn't change focus
focus_follows_mouse yes
focus_on_window_activation smart

# Floating modifier
floating_modifier $mod+Shift

# Workspace key bindings
set $ws1  "1"
set $ws2  "2"
set $ws3  "3"
set $ws4  "4"
set $ws5  "5"
set $ws6  "6"
set $ws7  "7"
set $ws8  "8"
set $ws9  "9"
set $ws10 "10"

bindsym $mod+1 workspace number $ws1
bindsym $mod+2 workspace number $ws2
bindsym $mod+3 workspace number $ws3
bindsym $mod+4 workspace number $ws4
bindsym $mod+5 workspace number $ws5
bindsym $mod+6 workspace number $ws6
bindsym $mod+7 workspace number $ws7
bindsym $mod+8 workspace number $ws8
bindsym $mod+9 workspace number $ws9
bindsym $mod+0 workspace number $ws10

bindsym $mod+Shift+1 move container to workspace number $ws1
bindsym $mod+Shift+2 move container to workspace number $ws2
bindsym $mod+Shift+3 move container to workspace number $ws3
bindsym $mod+Shift+4 move container to workspace number $ws4
bindsym $mod+Shift+5 move container to workspace number $ws5
bindsym $mod+Shift+6 move container to workspace number $ws6
bindsym $mod+Shift+7 move container to workspace number $ws7
bindsym $mod+Shift+8 move container to workspace number $ws8
bindsym $mod+Shift+9 move container to workspace number $ws9
bindsym $mod+Shift+0 move container to workspace number $ws10

# Layout
bindsym $mod+Shift+Space floating toggle
bindsym $mod+Shift+f fullscreen toggle

# Split orientation
bindsym $mod+h split h
bindsym $mod+v split v

# Focus movement
bindsym $mod+j focus left
bindsym $mod+k focus down
bindsym $mod+l focus up
bindsym $mod+semicolon focus right

# Move windows
bindsym $mod+Shift+j move left
bindsym $mod+Shift+k move down
bindsym $mod+Shift+l move up
bindsym $mod+Shift+semicolon move right

# Resize mode
bindsym $mod+r mode "resize"
mode "resize" {
    bindsym j resize shrink width 10 px or 10 ppt
    bindsym k resize grow height 10 px or 10 ppt
    bindsym l resize shrink height 10 px or 10 ppt
    bindsym semicolon resize grow width 10 px or 10 ppt
    bindsym Return mode "default"
    bindsym Escape mode "default"
}

# Applications
bindsym $mod+Return exec $term
bindsym $mod+d exec "rofi -show drun"
bindsym $mod+Tab exec "rofi -show window"
bindsym $mod+Shift+q kill
bindsym $mod+Shift+l exec ~/.local/share/bin/lock.sh

# Screenshots
bindsym Print exec "mkdir -p ~/Pictures/screenshots && maim ~/Pictures/screenshots/$(date +%Y%m%d-%H%M%S).png"
bindsym Shift+Print exec "mkdir -p ~/Pictures/screenshots && maim -s ~/Pictures/screenshots/$(date +%Y%m%d-%H%M%S).png"

# i3 control
bindsym $mod+Shift+c reload
bindsym $mod+Shift+r restart
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'Exit i3?' -b 'Yes' 'i3-msg exit'"

# Autostart
exec_always --no-startup-id feh --randomize --bg-fill ~/.local/share/wallpapers/
exec_always --no-startup-id picom --config ~/.config/picom/picom.conf
exec_always --no-startup-id ~/.config/polybar/launch.sh
exec_always --no-startup-id dunst
```

- [ ] **Step 3: Verify template data is accessible**

```bash
chezmoi execute-template '{{ .colors.lavender }}'
```

Expected: `#b4befe`

- [ ] **Step 4: Commit**

```bash
git add dot_config/i3/config.tmpl
git commit -m "feat: add i3 window manager config with Catppuccin Mocha theme"
```

---

### Task 3: Polybar Configuration

**Files:**
- Create: `dot_config/polybar/config.ini.tmpl`
- Create: `dot_config/polybar/launch.sh`

- [ ] **Step 1: Create polybar config directory**

```bash
mkdir -p dot_config/polybar
```

- [ ] **Step 2: Write polybar config**

Write `dot_config/polybar/config.ini.tmpl`:

```ini
[colors]
background = {{ .colors.base }}
background-alt = {{ .colors.surface0 }}
foreground = {{ .colors.text }}
foreground-alt = {{ .colors.subtext0 }}
primary = {{ .colors.lavender }}
secondary = {{ .colors.mauve }}
alert = {{ .colors.red }}
warning = {{ .colors.yellow }}
success = {{ .colors.green }}
disabled = {{ .colors.overlay0 }}

[bar/main]
monitor = ${env:MONITOR:}
width = 100%
height = 30
offset-x = 0
offset-y = 0
radius = 0
fixed-center = true

background = ${colors.background}
foreground = ${colors.foreground}

line-size = 2
line-color = ${colors.primary}

border-size = 0
border-color = ${colors.background}

padding-left = 1
padding-right = 1

module-margin-left = 1
module-margin-right = 1

font-0 = Noto Sans CJK SC;2
font-1 = DejaVu Sans Mono;2

modules-left = i3 xwindow
modules-center =
modules-right = cpu memory network pulseaudio battery date

tray-position = right
tray-padding = 2
tray-background = ${colors.background}

cursor-click = pointer
cursor-scroll = ns-resize

[module/i3]
type = internal/i3
format = <label-state> <label-mode>
index-sort = true
strip-wsnumbers = true
label-mode = %mode%
label-mode-padding = 2
label-mode-background = ${colors.alert}
label-mode-foreground = ${colors.background}
label-focused = %index%
label-focused-background = ${colors.primary}
label-focused-foreground = ${colors.background}
label-focused-padding = 2
label-unfocused = %index%
label-unfocused-padding = 2
label-unfocused-foreground = ${colors.foreground-alt}
label-visible = %index%
label-visible-background = ${colors.background-alt}
label-visible-padding = 2
label-urgent = %index%
label-urgent-background = ${colors.alert}
label-urgent-padding = 2

[module/xwindow]
type = internal/xwindow
label = %title:0:50:...%
label-foreground = ${colors.foreground}
label-maxlen = 50

[module/cpu]
type = internal/cpu
interval = 2
format-prefix = " CPU "
format-prefix-foreground = ${colors.foreground-alt}
label = %percentage:2%%
label-foreground = ${colors.foreground}

[module/memory]
type = internal/memory
interval = 2
format-prefix = " MEM "
format-prefix-foreground = ${colors.foreground-alt}
label = %percentage_used%%
label-foreground = ${colors.foreground}

[module/network]
type = internal/network
interface = wlp2s0
interval = 3
format-connected = <label-connected>
format-connected-foreground = ${colors.foreground}
label-connected = %ifname% %local_ip%
format-disconnected = <label-disconnected>
format-disconnected-foreground = ${colors.disabled}
label-disconnected = disconnected

[module/pulseaudio]
type = internal/pulseaudio
format-volume-prefix = " VOL "
format-volume-prefix-foreground = ${colors.foreground-alt}
format-volume = <label-volume>
label-volume = %percentage%%
label-volume-foreground = ${colors.foreground}
label-muted = muted
label-muted-foreground = ${colors.disabled}

[module/battery]
type = internal/battery
battery = BAT0
adapter = AC0
full-at = 99
time-format = %H:%M

format-charging-prefix = " CHR "
format-charging-prefix-foreground = ${colors.foreground-alt}
format-charging = <label-charging>
label-charging = %percentage%%
label-charging-foreground = ${colors.success}

format-discharging-prefix = " BAT "
format-discharging-prefix-foreground = ${colors.foreground-alt}
format-discharging = <label-discharging>
label-discharging = %percentage%%
label-discharging-foreground = ${colors.foreground}

format-full-prefix = " BAT "
format-full-prefix-foreground = ${colors.foreground-alt}
format-full = <label-full>
label-full = full
label-full-foreground = ${colors.success}

[module/date]
type = internal/date
interval = 1
date = %Y-%m-%d
date-alt = %a %d %b
time = %H:%M:%S
time-alt = %H:%M
label = %date%  %time%
label-foreground = ${colors.foreground}
```

- [ ] **Step 3: Write polybar launch script**

Write `dot_config/polybar/launch.sh`:

```bash
#!/usr/bin/env bash

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch bar(s) — one per monitor
if type "xrandr" > /dev/null; then
    for m in $(polybar --list-monitors | cut -d":" -f1); do
        MONITOR=$m polybar --reload main &
    done
else
    polybar --reload main &
fi
```

- [ ] **Step 4: Make launch script executable**

```bash
chmod +x dot_config/polybar/launch.sh
```

- [ ] **Step 5: Commit**

```bash
git add dot_config/polybar/config.ini.tmpl dot_config/polybar/launch.sh
git commit -m "feat: add polybar config with Catppuccin Mocha theme"
```

---

### Task 4: Rofi Configuration

**Files:**
- Create: `dot_config/rofi/config.rasi.tmpl`

- [ ] **Step 1: Create rofi config directory**

```bash
mkdir -p dot_config/rofi
```

- [ ] **Step 2: Write rofi config**

Write `dot_config/rofi/config.rasi.tmpl`:

```
configuration {
    modi: "drun,window,run";
    show-icons: true;
    icon-theme: "Papirus";
    drun-display-format: "{name}";
    font: "Noto Sans CJK SC 12";
    matching: "normal";
    sort: true;
    terminal: "wezterm";
    sidebar-mode: false;
}

* {
    bg-col: {{ .colors.base }};
    bg-col-light: {{ .colors.surface0 }};
    border-col: {{ .colors.lavender }};
    selected-col: {{ .colors.surface0 }};
    blue: {{ .colors.blue }};
    fg-col: {{ .colors.text }};
    fg-col2: {{ .colors.subtext0 }};
    grey: {{ .colors.overlay0 }};
    red: {{ .colors.red }};
    urgent: {{ .colors.red }};

    background-color: @bg-col;
    text-color: @fg-col;
    border: 2px;
    border-radius: 4;
    border-color: @border-col;
    padding: 4px;
}

#window {
    background-color: @bg-col;
    border: 2px;
    border-color: @border-col;
    border-radius: 8;
    width: 480px;
}

#mainbox {
    border: 0;
    padding: 4;
    children: [inputbar, listview];
}

#inputbar {
    border: 0;
    padding: 4;
    children: [prompt, entry];
}

#prompt {
    text-color: @blue;
    padding: 4;
}

#entry {
    padding: 4;
}

#listview {
    border: 0;
    columns: 1;
    lines: 8;
    cycle: true;
    dynamic: true;
    scrollbar: false;
}

#element {
    padding: 4;
    border-radius: 4;
}

#element normal {
    background-color: @bg-col;
    text-color: @fg-col;
}

#element selected {
    background-color: @selected-col;
    text-color: @fg-col;
}

#element alternate {
    background-color: @bg-col;
    text-color: @fg-col;
}

#element urgent {
    background-color: @urgent;
    text-color: @bg-col;
}

#scrollbar {
    width: 4px;
    border: 0;
    handle-color: @grey;
    handle-width: 4px;
    padding: 0;
}
```

- [ ] **Step 4: Commit**

```bash
git add dot_config/rofi/config.rasi.tmpl
git commit -m "feat: add rofi config with Catppuccin Mocha theme"
```

---

### Task 5: Dunst Notification Config

**Files:**
- Create: `dot_config/dunst/dunstrc.tmpl`

- [ ] **Step 1: Create dunst config directory**

```bash
mkdir -p dot_config/dunst
```

- [ ] **Step 2: Write dunst config**

Write `dot_config/dunst/dunstrc.tmpl`:

```ini
[global]
font = Noto Sans CJK SC 10
markup = yes
plain_text = no
format = "<b>%s</b>\n%b"
sort = yes
indicate_hidden = yes
alignment = left
show_age_threshold = 60
word_wrap = yes
ignore_newline = no
geometry = "300x5-20+20"
transparency = 0
idle_threshold = 120
monitor = 0
follow = mouse
sticky_history = yes
history_length = 20
show_indicators = no
line_height = 0
separator_height = 2
padding = 8
horizontal_padding = 8
separator_color = frame
browser = firefox
dmenu = rofi -dmenu -p dunst
icon_position = left
max_icon_size = 32
frame_width = 2
frame_color = "{{ .colors.lavender }}"

[urgency_low]
background = "{{ .colors.base }}"
foreground = "{{ .colors.text }}"
timeout = 5

[urgency_normal]
background = "{{ .colors.surface0 }}"
foreground = "{{ .colors.text }}"
timeout = 5

[urgency_critical]
background = "{{ .colors.red }}"
foreground = "{{ .colors.base }}"
timeout = 0
```

- [ ] **Step 4: Commit**

```bash
git add dot_config/dunst/dunstrc.tmpl
git commit -m "feat: add dunst notification config with Catppuccin Mocha theme"
```

---

### Task 6: Picom Compositor Config

**Files:**
- Create: `dot_config/picom/picom.conf`

- [ ] **Step 1: Create picom config directory**

```bash
mkdir -p dot_config/picom
```

- [ ] **Step 2: Write picom config**

Write `dot_config/picom/picom.conf`:

```ini
# Picom compositor config

backend = "glx";
vsync = true;

# Shadows
shadow = true;
shadow-radius = 8;
shadow-offset-x = -4;
shadow-offset-y = -4;
shadow-opacity = 0.25;
shadow-exclude = [
    "class_g = 'Polybar'",
    "class_g = 'i3bar'",
    "name = 'Notification'",
    "class_g = 'Dunst'",
];

# Fading
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 4;

# Opacity
inactive-opacity = 0.90;
active-opacity = 1.0;
frame-opacity = 0.9;
inactive-opacity-override = false;

opacity-rule = [
    "90:class_g = 'i3bar'",
    "90:class_g = 'Polybar'",
    "100:class_g = 'Rofi'",
];

# Blur (disabled for performance)
blur-background = false;

# Rounded corners (disabled)
corner-radius = 0;

# Exclude compositing for certain windows
no-fading-openclose = false;
no-fading-destroyed-argb = true;

# Detect client-side windows
detect-client-opacity = true;
detect-transient = true;
detect-rounded-corners = false;

# GLX-specific
glx-no-stencil = true;
glx-copy-from-front = false;
xrender-sync-fence = true;

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

- [ ] **Step 3: Validate picom config (syntax check on Linux)**

If on Linux:

```bash
picom --config dot_config/picom/picom.conf --diagnostics 2>&1 || true
```

(Note: this step is optional — picom config validity can only be fully verified on the target system.)

- [ ] **Step 4: Commit**

```bash
git add dot_config/picom/picom.conf
git commit -m "feat: add picom compositor config"
```

---

### Task 7: GTK Theme Settings

**Files:**
- Create: `dot_config/gtk-3.0/settings.ini.tmpl`
- Create: `dot_config/gtk-4.0/settings.ini.tmpl`

- [ ] **Step 1: Create GTK config directories**

```bash
mkdir -p dot_config/gtk-3.0 dot_config/gtk-4.0
```

- [ ] **Step 2: Write GTK3 settings**

Write `dot_config/gtk-3.0/settings.ini.tmpl`:

```ini
[Settings]
gtk-theme-name = Catppuccin-Mocha-Standard-Lavender-Dark
gtk-icon-theme-name = Papirus-Dark
gtk-font-name = Noto Sans CJK SC 10
gtk-cursor-theme-name = Adwaita
gtk-cursor-theme-size = 0
gtk-toolbar-style = GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size = GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images = 1
gtk-menu-images = 1
gtk-enable-event-sounds = 1
gtk-enable-input-feedback-sounds = 1
gtk-xft-antialias = 1
gtk-xft-hinting = 1
gtk-xft-hintstyle = hintmedium
gtk-xft-rgba = rgb
```

- [ ] **Step 3: Write GTK4 settings**

Write `dot_config/gtk-4.0/settings.ini.tmpl`:

```ini
[Settings]
gtk-theme-name = Catppuccin-Mocha-Standard-Lavender-Dark
gtk-icon-theme-name = Papirus-Dark
gtk-font-name = Noto Sans CJK SC 10
gtk-cursor-theme-name = Adwaita
gtk-cursor-theme-size = 0
```

- [ ] **Step 4: Commit**

```bash
git add dot_config/gtk-3.0/settings.ini.tmpl dot_config/gtk-4.0/settings.ini.tmpl
git commit -m "feat: add GTK3/GTK4 theme settings with Catppuccin"
```

---

### Task 8: i3lock Wrapper Script

**Files:**
- Create: `dot_local/share/bin/executable_lock.sh`

- [ ] **Step 1: Create lock script directory**

```bash
mkdir -p dot_local/share/bin
```

Note: chezmoi maps `dot_local/share/bin/executable_lock.sh` to `~/.local/share/bin/lock.sh` (executable).

- [ ] **Step 2: Write lock script**

Write `dot_local/share/bin/executable_lock.sh`:

```bash
#!/usr/bin/env bash

# i3lock wrapper — Catppuccin Mocha
# Takes a screenshot, blurs it, and uses it as lock background

tmpbg="/tmp/i3lock-$(date +%s).png"

# Take screenshot
maim "$tmpbg"

# Blur screenshot
convert "$tmpbg" -blur 0x8 "$tmpbg"

# Lock with Catppuccin Mocha colors
i3lock \
    --image="$tmpbg" \
    --inside-color=1e1e2e66 \
    --ring-color=b4befe \
    --line-color=00000000 \
    --keyhl-color=a6e3a1 \
    --bshl-color=f38ba8 \
    --separator-color=00000000 \
    --insidever-color=1e1e2e66 \
    --ringver-color=89b4fa \
    --insidewrong-color=1e1e2e66 \
    --ringwrong-color=f38ba8 \
    --radius=100 \
    --ring-width=5 \
    --verif-text="" \
    --wrong-text="" \
    --noinput-text="" \
    --lock-text="" \
    --clock \
    --time-color=cdd6f4 \
    --time-align=1 \
    --date-color=a6adc8 \
    --date-align=1 \
    --time-font="Noto Sans CJK SC" \
    --date-font="Noto Sans CJK SC" \
    --time-size=48 \
    --date-size=18 \
    --time-str="%H:%M" \
    --date-str="%Y-%m-%d"

# Clean up
rm "$tmpbg"
```

- [ ] **Step 3: Commit**

```bash
git add dot_local/share/bin/executable_lock.sh
git commit -m "feat: add i3lock wrapper script with Catppuccin Mocha colors"
```

---

### Task 9: Wallpaper Directory Placeholder

**Files:**
- Create: `dot_local/share/wallpapers/.gitkeep`

- [ ] **Step 1: Create wallpapers directory**

```bash
mkdir -p dot_local/share/wallpapers
```

- [ ] **Step 2: Add .gitkeep placeholder**

```bash
touch dot_local/share/wallpapers/.gitkeep
```

- [ ] **Step 3: Commit**

```bash
git add dot_local/share/wallpapers/.gitkeep
git commit -m "feat: add wallpapers directory placeholder"
```

---

### Task 10: Final Verification

- [ ] **Step 1: Verify chezmoi doctor shows no template errors**

```bash
chezmoi doctor
```

Expected: No errors in template parsing or data sections.

- [ ] **Step 2: Verify color data is accessible to templates**

```bash
chezmoi execute-template '{{ .colors.base }}' && chezmoi execute-template '{{ .colors.lavender }}'
```

Expected: `#1e1e2e` and `#b4befe`

- [ ] **Step 3: Review git status and commit any stragglers**

```bash
git status
git diff --stat
```

- [ ] **Step 4: Final commit (if any changes remain)**

```bash
git add -A
git commit -m "chore: final polish of i3 software stack config" || echo "Nothing to commit"
```
