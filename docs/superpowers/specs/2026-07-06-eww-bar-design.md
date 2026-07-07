# Eww Bar — Polybar Replacement Design

## Overview

Replace polybar with eww widgets, providing a modern glassmorphism bar with popup overlays for calendar, notifications, network, control center, and power menu. Architecture: single bar window + 5 independent popup windows.

## Color Palette

All colors from `.chezmoi.yaml.tmpl` data block (Catppuccin Mocha):

| Token | Hex | Usage |
|-------|-----|-------|
| `crust` | #11111b | Bar background |
| `base` | #1e1e2e | Popup backgrounds |
| `surface0` | #313244 | Inactive dots, hover backgrounds, notification lines |
| `surface1` | #45475a | Slider track |
| `surface2` | #585b70 | Occupied non-focused workspace dots |
| `overlay0` | #6c7086 | Timestamps, per-item delete button |
| `overlay1` | #7f849c | — |
| `subtext0` | #a6adc8 | Secondary text, all default icons, labels |
| `subtext1` | #bac2de | Calendar day numbers |
| `text` | #cdd6f4 | Primary text, time display, hover icons |
| `lavender` | #b4befe | Focus workspace pill, calendar today, slider fill |
| `mauve` | #cba6f7 | Notification badge, group labels |
| `red` | #f38ba8 | Urgent workspace, low battery, clear all hover |
| `green` | #a6e3a1 | Charging indicator, active toggle tile accent bar |
| `peach` | #fab387 | DND bell icon |

## Eww Windows (6 total)

| Window | Type | Anchor | Purpose |
|--------|------|--------|---------|
| `bar` | dock | top, full-width | Main bar |
| `calendar-popup` | normal | below time module, right-aligned | Calendar popover |
| `notification-popup` | normal | below bell module, right-aligned to screen edge | Notification history drawer |
| `control-center` | normal | below control center module | WiFi/BT/volume/brightness |
| `network-popup` | normal | below network icon module | WiFi network list |
| `power-menu` | normal | screen center | Lock/Logout/Suspend/Power Off |

All popups: 12px border-radius.

**Interaction rule**: only one popup open at a time. Opening a new popup closes any other. Clicking outside closes all.

**Popup animation**: `revealer` slideup + crossfade, 200ms. Dismiss: reversed same animation.

## Bar Layout

```
[tray][ ][        ]      [  ][  ][  ][  HH:MM  ][  ]
← Tray/Power/Workspaces   Net CC  Bat Time/Date  Notif
```

**Left**: System tray → Power button → Workspace dots  
**Center**: empty  
**Right**: Network icon → Control center → Battery → Time/Date → Notifications

### Visual Hierarchy (strong → weak)

1. **Time/Date** — `text` color, font 2-4px larger than other modules
2. **Focused workspace pill** — `lavender` background
3. **Notification bell (with unread)** — `mauve` highlight + `red` dot badge
4. **All other icons** — `subtext0`, hover → `text`

### Module Spacing

- Same-group: 8px
- Between groups: 16px
- Groups: [Tray + Power + Workspaces] | [Net + CC + Battery] | [Time] | [Notifications]
- No divider lines — spacing only

### Module Details

#### System Tray
- eww native `systray` widget
- `icon-size` matched to bar height, spacing 4px
- Leftmost position for natural visual balance

#### Power Button
- Nerd Font  icon, `subtext0`
- Hover: `surface0` pill background, 100ms fade
- Click: opens power-menu popup

#### Workspaces
- **Focused**: pill shape (20×14px rounded rect), `lavender` fill
- **Occupied, not focused**: 6px solid circle, `surface2`
- **Idle**: 6px solid circle, `surface0`
- **Urgent**: pill shape, `red` fill
- Click workspace dot to switch, scroll to prev/next

#### Network Icon
- WiFi:  icon + `subtext0`
- Wired:  icon + `subtext0`
- Disconnected:  icon + `overlay0`
- Hover: `surface0` pill background
- Click: opens network-popup

#### Control Center Button
-  icon, `subtext0`, hover `surface0` pill
- Click: opens control-center popup

#### Battery
- Charging:  icon + `green` subtle glow (`box-shadow: 0 0 4px rgba(166, 227, 161, 0.4)`)
- Discharging: / /  by level, `subtext0`
- Low (<15%):  icon, `red`
- No percentage displayed — hover tooltip shows percentage

