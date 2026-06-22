# Polybar Icon Style Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign polybar to use Nerd Font icons, add practical modules (filesystem, powermenu), add i3 workspace icons, and replace i3-nagbar with rofi powermenu.

**Architecture:** In-place modification of existing chezmoi-managed dotfiles. Single-file polybar config gets icon/font/module upgrades. i3 config gets workspace icon names and powermenu keybinding. New powermenu script + rofi theme follow existing patterns (keyhint script/keyhint.rasi).

**Tech Stack:** polybar, i3, rofi, Nerd Fonts (Symbols Nerd Font + JetBrainsMono Nerd Font), chezmoi Go templates, Catppuccin Mocha color palette

## Global Constraints

- All files are chezmoi source files: edit in repo, apply via `chezmoi apply`
- `dot_` prefix → `.` in `$HOME`; `dot_config/` → `~/.config/`
- Color variables come from `.chezmoi.yaml.tmpl` data block (Catppuccin Mocha)
- Template syntax: `{{ .colors.lavender }}` etc.
- Available Nerd Fonts on system: `Symbols Nerd Font`, `JetBrainsMono Nerd Font`
- Available tools: `rofi` (v2.0), `i3lock`, `systemctl`
- Do NOT edit deployed files directly — only source files in this repo
- Do NOT modify OS-level configuration

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `dot_config/polybar/config.ini.tmpl` | Modify | Polybar bar/module config with Nerd Font icons |
| `dot_config/i3/config.tmpl` | Modify | Workspace icon names, powermenu keybinding |
| `dot_config/i3/scripts/executable_powermenu` | Create | Shell script for rofi powermenu |
| `dot_config/rofi/powermenu.rasi` | Create | Rofi theme for powermenu (imports base config.rasi) |
| `dot_config/polybar/executable_launch.sh` | No change | Launch script unchanged |

---

### Task 1: Update polybar font configuration

**Files:**
- Modify: `dot_config/polybar/config.ini.tmpl:40-41`

**Interfaces:**
- Produces: Font declarations that all modules reference for icon rendering

- [ ] **Step 1: Replace font declarations in bar/main section**

Replace lines 40-41:

```ini
font-0 = "Noto Sans CJK SC;2"
font-1 = "DejaVu Sans Mono;2"
```

With:

```ini
font-0 = "Symbols Nerd Font:size=12;1"
font-1 = "JetBrainsMono Nerd Font:size=10;2"
font-2 = "Noto Sans CJK SC:size=10;2"
```

Rationale:
- font-0: Symbols Nerd Font for icons, size=12 with offset=1 to vertically center icons
- font-1: JetBrainsMono Nerd Font for monospace text (also contains icons as fallback)
- font-2: Noto Sans CJK SC for CJK characters

- [ ] **Step 2: Verify template syntax is valid**

Run: `chezmoi execute-template '{{ .colors.base }}' | head -1`
Expected: outputs a hex color like `#1e1e2e`

- [ ] **Step 3: Commit**

```bash
git add dot_config/polybar/config.ini.tmpl
git commit -m "feat(polybar): update font stack for Nerd Font icons"
```

---

### Task 2: Update polybar bar/main section

**Files:**
- Modify: `dot_config/polybar/config.ini.tmpl:16-53`

**Interfaces:**
- Produces: Updated module layout that Task 3-5 modules will fill

- [ ] **Step 1: Update module layout and spacing**

Replace lines 43-45:

```ini
modules-left = i3 xwindow
modules-center =
modules-right = cpu memory network pulseaudio battery date
```

With:

```ini
modules-left = i3 xwindow
modules-center =
modules-right = cpu memory filesystem network pulseaudio date powermenu
```

Also update spacing for better visual density. Replace lines 34-38:

```ini
padding-left = 1
padding-right = 1

module-margin-left = 1
module-margin-right = 1
```

With:

```ini
padding-left = 2
padding-right = 2

module-margin-left = 0
module-margin-right = 0
```

Set module-margin to 0 because we'll use explicit separator characters within module format strings for more control.

- [ ] **Step 2: Commit**

```bash
git add dot_config/polybar/config.ini.tmpl
git commit -m "feat(polybar): update module layout, add filesystem/powermenu"
```

---

### Task 3: Redesign existing polybar modules with Nerd Font icons

**Files:**
- Modify: `dot_config/polybar/config.ini.tmpl:55-157`