#### Time/Date
- Primary: `HH:MM`, larger font
- Secondary: `Mon 07/06`, `subtext0`, smaller, below time
- Click: opens calendar popup

#### Notifications Bell
-  icon (no DND) /  icon (DND active, `peach`)
- No unread + DND off: `subtext0`
- Has unread + DND off: `mauve` + small 6px `red` dot badge (top-right)
- DND active: `peach`
- Left-click: opens notification-popup
- Right-click: toggle DND (`dunstctl set-paused toggle`)

### Micro-interactions

- **Hover**: icon modules get `surface0` rounded-pill background, 100ms fade
- **Click**: subtle scale-down (`transform: scale(0.95)`), 80ms
- **Popup open**: corresponding bar module highlighted (`surface0` persistent background)
- **Popup animation**: `revealer` slideup + crossfade, 200ms

## Calendar Popup

**Size**: ~340×320px  
**Position**: below time module, right-aligned to time text

```
┌──────────────────────────────┐
│  Monday                      │  ← Today's weekday, text, large
│  July 6                      │  ← Today's date, lavender, large bold
│                              │
│  Mo Tu We Th Fr Sa Su        │  ← subtext0, small, wide letter-spacing
│         1  2  3  4  5        │
│   6  7  8  9 10 11 12       │  ← cell padding 28×28px minimum
│  13 14 15 16 17 18 19       │
│  20 21 22 23 24 25 26       │  ← "6" today: lavender pill
│  27 28 29 30 31             │
│          ◂   Jul   ▸         │  ← month switch, bottom-right, subtext0
└──────────────────────────────┘
```

- **Hero area**: top two lines — weekday + date, the information payoff for clicking
- **Month switch**: `◂` and `▸` flanking current month name in a single horizontal row. `subtext0`, hover → `lavender`, 16px spacing between arrows and month name
- **Cell padding**: each date cell ≥ 28×28px (at 1x), number centered
- **Today**: lavender pill (matches workspace pill style)
- **Non-current-month dates**: not displayed
- Uses eww native `calendar` widget

## Notification Popup

**Size**: ~380×420px, scrollable  
**Position**: below bell module, right-aligned to screen edge

```
┌───────────────────────────────────┐
│  Notifications                     │
│                                    │
│  JUST NOW                          │  ← group label, mauve, small caps
│  󰍡  Screenshot saved               │  ← icon + title same line, text
│     ~/Pictures/...png              │  ← summary full width, subtext0
│                                    │
│  EARLIER                           │
│  󰇗  OCR text copied                │
│     (no text recognized)           │
│  ─────────────────────────         │  ← surface1 thin line between items
│  󰂵  Volume changed                 │
│     65%                            │
│                                    │
│           󰆔 Clear all              │  ← bottom center, subtext0, hover → red
└───────────────────────────────────┘
```

- **Flat list**, no card-within-card — items separated by `surface1` thin lines
- **Time grouping**: "JUST NOW" / "EARLIER" in `mauve` small caps
- **Unread indicator**: 3px `mauve` vertical line on left edge of notification
- **Per-item delete**: hover reveals `×` button on right, `overlay0`, click removes
- **Clear all**: bottom center, `subtext0` +  icon, hover → `red`
- **Hover item**: `surface0` background
- **Empty state**: title + single line "All caught up" in `subtext0`

**Data source**: `dunstctl history` parsed by script → eww variable, polled every 2s

## Network Popup

**Size**: ~300×240px
**Position**: below network icon module

```
┌───────────────────────────┐
│  Network                   │
│                            │
│  󰤉  Home-Network    󰜺      │  ← current connection + disconnect button
│     192.168.1.42           │
│                            │
│  ────────────────────────  │
│                            │
│  󰤩  Guest-WiFi        󰉂    │  ← available network list
│  󰤩  Coffee-Shop       󰉂    │     󰉂 = saved/known
│  󰤩  Neighbor-Net     󰉃    │     󰉃 = needs password
│                            │
│           󰇘  Manage        │  ← open nm-connection-editor
└───────────────────────────┘
```