**Interfaces:**
- Consumes: Font stack from Task 1, module layout from Task 2
- Produces: Styled modules with icons, consistent separator pattern

**Design conventions for all modules:**
- Module format: `<icon> <value>` with icon in `${colors.overlay1}` and value in `${colors.foreground}`
- Inter-module separator: appended as `%{F${colors.surface1}}│%{F-}` after each module's label
- Icon glyphs use Symbols Nerd Font (font-0)

- [ ] **Step 1: Replace the i3 module (lines 55-76)**

Replace entire `[module/i3]` section:

```ini
[module/i3]
type = internal/i3
format = <label-state> <label-mode>
index-sort = true
strip-wsnumbers = true
label-mode = %mode%
label-mode-padding = 2
label-mode-background = ${colors.alert}
label-mode-foreground = ${colors.background}
label-focused = %icon%
label-focused-background = ${colors.primary}
label-focused-foreground = ${colors.background}
label-focused-padding = 2
label-unfocused = %icon%
label-unfocused-padding = 2
label-unfocused-foreground = ${colors.disabled}
label-visible = %icon%
label-visible-background = ${colors.surface0}
label-visible-padding = 2
label-urgent = %icon%
label-urgent-background = ${colors.alert}
label-urgent-padding = 2

ws-icon-0 = 1;
ws-icon-1 = 2;
ws-icon-2 = 3;
ws-icon-3 = 4;
ws-icon-4 = 5;
ws-icon-default =
```

Note: `strip-wsnumbers = true` shows only the icon portion. The `ws-icon-*` mapping must match the i3 workspace names set in Task 6. The `%icon%` token uses ws-icon mapping, falling back to `ws-icon-default` for workspaces 6-10.

- [ ] **Step 2: Replace the xwindow module (lines 78-82)**

Replace:

```ini
[module/xwindow]
type = internal/xwindow
label = %title:0:50:...%
label-foreground = ${colors.foreground}
label-maxlen = 50
```

With:

```ini
[module/xwindow]
type = internal/xwindow
format = <label>
format-prefix = "  "
format-prefix-foreground = ${colors.overlay1}
label = %title:0:50:...%
label-foreground = ${colors.foreground}
label-maxlen = 50
```

- [ ] **Step 3: Replace the cpu module (lines 84-90)**

Replace:

```ini
[module/cpu]
type = internal/cpu
interval = 2
format-prefix = " CPU "
format-prefix-foreground = ${colors.foreground-alt}
label = %percentage:2%%
label-foreground = ${colors.foreground}
```

With:

```ini
[module/cpu]
type = internal/cpu
interval = 2
format = <label>
format-prefix = " "
format-prefix-foreground = ${colors.overlay1}
label = %percentage:2%% %{F${colors.surface1}}│%{F-}
label-foreground = ${colors.foreground}
```

- [ ] **Step 4: Replace the memory module (lines 92-98)**

Replace:

```ini
[module/memory]
type = internal/memory
interval = 2
format-prefix = " MEM "
format-prefix-foreground = ${colors.foreground-alt}
label = %percentage_used%%
label-foreground = ${colors.foreground}
```

With:

```ini
[module/memory]
type = internal/memory
interval = 2
format = <label>
format-prefix = " "
format-prefix-foreground = ${colors.overlay1}
label = %percentage_used%% %{F${colors.surface1}}│%{F-}
label-foreground = ${colors.foreground}
```

- [ ] **Step 5: Replace the network module (lines 100-110)**

Replace:

```ini
[module/network]
type = internal/network
; Change interface to match your system (ip link show)
interface = wlp2s0
interval = 3
format-connected = <label-connected>
format-connected-foreground = ${colors.foreground}
label-connected = %ifname% %local_ip%
format-disconnected = <label-disconnected>
format-disconnected-foreground = ${colors.disabled}
label-disconnected = disconnected
```

With:

```ini
[module/network]
type = internal/network
interface = wlp2s0
interval = 3
format-connected = <ramp-signal> <label-connected>
format-connected-foreground = ${colors.foreground}
ramp-signal-0 = 
ramp-signal-1 = 
ramp-signal-2 = 
ramp-signal-3 = 
ramp-signal-foreground = ${colors.overlay1}
label-connected = %local_ip% %{F${colors.surface1}}│%{F-}
format-disconnected = <label-disconnected>
format-disconnected-foreground = ${colors.disabled}
label-disconnected =  disconnected %{F${colors.surface1}}│%{F-}
```