- **Current connection**: at top, icon + SSID + IP, disconnect button ( ) on right
- **Available networks**: flat list below a thin `surface1` divider
  - Known/saved network:  icon +  no-lock icon
  - Unknown network:  icon +  lock icon
- **Manage**: bottom center, `subtext0` + gear icon, hover → `text`, opens `nm-connection-editor`
- **Click network**: known networks `nmcli device wifi connect <SSID>`; unknown networks open `nm-connection-editor` for password entry (eww cannot present system auth dialogs)

**Data source**: `nmcli -t -f SSID,SECURITY,IN-USE device wifi list` parsed by script → JSON. Script polls at 5s but exits early (output empty) when `eww active-windows | grep -q network-popup` returns false — effectively polls only while the popup is open.

## Control Center

**Size**: ~360×280px  
**Position**: below control center module

```
┌──────────────────────────────────────┐
│                                      │
│  ┌──────────┐  ┌──────────┐         │
│  │ 󰤉  WiFi  │  │ 󰂯  BT    │         │  ← toggle tiles
│  │ Connected │  │  Off     │         │
│  └──────────┘  └──────────┘         │
│                                      │
│  󰕾  Volume                     65%  │
│  ═══════════════●══════════          │  ← slider
│                                      │
│  󰖨  Brightness                  80% │
│  ══════════════════════●══          │
│                                      │
└──────────────────────────────────────┘
```

### Toggle Tiles

- 2×1 grid, each tile ~160×64px, `surface0` background, 8px border-radius
- **On state**: 3px `green` left accent bar, icon+name `text`, status `subtext0`
- **Off state**: no accent bar, icon+name `subtext0`, status `overlay0`
- **Hover**: `surface1` background
- **WiFi**: left-click toggle on/off; right-click `nm-connection-editor`
- **BT**: left-click toggle on/off; right-click `blueman-manager`

### Volume Slider

- Icons by level: / / 
- Muted: `overlay0`; active: `subtext0`
- Track: `surface1`, filled portion `lavender`
- Thumb: `text`, circular
- Percentage: `subtext0`, right-aligned
- Click icon: toggle mute

### Brightness Slider

- Icon: , `subtext0`
- Style same as volume slider
- Source: `brightnessctl`

## Power Menu

**Size**: ~420×120px  
**Position**: screen center

```
┌─────────────────────────────────────────────┐
│                                             │
│      󰒜          󰐾          󰤄          󰐥    │
│     Lock       Logout     Suspend    Power Off│
│                                             │
└─────────────────────────────────────────────┘
```

- Single row, 4 actions evenly spaced
- Each: large icon (24px) above + small label below, `subtext0`
- All same `text` color — no special treatment for Power Off
- Hover: `surface0` pill background
- Click: execute immediately, no confirmation
- After action: close popup automatically

## Data Flow & Scripts

### eww Variables

| Variable | Source | Poll Interval |
|----------|--------|---------------|
| `workspaces` | `i3-msg -t get_workspaces` | 500ms |
| `cal_month` / `cal_year` | eww internal state | on user switch |
| `notifications` | `dunstctl history` script | 2s |
| `notif_count` | same script | 2s |
| `dnd` | `dunstctl is-paused` | 5s |
| `volume` | `pamixer --get-volume` | 1s |
| `muted` | `pamixer --get-mute` | 1s |
| `brightness` | `brightnessctl info` | 1s |
| `wifi_on` | `nmcli radio wifi` | 5s |
| `wifi_name` | `nmcli -t -f NAME c show --active` | 5s |
| `wifi_icon` | derived: / /  from `nmcli` output | 5s |
| `wifi_networks` | `nmcli dev wifi list` | 5s (when popup open) |
| `bt_on` | `rfkill list bluetooth` — check soft/hard blocked | 5s |
| `battery_percent` | `/sys/class/power_supply/BAT0/capacity` | 5s |
| `battery_charging` | `/sys/class/power_supply/BAT0/status` | 5s |
| `time` / `date` | `EWW_TIME` magic variable | built-in, 1s |

### Script Files (in `dot_config/eww/scripts/`)