- [ ] **Step 6: Replace the pulseaudio module (lines 112-120)**

Replace:

```ini
[module/pulseaudio]
type = internal/pulseaudio
format-volume-prefix = " VOL "
format-volume-prefix-foreground = ${colors.foreground-alt}
format-volume = <label-volume>
label-volume = %percentage%%
label-volume-foreground = ${colors.foreground}
label-muted = muted
label-muted-foreground = ${colors.disabled}
```

With:

```ini
[module/pulseaudio]
type = internal/pulseaudio
format-volume = <ramp-volume> <label-volume>
ramp-volume-0 = 
ramp-volume-1 = 
ramp-volume-2 = 
ramp-volume-3 = 
ramp-volume-foreground = ${colors.overlay1}
label-volume = %percentage%% %{F${colors.surface1}}│%{F-}
label-volume-foreground = ${colors.foreground}
format-muted = <label-muted>
label-muted =  muted %{F${colors.surface1}}│%{F-}
label-muted-foreground = ${colors.disabled}
click-right = pactl set-sink-mute @DEFAULT_SINK@ toggle
```

- [ ] **Step 7: Remove the battery module (lines 122-146)**

Delete the entire `[module/battery]` section (lines 122-146). Battery module is not needed per user request.

- [ ] **Step 8: Replace the date module (lines 148-157)**

Replace:

```ini
[module/date]
type = internal/date
click-left = date.toggle
interval = 1
date = %Y-%m-%d
date-alt = %a %d %b
time = %H:%M:%S
time-alt = %H:%M
label = %date%  %time%
label-foreground = ${colors.foreground}
```

With:

```ini
[module/date]
type = internal/date
interval = 1
date = %Y-%m-%d
date-alt = %a %d %b
time = %H:%M:%S
time-alt = %H:%M
format = <label>
format-prefix = " "
format-prefix-foreground = ${colors.overlay1}
label = %date% %time%
label-foreground = ${colors.foreground}
```

- [ ] **Step 9: Commit**

```bash
git add dot_config/polybar/config.ini.tmpl
git commit -m "feat(polybar): replace text labels with Nerd Font icons, remove battery"
```

---

### Task 4: Add new polybar modules (filesystem, powermenu)

**Files:**
- Modify: `dot_config/polybar/config.ini.tmpl` — append after date module

**Interfaces:**
- Consumes: Separator pattern from Task 3
- Produces: filesystem module displaying disk usage; powermenu module that triggers the script from Task 8

- [ ] **Step 1: Add filesystem module**

Append after the `[module/date]` section:

```ini
[module/filesystem]
type = internal/fs
mount-0 = /
interval = 30
format-mounted = <label-mounted>
format-mounted-prefix = " "
format-mounted-prefix-foreground = ${colors.overlay1}
label-mounted = %percentage_used%% %{F${colors.surface1}}│%{F-}
label-mounted-foreground = ${colors.foreground}
format-unmounted = <label-unmounted>
label-unmounted =  %{F${colors.surface1}}│%{F-}
label-unmounted-foreground = ${colors.disabled}
```

- [ ] **Step 2: Add powermenu module**

Append after the `[module/filesystem]` section:

```ini
[module/powermenu]
type = custom/text
content = 
content-foreground = ${colors.alert}
click-left = ~/.config/i3/scripts/powermenu
```

Note: The power icon has no trailing separator — it is the rightmost module.

- [ ] **Step 3: Commit**

```bash
git add dot_config/polybar/config.ini.tmpl
git commit -m "feat(polybar): add filesystem and powermenu modules"
```

---

### Task 5: Verify polybar config renders correctly

**Files:**
- No changes — verification only

- [ ] **Step 1: Render the template and check for syntax errors**

Run: `chezmoi execute-template < dot_config/polybar/config.ini.tmpl > /tmp/polybar-test.ini && polybar -c /tmp/polybar-test.ini --dump=main 2>&1 | head -30`
Expected: No parse errors. Module list should show: `i3 xwindow` (left), empty (center), `cpu memory filesystem network pulseaudio date powermenu` (right).

- [ ] **Step 2: Check icon rendering in a test bar**

Run: `polybar -c /tmp/polybar-test.ini main &` then after a few seconds `killall polybar`
Expected: Bar appears briefly with icons visible (no empty squares/boxes).