| Script | Function |
|--------|----------|
| `executable_launch.sh` | DPI detection, set `scale` var, start daemon, open bar |
| `executable_workspaces.sh` | Parse i3-msg → yuck workspace list |
| `executable_notifications.sh` | Parse `dunstctl history` → JSON notification list |
| `executable_volume.sh` | Get volume + mute state |
| `executable_brightness.sh` | Get brightness |
| `executable_network.sh` | WiFi connection status + icon type + network list |
| `executable_battery.sh` | Battery status |
| `executable_toggle-wifi.sh` | `nmcli radio wifi on/off` |
| `executable_toggle-bt.sh` | `rfkill block/unblock bluetooth` |
| `executable_toggle-dnd.sh` | `dunstctl set-paused toggle` |
| `executable_power.sh` | Execute lock/logout/suspend/reboot/poweroff |

## DPI Adaptation

No temporary files. Launch script reads `xrdb` DPI and runs `eww update scale=<value>` before opening the bar.

| Mode | DPI Range | Bar H | Icon | Font | WS Dot | WS Pill | Cell | Spacing (8/16) |
|------|-----------|-------|------|------|--------|---------|------|----------------|
| 1x   | < 144     | 38px  | 14px | 12px | 6px    | 20×14px | 28px | 8px / 16px     |
| 1.5x | 144–191   | 54px  | 20px | 17px | 8px    | 28×20px | 34px | 12px / 24px    |
| 2x   | ≥ 192     | 72px  | 28px | 24px | 10px   | 36×24px | 40px | 16px / 32px    |

Notes:
- Dot sizes scale non-linearly (6→8→10px, not 6→9→12px) to remain visually proportional
- Cell padding scales less aggressively (28→34→40px) to avoid wasting popup space at high DPI
- Spacing scales proportionally but is independently set per tier

Implementation: launch script detects DPI → `eww update scale=1.5` → then opens bar window. The bar window's root `box` has an inline style that bridges the yuck variable into CSS:

```yuck
(defwindow bar :stacking "overlay" :class "eww-bar"
  (box :style "--eww-scale: ${scale};" ...))
```

scss then references:
```scss
.bar-module { font-size: calc(14px * var(--eww-scale)); }
```

**Critical ordering**: `eww update scale` must run BEFORE `eww open bar`, otherwise the CSS variable is undefined at render time.

## i3 Integration Changes

- Remove: `exec --no-startup-id ~/.config/polybar/launch.sh`
- Add: `exec --no-startup-id ~/.config/eww/scripts/launch.sh`
- Picom: replace `class_g = 'Polybar'` with `class_g = 'eww-bar'` and `class_g = 'eww'`
- No `bar {}` block in i3 config (same as current)

**Window class names**:
- Bar: `eww-bar` (via `--class eww-bar` in launch script)
- Popups: `eww` (default)

## Chezmoi File Structure

eww requires a single yuck entry point. yuck definitions go in one file with section comments. scss can use `@import` for sub-files.

```
dot_config/eww/
├── eww.yuck.tmpl       ← single yuck entry — all windows + variables + widgets
├── eww.scss.tmpl       ← main scss, @imports styles/
├── styles/
│   ├── colors.scss.tmpl
│   ├── bar.scss
│   ├── calendar.scss
│   ├── notifications.scss
│   ├── network.scss
│   ├── control-center.scss
│   └── power-menu.scss
└── scripts/
    ├── executable_launch.sh
    ├── executable_workspaces.sh
    ├── executable_notifications.sh
    ├── executable_volume.sh
    ├── executable_brightness.sh
    ├── executable_network.sh
    ├── executable_battery.sh
    ├── executable_toggle-wifi.sh
    ├── executable_toggle-bt.sh
    ├── executable_toggle-dnd.sh
    └── executable_power.sh
```

`eww.yuck.tmpl` internal structure:
```yuck
;; ============================================ VARIABLES ============================================

;; ============================================ BAR WINDOW ============================================

;; ============================================ CALENDAR POPUP ============================================

;; ============================================ NOTIFICATION POPUP ============================================

;; ============================================ NETWORK POPUP ============================================

;; ============================================ CONTROL CENTER ============================================

;; ============================================ POWER MENU ============================================
```

All `.tmpl` files use Go templates to inject Catppuccin Mocha color variables from `.chezmoi.yaml.tmpl`. Polybar directory is preserved (not deleted) so user can switch back.