- [ ] **Step 3: Commit (if any fixes were needed)**

Only commit if fixes were required during verification.

---

### Task 6: Update i3 workspace names with icons

**Files:**
- Modify: `dot_config/i3/config.tmpl:32-52`

**Interfaces:**
- Produces: Workspace names with icon prefixes that match polybar's `ws-icon-*` mapping (Task 3 Step 1)

- [ ] **Step 1: Replace workspace definitions and keybindings**

Replace lines 32-52:

```
# Workspace key bindings
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+6 workspace number 6
bindsym $mod+7 workspace number 7
bindsym $mod+8 workspace number 8
bindsym $mod+9 workspace number 9
bindsym $mod+0 workspace number 10

bindsym $mod+Ctrl+1 move container to workspace number 1
bindsym $mod+Ctrl+2 move container to workspace number 2
bindsym $mod+Ctrl+3 move container to workspace number 3
bindsym $mod+Ctrl+4 move container to workspace number 4
bindsym $mod+Ctrl+5 move container to workspace number 5
bindsym $mod+Ctrl+6 move container to workspace number 6
bindsym $mod+Ctrl+7 move container to workspace number 7
bindsym $mod+Ctrl+8 move container to workspace number 8
bindsym $mod+Ctrl+9 move container to workspace number 9
bindsym $mod+Ctrl+0 move container to workspace number 10
```

With:

```
set $ws1 "1:"
set $ws2 "2:"
set $ws3 "3:"
set $ws4 "4:"
set $ws5 "5:"

# Workspace key bindings
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+6 workspace number 6
bindsym $mod+7 workspace number 7
bindsym $mod+8 workspace number 8
bindsym $mod+9 workspace number 9
bindsym $mod+0 workspace number 10

bindsym $mod+Ctrl+1 move container to workspace number 1
bindsym $mod+Ctrl+2 move container to workspace number 2
bindsym $mod+Ctrl+3 move container to workspace number 3
bindsym $mod+Ctrl+4 move container to workspace number 4
bindsym $mod+Ctrl+5 move container to workspace number 5
bindsym $mod+Ctrl+6 move container to workspace number 6
bindsym $mod+Ctrl+7 move container to workspace number 7
bindsym $mod+Ctrl+8 move container to workspace number 8
bindsym $mod+Ctrl+9 move container to workspace number 9
bindsym $mod+Ctrl+0 move container to workspace number 10
```

Note: Workspace variables `$ws1`-`$ws5` are defined for future use (e.g., `assign [class="..."] $ws1`), but keybindings still use `workspace number N` which matches the numeric prefix of the named workspaces.

- [ ] **Step 2: Commit**

```bash
git add dot_config/i3/config.tmpl
git commit -m "feat(i3): add icon names for workspaces 1-5"
```

---

### Task 7: Replace i3-nagbar with rofi powermenu keybinding

**Files:**
- Modify: `dot_config/i3/config.tmpl:121`

**Interfaces:**
- Consumes: Powermenu script from Task 8

- [ ] **Step 1: Replace the exit keybinding**

Replace line 121:

```
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'Exit i3?' -b 'Yes' 'i3-msg exit'"
```

With:

```
bindsym $mod+Shift+e exec --no-startup-id ~/.config/i3/scripts/powermenu
```

- [ ] **Step 2: Commit**

```bash
git add dot_config/i3/config.tmpl
git commit -m "feat(i3): replace i3-nagbar with rofi powermenu"
```

---

### Task 8: Create powermenu shell script

**Files:**
- Create: `dot_config/i3/scripts/executable_powermenu`

**Interfaces:**
- Produces: `~/.config/i3/scripts/powermenu` script invoked by both i3 keybinding (Task 7) and polybar module (Task 4)
- Consumes: `powermenu.rasi` theme from Task 9

- [ ] **Step 1: Create the script**

Create `dot_config/i3/scripts/executable_powermenu`:

```sh
#!/bin/sh

lock=" Lock"
logout=" Logout"
suspend=" Suspend"
reboot=" Reboot"
shutdown=" Shutdown"

chosen=$(printf "%s\n%s\n%s\n%s\n%s\n" "$lock" "$logout" "$suspend" "$reboot" "$shutdown" \
    | rofi -dmenu -i -p "Power" -theme ~/.config/rofi/powermenu.rasi -no-custom)

case "$chosen" in
    "$lock")    i3lock ;;
    "$logout")  i3-msg exit ;;
    "$suspend") systemctl suspend ;;
    "$reboot")  systemctl reboot ;;
    "$shutdown") systemctl poweroff ;;
esac
```

- [ ] **Step 2: Verify chezmoi executable convention**

The `executable_` prefix in chezmoi automatically sets the execute permission. Verify:

Run: `chezmoi source-path ~/.config/i3/scripts/powermenu`
Expected: outputs the source file path

- [ ] **Step 3: Test the script manually**

Run: `chezmoi apply -v ~/.config/i3/scripts/powermenu`
Then: `~/.config/i3/scripts/powermenu`
Expected: Rofi window appears with 5 options. Press Escape to dismiss.

- [ ] **Step 4: Commit**

```bash
git add dot_config/i3/scripts/executable_powermenu
git commit -m "feat(i3): add rofi powermenu script"
```

---

### Task 9: Create powermenu rofi theme

**Files:**
- Create: `dot_config/rofi/powermenu.rasi`

**Interfaces:**
- Consumes: Base theme variables from `dot_config/rofi/config.rasi.tmpl` (via `@import`)
- Produces: Styled rofi powermenu matching Catppuccin Mocha palette

- [ ] **Step 1: Create the theme file**

Create `dot_config/rofi/powermenu.rasi`:

```rasi
@import "~/.config/rofi/config.rasi"

configuration {
    show-icons:      false;
    disable-history: true;
    hide-scrollbar:  true;
    sidebar-mode:    false;
}

window {
    width:            160px;
    padding:          20px;
    border:           2px;
    border-color:     @border-col;
    border-radius:    8;
    background-color: @bg-col;
}

mainbox {
    border:  0;
    padding: 0;
}

inputbar {
    children: [ prompt ];
    padding:  0;
}

prompt {
    padding:     8px;
    text-color:  @blue;
    border:      0 0 2px 0;
    border-color: @border-col;
}

listview {
    lines:        5;
    columns:      1;
    fixed-height: 0;
    border:       0;
    spacing:      4px;
    scrollbar:    false;
    padding:      8px 0px 0px;
}

element {
    border:  0;
    padding: 6px 8px;
    border-radius: 4;
}

element normal {
    background-color: @bg-col;
    text-color:       @fg-col;
}

element selected {
    background-color: @selected-col;
    text-color:       @fg-col;
}

element urgent {
    background-color: @urgent;
    text-color:       @bg-col;
}
```

Note: This theme does NOT use `.tmpl` extension because it has no chezmoi template variables — it imports `config.rasi` which IS a template and provides all color variables at runtime.

- [ ] **Step 2: Test the theme renders correctly**

Run: `echo -e "Lock\nLogout\nSuspend\nReboot\nShutdown" | rofi -dmenu -theme ~/.config/rofi/powermenu.rasi`
Expected: A narrow, compact rofi window with 5 options styled in Catppuccin Mocha colors.

- [ ] **Step 3: Commit**

```bash
git add dot_config/rofi/powermenu.rasi
git commit -m "feat(rofi): add powermenu theme"
```

---

### Task 10: Integration test — apply all changes and verify

**Files:**
- No changes — verification only

- [ ] **Step 1: Apply all changes**

Run: `chezmoi apply -v`

Expected: All files apply without errors.

- [ ] **Step 2: Restart i3 to pick up workspace name changes**

Run: `i3-msg restart`

Expected: i3 restarts, polybar relaunches automatically (via `exec_always` in i3 config).

- [ ] **Step 3: Verify polybar displays correctly**

Check:
1. Left side: workspace icons for ws1-5, numbers for 6-10
2. Left side after workspaces: window title with icon
3. Right side: CPU | MEM | Disk | IP | Vol% | Date Time | power icon
4. All icons render as symbols (no empty boxes)
5. Clicking power icon opens rofi powermenu

- [ ] **Step 4: Verify i3 keybindings**

Check:
1. `$mod+1` through `$mod+0` switch workspaces
2. `$mod+Shift+e` opens rofi powermenu (not i3-nagbar)
3. Powermenu Lock/Logout/Suspend/Reboot/Shutdown all work

- [ ] **Step 5: Final commit if any fixes needed**

Only commit if integration testing revealed issues.
