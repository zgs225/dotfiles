# Eww Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace polybar with eww widgets providing a modern glassmorphism bar with popup overlays for calendar, notifications, network, control center, and power menu.

**Architecture:** Single bar window (dock) + 5 independent popup windows. All data polling uses eww `defpoll` (no background bash loops). Popup open/close managed via `open-popup.sh` script. DPI adaptation via per-tier variables set by launch script before opening windows. Notification history via `dbus-monitor` daemon writing JSON log file.

**Tech Stack:** eww 0.5.0, bash scripts, dbus-monitor for dunst notification logging, chezmoi Go templates with Catppuccin Mocha colors from `.chezmoi.yaml.tmpl`

## Global Constraints

- **Color Palette:** All Catppuccin Mocha colors injected from `.chezmoi.yaml.tmpl` via Go templates
- **Fonts:** JetBrainsMono Nerd Font (text), Symbols Nerd Font (icons), Noto Sans CJK SC (CJK)
- **DPI Modes:** 1x (<144), 1.5x (144-191), 2x (≥192) — individually tuned per tier, NOT simple multiplication. Set via `eww update` in launch script as variables: `bar_height`, `icon_size`, `font_size`, `dot_size`, `pill_w`, `pill_h`, `cell_pad`
- **Popup interaction:** Only one popup open at a time; managed via `open-popup.sh` + `popup_open` state variable
- **Popup animation:** CSS `@keyframes popup-in` on `.revealer` class — translateY(-8px) + opacity, 200ms
- **Polling:** Use eww `defpoll` for ALL polling — no `while true` loop in launch script (exception: `notif-logger.sh` for D-Bus monitoring runs as one background daemon)
- **SCSS math:** Use `calc()` everywhere — never SCSS `*` on CSS `var()` references
- **Polybar directory:** Preserved (not deleted) for rollback

---

### Task 1: Create directory structure and launch+popup scripts

**Files:**
- Create: `dot_config/eww/scripts/executable_launch.sh`
- Create: `dot_config/eww/scripts/executable_open-popup.sh`

**Interfaces:**
- Produces: `~/.config/eww/scripts/launch.sh` — sets DPI vars, starts daemon + notif-logger, opens bar
- Produces: `~/.config/eww/scripts/open-popup.sh` — receives popup name as `$1`, closes any open popup, opens requested one

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p dot_config/eww/scripts dot_config/eww/styles
```

- [ ] **Step 2: Write launch.sh**

```bash
#!/usr/bin/env bash
# Eww bar launch — DPI detection, variable injection, daemon start

DPI=$(xrdb -query | awk '/Xft.dpi/ {print $2}')
if [ -n "$DPI" ] && [ "$DPI" -ge 192 ]; then
    BAR_HEIGHT=72;  ICON_SIZE=28; FONT_SIZE=24
    DOT_SIZE=10;    PILL_W=36;  PILL_H=24; CELL_PAD=40
elif [ -n "$DPI" ] && [ "$DPI" -ge 144 ]; then
    BAR_HEIGHT=54;  ICON_SIZE=20; FONT_SIZE=17
    DOT_SIZE=8;     PILL_W=28;  PILL_H=20; CELL_PAD=34
else
    BAR_HEIGHT=38;  ICON_SIZE=14; FONT_SIZE=12
    DOT_SIZE=6;     PILL_W=20;  PILL_H=14; CELL_PAD=28
fi

eww kill 2>/dev/null
sleep 0.3

eww daemon

eww update bar_height=$BAR_HEIGHT icon_size=$ICON_SIZE font_size=$FONT_SIZE \
          dot_size=$DOT_SIZE pill_w=$PILL_W pill_h=$PILL_H cell_pad=$CELL_PAD \
          popup_open="none"

eww open bar

# Start D-Bus notification log monitor daemon
~/.config/eww/scripts/notif-logger.sh &
```

- [ ] **Step 3: Write open-popup.sh**

```bash
#!/usr/bin/env bash
# Popup state manager — ensures only one popup open at a time
# Usage: open-popup.sh <popup-name>

NEW="$1"
CURRENT=$(eww get popup_open 2>/dev/null || echo "none")

if [ "$CURRENT" = "$NEW" ]; then
    eww close "$NEW"
    eww update popup_open="none"
else
    [ "$CURRENT" != "none" ] && eww close "$CURRENT" 2>/dev/null
    eww open "$NEW"
    eww update popup_open="$NEW"
fi
```

- [ ] **Step 4: Make executable and commit**

```bash
chmod +x dot_config/eww/scripts/executable_launch.sh dot_config/eww/scripts/executable_open-popup.sh
git add dot_config/eww/scripts/executable_launch.sh dot_config/eww/scripts/executable_open-popup.sh
git commit -m "feat(eww): add launch script with DPI detection and popup manager"
```

---

### Task 2: Create eww.yuck.tmpl with defpoll and all window definitions

**Files:**
- Write: `dot_config/eww/eww.yuck.tmpl`

**Interfaces:**
- Produces: 6 window definitions (bar + 5 popups) with correct geometry, all `defvar` declarations, all `defpoll` bindings

- [ ] **Step 1: Write eww.yuck.tmpl**

```yuck
;; ============================================ DPI VARIABLES ============================================
;; Set by launch script via `eww update` before bar window opens

(defvar bar_height 38)
(defvar icon_size 14)
(defvar font_size 12)
(defvar dot_size 6)
(defvar pill_w 20)
(defvar pill_h 14)
(defvar cell_pad 28)

;; ============================================ STATE VARIABLES ============================================

(defvar workspaces "")
(defvar popup_open "none")

(defvar time "00:00")
(defvar date "Mon 01/01")
(defvar calendar_weekday "Monday")
(defvar calendar_monthday "1")
(defvar calendar_month 1)
(defvar calendar_year 2026)

(defvar notifications "")
(defvar notif_count 0)
(defvar dnd false)

(defvar volume 100)
(defvar muted false)
(defvar brightness 100)

(defvar wifi_icon "󰤭")
(defvar wifi_name "Disconnected")
(defvar wifi_on 0)
(defvar wired 0)
(defvar wifi_networks "")

(defvar bt_on 0)

(defvar battery_percent 100)
(defvar battery_charging false)
(defvar battery_icon "󰁹")

;; ============================================ DATA POLLING (defpoll) ============================================

(defpoll workspaces :interval "500ms"
  "~/.config/eww/scripts/workspaces.sh")

(defpoll time :interval "1s"
  "date +'%H:%M'")

(defpoll date :interval "30s"
  "date +'%a %m/%d'")

(defpoll calendar_weekday :interval "30s"
  "date +'%A'")

(defpoll calendar_monthday :interval "30s"
  "date +'%-d'")

(defpoll calendar_month :interval "30s"
  "date +'%-m'")

(defpoll calendar_year :interval "30s"
  "date +'%Y'")

(defpoll notif_vars :interval "2s"
  "~/.config/eww/scripts/notifications.sh")

(defpoll dnd :interval "5s"
  "dunstctl is-paused 2>/dev/null && echo true || echo false")

(defpoll volume :interval "1s"
  "pamixer --get-volume 2>/dev/null || echo 100")

(defpoll muted :interval "1s"
  "pamixer --get-mute 2>/dev/null || echo false")

(defpoll brightness :interval "1s"
  "brightnessctl info 2>/dev/null | grep -oP '(\\d+)%' | head -1 | tr -d '%' || echo 100")

(defpoll network_status :interval "5s"
  "~/.config/eww/scripts/network.sh")

(defpoll battery_status :interval "5s"
  "~/.config/eww/scripts/battery.sh")

;; ============================================ BAR WINDOW ============================================

(defwindow bar
  :stacking "overlay"
  :class "eww-bar"
  :exclusive true
  :geometry (geometry
    :width "100%"
    :height "${bar_height}px"
    :anchor "top left")

  (box :class "bar-inner" :spacing 0

    ;; ── Left: Tray, Power, Workspaces ──
    (box :class "bar-group bar-start" :halign "start" :spacing 8
      (systray :icon-size "${icon_size}" :spacing 4)
      (button :class "module-btn"
        :onclick "~/.config/eww/scripts/open-popup.sh power-menu"
        (label :text "󰌆" :class "module-icon"))
      (box :class "workspaces-container" :spacing 6
        (literal :content "${workspaces}")))

    ;; ── Spacer ──
    (box :class "bar-spacer" :hexpand true)

    ;; ── Right: Network, CC, Battery ──
    (box :class "bar-group" :halign "end" :spacing 8
      (button :class "module-btn"
        :onclick "~/.config/eww/scripts/open-popup.sh network-popup"
        (overlay
          (label :text "${wifi_icon}" :class "module-icon")
          (label :text "" :class "net-dot net-dot-${wired > 0 ? 'eth' : (wifi_on > 0 ? 'on' : 'off')}")))
      (button :class "module-btn"
        :onclick "~/.config/eww/scripts/open-popup.sh control-center"
        (label :text "󰒥" :class "module-icon"))
      (button :class "module-btn battery-btn"
        :tooltip "${battery_percent}%"
        (label :text "${battery_icon}" :class "module-icon bat-${battery_charging ? 'charging' : (battery_percent < 15 ? 'low' : 'normal')}")))

    ;; ── Group spacer ──
    (box :width 16)

    ;; ── Time/Date ──
    (button :class "module-btn time-btn"
      :onclick "~/.config/eww/scripts/open-popup.sh calendar-popup"
      (box :orientation "v" :spacing 0
        (label :text "${time}" :class "time-main")
        (label :text "${date}" :class "time-sub")))

    ;; ── Group spacer ──
    (box :width 16)

    ;; ── Notifications Bell ──
    (button :class "module-btn notif-btn"
      :onclick "~/.config/eww/scripts/open-popup.sh notification-popup"
      :onrightclick "dunstctl set-paused toggle"
      (overlay
        (label :text "${dnd ? '󰂠' : '󰂞'}"
          :class "notif-bell notif-bell-${dnd ? 'dnd' : (notif_count > 0 ? 'unread' : 'none')}")
        (label :text "${notif_count}"
          :class "notif-badge"
          :visible "${notif_count > 0 && !dnd}")))))

;; ============================================ CALENDAR POPUP ============================================

(defwindow calendar-popup
  :stacking "overlay"
  :geometry (geometry :width "340px" :height "320px" :anchor "top right")
  :style "calendar-popup { --cell-pad: ${cell_pad}px; }"
  (box :class "popup revealer" :orientation "v" :spacing 8
    (box :orientation "v" :spacing 2 :class "calendar-hero"
      (label :text "${calendar_weekday}" :class "calendar-weekday")
      (label :text "${calendar_monthday}" :class "calendar-date"))
    (calendar
      :day "${calendar_monthday}"
      :month "${calendar_month}"
      :year "${calendar_year}"
      :show-heading true
      :show-day-names true)))

;; ============================================ NOTIFICATION POPUP ============================================

(defwindow notification-popup
  :stacking "overlay"
  :geometry (geometry :width "380px" :height "420px" :anchor "top right")
  (box :class "popup revealer" :orientation "v"
    (box :class "notif-header"
      (label :text "Notifications" :class "popup-title")
      (button :class "notif-clear-all"
        :onclick "~/.config/eww/scripts/clear-notifs.sh"
        (label :text "󰆔")))
    (box :orientation "v" :class "notif-scroll"
      (literal :content "${notifications}"))))

;; ============================================ NETWORK POPUP ============================================

(defwindow network-popup
  :stacking "overlay"
  :geometry (geometry :width "300px" :height "240px" :anchor "top right")
  (box :class "popup revealer" :orientation "v" :spacing 8
    (label :text "Network" :class "popup-title")
    (box :class "current-connection" :spacing 8
      (label :text "${wifi_icon}" :class "module-icon")
      (box :orientation "v"
        (label :text "${wifi_name}" :class "conn-name")
        (label :text "${wired > 0 ? 'Ethernet' : (wifi_on > 0 ? 'Connected' : 'Disconnected')}" :class "conn-status")))
    (box :class "separator-line")
    (box :orientation "v" :class "wifi-list" :spacing 4
      (literal :content "${wifi_networks}"))
    (box :class "separator-line")
    (button :class "popup-footer-btn"
      :onclick "nm-connection-editor &"
      (label :text "󰇘  Manage"))))

;; ============================================ CONTROL CENTER ============================================

(defwindow control-center
  :stacking "overlay"
  :geometry (geometry :width "360px" :height "280px" :anchor "top right")
  (box :class "popup revealer" :orientation "v" :spacing 12
    (box :spacing 8
      (button :class "toggle-tile ${wifi_on > 0 ? 'on' : 'off'}"
        :onclick "~/.config/eww/scripts/toggle-wifi.sh"
        :onrightclick "nm-connection-editor &"
        (box :orientation "v" :spacing 4
          (label :text "󰤉" :class "tile-icon")
          (label :text "WiFi" :class "tile-label")
          (label :text "${wifi_on > 0 ? wifi_name : 'Off'}" :class "tile-status")))
      (button :class "toggle-tile ${bt_on > 0 ? 'on' : 'off'}"
        :onclick "~/.config/eww/scripts/toggle-bt.sh"
        :onrightclick "blueman-manager &"
        (box :orientation "v" :spacing 4
          (label :text "󰂯" :class "tile-icon")
          (label :text "Bluetooth" :class "tile-label")
          (label :text "${bt_on > 0 ? 'On' : 'Off'}" :class "tile-status"))))
    (box :class "slider-row" :spacing 8
      (button :class "slider-icon-btn" :onclick "pamixer -t"
        (label :text "${muted ? '󰝟' : (volume >= 66 ? '󰕾' : (volume >= 33 ? '󰖀' : '󰕿'))}" :class "module-icon"))
      (scale :min 0 :max 100 :value "${volume}"
        :onchange "pamixer --set-volume {}")
      (label :text "${volume}%" :class "slider-value"))
    (box :class "slider-row" :spacing 8
      (label :text "󰖨" :class "module-icon slider-icon")
      (scale :min 0 :max 100 :value "${brightness}"
        :onchange "brightnessctl set {}%")
      (label :text "${brightness}%" :class "slider-value"))))

;; ============================================ POWER MENU ============================================

(defwindow power-menu
  :stacking "overlay"
  :geometry (geometry :width "420px" :height "120px" :anchor "center")
  (box :class "popup revealer power-menu" :spacing 32 :halign "center"
    (button :class "power-item"
      :onclick "~/.config/eww/scripts/power.sh lock && eww close power-menu && eww update popup_open='none'"
      (box :orientation "v" :spacing 4
        (label :text "󰒜" :class "power-icon")
        (label :text "Lock" :class "power-label")))
    (button :class "power-item"
      :onclick "~/.config/eww/scripts/power.sh logout"
      (box :orientation "v" :spacing 4
        (label :text "󰐾" :class "power-icon")
        (label :text "Logout" :class "power-label")))
    (button :class "power-item"
      :onclick "~/.config/eww/scripts/power.sh suspend && eww close power-menu && eww update popup_open='none'"
      (box :orientation "v" :spacing 4
        (label :text "󰤄" :class "power-icon")
        (label :text "Suspend" :class "power-label")))
    (button :class "power-item"
      :onclick "~/.config/eww/scripts/power.sh poweroff && eww close power-menu && eww update popup_open='none'"
      (box :orientation "v" :spacing 4
        (label :text "󰐥" :class "power-icon")
        (label :text "Power Off" :class "power-label")))))
```

- [ ] **Step 2: Commit**

```bash
git add dot_config/eww/eww.yuck.tmpl
git commit -m "feat(eww): add complete yuck definitions with defpoll and revealer wrappers"
```

---

### Task 3: Create SCSS styles with calc() math and animations

**Files:**
- Write: `dot_config/eww/styles/colors.scss.tmpl`
- Write: `dot_config/eww/eww.scss.tmpl`

**Interfaces:**
- Produces: All CSS styles using `calc()` for DPI-aware sizing, `:active` scale feedback, battery glow, animations

- [ ] **Step 1: Write colors.scss.tmpl**

```scss
$rosewater: {{ .colors.rosewater }};
$flamingo:  {{ .colors.flamingo }};
$pink:      {{ .colors.pink }};
$mauve:     {{ .colors.mauve }};
$red:       {{ .colors.red }};
$maroon:    {{ .colors.maroon }};
$peach:     {{ .colors.peach }};
$yellow:    {{ .colors.yellow }};
$green:     {{ .colors.green }};
$teal:      {{ .colors.teal }};
$sky:       {{ .colors.sky }};
$sapphire:  {{ .colors.sapphire }};
$blue:      {{ .colors.blue }};
$lavender:  {{ .colors.lavender }};
$text:      {{ .colors.text }};
$subtext1:  {{ .colors.subtext1 }};
$subtext0:  {{ .colors.subtext0 }};
$overlay2:  {{ .colors.overlay2 }};
$overlay1:  {{ .colors.overlay1 }};
$overlay0:  {{ .colors.overlay0 }};
$surface2:  {{ .colors.surface2 }};
$surface1:  {{ .colors.surface1 }};
$surface0:  {{ .colors.surface0 }};
$base:      {{ .colors.base }};
$mantle:    {{ .colors.mantle }};
$crust:     {{ .colors.crust }};
```

- [ ] **Step 2: Write eww.scss.tmpl**

```scss
@import "colors.scss";

* { all: unset; font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font", "Noto Sans CJK SC"; }

/* ===== BAR ===== */
.bar-inner {
  background: rgba($crust, 0.85);
  padding: 0 16px;
  height: ${bar_height}px;
}
.bar-spacer { min-width: 0px; }
.bar-start { margin-right: auto; }

/* ===== MODULE BUTTONS ===== */
.module-btn {
  color: $subtext0;
  font-size: calc(${icon_size}px * 1);
  padding: 4px 8px;
  border-radius: 6px;
  transition: all 100ms ease;
}
.module-btn:hover { background: $surface0; color: $text; }
.module-btn:active { transform: scale(0.95); }
.module-icon { font-family: "Symbols Nerd Font"; }

/* ===== NETWORK STATUS DOT ===== */
.net-dot { min-width: 4px; min-height: 4px; border-radius: 50%; margin: 2px 0 0 4px; }
.net-dot-on  { background: $green; }
.net-dot-eth { background: $sapphire; }
.net-dot-off { background: $overlay0; }

/* ===== WORKSPACES ===== */
.workspaces-container box {
  width: ${dot_size}px; height: ${dot_size}px;
  border-radius: 50%; margin: 0 2px;
  transition: all 150ms ease;
}
.workspaces-container box.idle     { background: $surface0; }
.workspaces-container box.occupied { background: $surface2; }
.workspaces-container box.focused  { background: $lavender; width: ${pill_w}px; height: ${pill_h}px; border-radius: 4px; }
.workspaces-container box.urgent   { background: $red;      width: ${pill_w}px; height: ${pill_h}px; border-radius: 4px; animation: urgent-pulse 1s ease infinite alternate; }
@keyframes urgent-pulse { from { opacity: 1; } to { opacity: 0.4; } }

/* ===== TIME ===== */
.time-main { color: $text; font-size: calc(${font_size}px * 1); font-weight: bold; }
.time-sub  { color: $subtext0; font-size: calc(${font_size}px * 0.8); }

/* ===== NOTIFICATION BELL ===== */
.notif-bell-none   { color: $subtext0; }
.notif-bell-unread { color: $mauve; }
.notif-bell-dnd    { color: $peach; }
.notif-badge { color: $base; background: $red; font-size: calc(${font_size}px * 0.6); border-radius: 50%; min-width: 14px; min-height: 14px; padding: 1px 3px; margin: -6px 0 0 -6px; }

/* ===== BATTERY ===== */
.bat-charging { color: $green; box-shadow: 0 0 4px rgba($green, 0.4); border-radius: 4px; }
.bat-normal   { color: $subtext0; }
.bat-low      { color: $red; }

/* ===== POPUP BASE ===== */
.popup { background: rgba($base, 0.92); border-radius: 12px; border: 1px solid $surface1; padding: 12px; margin: 4px 8px 0 0; }
.popup-title    { color: $text; font-size: 14px; padding: 0 0 8px 0; }
.separator-line  { background: $surface1; min-height: 1px; margin: 8px 0; }
.popup-footer-btn { color: $subtext0; padding: 6px 0; transition: all 100ms; }
.popup-footer-btn:hover { color: $text; }

/* Revealer popup animation */
.revealer { animation: popup-in 200ms ease; }
@keyframes popup-in { from { opacity: 0; transform: translateY(-8px); } to { opacity: 1; transform: translateY(0); } }

/* ===== CALENDAR ===== */
.calendar-hero { padding: 4px 0 8px 0; }
.calendar-weekday { color: $text; font-size: 18px; }
.calendar-date    { color: $lavender; font-size: 26px; font-weight: bold; }
calendar:selected { background: $lavender; color: $base; border-radius: 4px; }
calendar.header   { color: $subtext0; font-size: 11px; }
calendar.button   { color: $subtext1; }
calendar.button:hover { background: $surface0; border-radius: 4px; }

/* ===== NOTIFICATIONS ===== */
.notif-header { padding: 0 0 8px 0; }
.notif-clear-all { color: $subtext0; font-size: 14px; padding: 0 4px; }
.notif-clear-all:hover { color: $red; }
.notif-scroll { min-height: 350px; }
.notif-list { padding: 4px 0; }
.notif-item { padding: 8px 4px; border-left: 3px solid transparent; transition: all 100ms; }
.notif-item:hover { background: $surface0; }
.notif-item.unread { border-left-color: $mauve; }
.notif-group-label { color: $mauve; font-size: 10px; font-weight: bold; text-transform: uppercase; letter-spacing: 1px; padding: 12px 4px 4px 4px; margin-top: 4px; }
.notif-app   { color: $overlay1; font-size: 10px; margin-right: 4px; }
.notif-title { color: $text; font-size: 12px; }
.notif-body  { color: $subtext0; font-size: 11px; margin-top: 2px; }
.notif-time  { color: $overlay0; font-size: 10px; margin-top: 4px; }
.notif-empty { color: $subtext0; font-size: 13px; padding: 32px 0; text-align: center; }

/* ===== NETWORK ===== */
.current-connection { padding: 8px; background: $surface0; border-radius: 8px; }
.conn-name   { color: $text; font-size: 13px; }
.conn-status { color: $subtext0; font-size: 11px; }
.wifi-network { padding: 6px 8px; border-radius: 6px; transition: all 100ms; }
.wifi-network:hover { background: $surface0; }
.wifi-network-ssid     { color: $text; font-size: 12px; }
.wifi-network-security { color: $overlay0; font-size: 10px; }

/* ===== CONTROL CENTER ===== */
.toggle-tile { background: $surface0; border-radius: 8px; padding: 12px 16px; min-width: 150px; transition: all 100ms; }
.toggle-tile:hover  { background: $surface1; }
.toggle-tile.on     { border-left: 3px solid $green; }
.toggle-tile.off    { border-left: 3px solid transparent; }
.tile-icon   { font-size: 18px; color: $text; }
.toggle-tile.off .tile-icon, .toggle-tile.off .tile-label  { color: $subtext0; }
.toggle-tile.off .tile-status { color: $overlay0; }
.tile-label  { color: $text; font-size: 12px; }
.tile-status { color: $subtext0; font-size: 10px; }
.slider-row      { padding: 4px 0; }
.slider-icon      { color: $subtext0; font-size: 16px; }
.slider-icon-btn  { color: $subtext0; font-size: 16px; }
.slider-icon-btn:hover { color: $text; }
.slider-value { color: $subtext0; font-size: 12px; min-width: 36px; text-align: right; }
scale trough          { background: $surface1; border-radius: 4px; min-height: 4px; }
scale trough highlight { background: $lavender; border-radius: 4px; }
scale slider           { background: $text; min-width: 12px; min-height: 12px; border-radius: 50%; }

/* ===== POWER MENU ===== */
.power-item { padding: 12px 16px; border-radius: 8px; transition: all 100ms; }
.power-item:hover  { background: $surface0; }
.power-item:active { transform: scale(0.95); }
.power-icon  { font-size: 26px; color: $text; font-family: "Symbols Nerd Font"; }
.power-label { color: $subtext0; font-size: 11px; margin-top: 2px; }
```

- [ ] **Step 3: Commit**

```bash
git add dot_config/eww/eww.scss.tmpl dot_config/eww/styles/colors.scss.tmpl
git commit -m "feat(eww): add complete scss with DPI calc math and animations"
```

---

### Task 4: Create data collection and toggle scripts

**Files:**
- Create: `dot_config/eww/scripts/executable_workspaces.sh`
- Create: `dot_config/eww/scripts/executable_network.sh`
- Create: `dot_config/eww/scripts/executable_notif-logger.sh`
- Create: `dot_config/eww/scripts/executable_notifications.sh`
- Create: `dot_config/eww/scripts/executable_battery.sh`
- Create: `dot_config/eww/scripts/executable_toggle-wifi.sh`
- Create: `dot_config/eww/scripts/executable_toggle-bt.sh`
- Create: `dot_config/eww/scripts/executable_clear-notifs.sh`
- Create: `dot_config/eww/scripts/executable_power.sh`

**Interfaces:**
- defpoll scripts output single-line values to stdout
- Toggle scripts execute actions, output nothing since eww will re-poll via defpoll

- [ ] **Step 1: Write workspaces.sh**

```bash
#!/usr/bin/env bash
# Called by defpoll every 500ms
# Output: single line of concatenated (box :class ... ) yuck elements

workspaces_json=$(i3-msg -t get_workspaces 2>/dev/null)
if [ -z "$workspaces_json" ]; then
    echo ""
    exit 0
fi

echo "$workspaces_json" | jq -j 'sort_by(.num) | .[] |
  if .focused then
    "(box :class \"focused\" :onclick \"i3-msg workspace \(.num)\" \"\")"
  elif .urgent then
    "(box :class \"urgent\" :onclick \"i3-msg workspace \(.num)\" \"\")"
  elif (.nodes | length) > 0 then
    "(box :class \"occupied\" :onclick \"i3-msg workspace \(.num)\" \"\")"
  else
    "(box :class \"idle\" :onclick \"i3-msg workspace \(.num)\" \"\")"
  end
'
```

- [ ] **Step 2: Write network.sh**

```bash
#!/usr/bin/env bash
# Called by defpoll every 5s — outputs key=value lines

if ! nmcli radio wifi 2>/dev/null | grep -q "enabled"; then
    echo "wifi_on=0"
    echo "wifi_icon=󰤭"
    echo "wifi_name=Disconnected"
    echo "wired=0"
    echo "wifi_networks="
    exit 0
fi

echo "wifi_on=1"

# Wired detection
if nmcli -t -f TYPE,STATE c show --active 2>/dev/null | grep -q "^802-3-ethernet"; then
    echo "wired=1"
    echo "wifi_icon=󰈀"
else
    echo "wired=0"
    echo "wifi_icon=󰤉"
fi

# Active SSID
ssid=$(nmcli -t -f NAME c show --active 2>/dev/null | grep -v '^lo$' | head -1)
echo "wifi_name=${ssid:-Disconnected}"

# Available networks formatted as yuck literal
networks_yuck=""
while IFS=':' read -r ssid security in_use; do
    [ -z "$ssid" ] && continue
    lock="󰉂"
    case "$security" in WPA1|WPA2|WPA3) lock="󰉃" ;; esac
    networks_yuck="${networks_yuck}(box :class \"wifi-network\" :onclick \"nmcli device wifi connect '${ssid}' 2>/dev/null || nm-connection-editor &\" (label :text \"${lock}  ${ssid}\" :class \"wifi-network-ssid\"))"
done < <(nmcli -t -f SSID,SECURITY device wifi list 2>/dev/null | sort -u)

echo "wifi_networks=$networks_yuck"
```

- [ ] **Step 3: Write notif-logger.sh**

```bash
#!/usr/bin/env bash
# Daemon started by launch script — monitors D-Bus for dunst notifications
# Appends to /tmp/eww_notifications.json, keeps last 50 entries

LOG_FILE="/tmp/eww_notifications.json"
echo "[]" > "$LOG_FILE"

capture_state=""
app=""; sum=""; body=""

dbus-monitor "interface='org.freedesktop.Notifications',member='Notify'" 2>/dev/null \
| while IFS= read -r line; do
    if echo "$line" | grep -q '^method call'; then
        capture_state="app"; app=""; sum=""; body=""
    fi
    if echo "$line" | grep -q '^\s*string'; then
        value=$(echo "$line" | sed 's/^\s*string "//;s/"$//')
        case "$capture_state" in
            app)     app="$value";   capture_state="summary" ;;
            summary) sum="$value";   capture_state="body" ;;
            body)    body="$value";  capture_state="done" ;;
            *)       capture_state="" ;;
        esac
    fi
    if [ "$capture_state" = "done" ]; then
        timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        jq --arg app "$app" --arg t "$sum" --arg b "$body" --arg ts "$timestamp" \
          "[{app: \$app, title: \$t, body: \$b, timestamp: \$ts}] + . | .[:50]" \
          "$LOG_FILE" > /tmp/eww_notifs.new 2>/dev/null && mv /tmp/eww_notifs.new "$LOG_FILE"
        capture_state=""
    fi
done
```

- [ ] **Step 4: Write notifications.sh**

```bash
#!/usr/bin/env bash
# Called by defpoll every 2s
# Reads /tmp/eww_notifications.json, outputs notif_count + yuck literal for notification list

LOG_FILE="/tmp/eww_notifications.json"
[ ! -f "$LOG_FILE" ] && echo "[]" > "$LOG_FILE"

count=$(jq 'length' "$LOG_FILE" 2>/dev/null || echo 0)
echo "notif_count=$count"

if [ "$count" -eq 0 ] 2>/dev/null; then
    echo "notifications=(label :class \"notif-empty\" \"All caught up\")"
    exit 0
fi

# Build yuck literal: group by "just now" (<2min) and "earlier"
now=$(date +%s)
cutoff=$((now - 120))

output=""
jq -c '.[] | {app: .app, title: .title, body: .body, timestamp: .timestamp}' "$LOG_FILE" 2>/dev/null \
| while IFS= read -r item; do
    app=$(echo "$item" | jq -r '.app // "dunst"')
    title=$(echo "$item" | jq -r '.title // ""')
    body=$(echo "$item" | jq -r '.body // ""')
    ts=$(echo "$item" | jq -r '.timestamp // ""')
    ts_epoch=$(date -d "$ts" +%s 2>/dev/null || echo 0)
    if [ "$ts_epoch" -ge "$cutoff" ] 2>/dev/null; then
        group="just_now"
    else
        group="earlier"
    fi
    echo "notif:${group}:${app}:${title}:${body}:${ts}"
done | while IFS=: read -r _ group app title body ts; do
    echo "(box :class \"notif-item unread\" (label :text \"${app}  ${title}\" :class \"notif-title\") (label :text \"${body}\" :class \"notif-body\") (label :text \"${ts}\" :class \"notif-time\"))"
done | tr '\n' ' '
```

- [ ] **Step 5: Write battery.sh**

```bash
#!/usr/bin/env bash
# Called by defpoll every 5s

BAT=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
if [ -z "$BAT" ]; then
    echo "battery_percent=100"
    echo "battery_charging=false"
    echo "battery_icon=󰁹"
    exit 0
fi

percent=$(cat "$BAT" 2>/dev/null || echo 100)
status=$(cat "${BAT%/*}/status" 2>/dev/null || echo "Unknown")

charging="false"
if [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
    charging="true"
fi

if [ "$charging" = "true" ]; then
    icon="󰂄"
elif [ "$percent" -ge 90 ] 2>/dev/null; then icon="󰁹"
elif [ "$percent" -ge 70 ] 2>/dev/null; then icon="󰂁"
elif [ "$percent" -ge 50 ] 2>/dev/null; then icon="󰁾"
elif [ "$percent" -ge 30 ] 2>/dev/null; then icon="󰁼"
elif [ "$percent" -ge 15 ] 2>/dev/null; then icon="󰁺"
else icon="󰂃"
fi

echo "battery_percent=$percent"
echo "battery_charging=$charging"
echo "battery_icon=$icon"
```

- [ ] **Step 6: Write toggle and action scripts**

```bash
#!/usr/bin/env bash
# toggle-wifi.sh
nmcli radio wifi toggle

#!/usr/bin/env bash
# toggle-bt.sh
rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: yes" && rfkill unblock bluetooth || rfkill block bluetooth

#!/usr/bin/env bash
# clear-notifs.sh — clear notification log
echo "[]" > /tmp/eww_notifications.json

#!/usr/bin/env bash
# power.sh — execute power actions
case "$1" in
    lock)     betterlockscreen -l blur ;;
    logout)   i3-msg exit ;;
    suspend)  systemctl suspend ;;
    reboot)   systemctl reboot ;;
    poweroff) systemctl poweroff ;;
    *)        echo "Usage: power.sh {lock|logout|suspend|reboot|poweroff}" >&2 ;;
esac
```

- [ ] **Step 7: Make all scripts executable and commit**

```bash
chmod +x dot_config/eww/scripts/executable_*.sh
git add dot_config/eww/scripts/
git commit -m "feat(eww): add all data collection and toggle scripts"
```

---

### Task 5: Update i3 and picom configurations

**Files:**
- Modify: `dot_config/i3/config.tmpl` — replace polybar launch with eww
- Modify: `dot_config/picom/picom.conf` — add eww window classes to exclusion rules

**Interfaces:**
- Consumes: `~/.config/eww/scripts/launch.sh`

- [ ] **Step 1: Update i3 config**

In `dot_config/i3/config.tmpl`, replace:
```
exec --no-startup-id ~/.config/polybar/launch.sh
```
With:
```
exec --no-startup-id ~/.config/eww/scripts/launch.sh
```

- [ ] **Step 2: Update picom config**

In `dot_config/picom/picom.conf`:

Add to `shadow-exclude` AND `blur-background-exclude` (find the existing arrays and append):
```
    "class_g = 'eww-bar'",
    "class_g = 'eww'",
```

Remove existing `"class_g = 'Polybar'"` entries from both blocks.

In `opacity-rule`, add:
```
    "90:class_g = 'eww-bar'",
```

Remove existing `"90:class_g = 'Polybar'"` entry.

- [ ] **Step 3: Commit**

```bash
git add dot_config/i3/config.tmpl dot_config/picom/picom.conf
git commit -m "feat(eww): integrate eww bar into i3 and picom configs"
```

---

### Task 6: Test and verify

**Files:**
- No file changes — manual integration testing

- [ ] **Step 1: Apply chezmoi**

```bash
chezmoi apply
```

- [ ] **Step 2: Start eww manually**

```bash
~/.config/eww/scripts/launch.sh
```

Verify: bar appears at top, tray visible, workspace dots render, time/date correct.

- [ ] **Step 3: Test each module interaction**

- Click time → calendar popup opens below time
- Click bell → notification popup opens below bell
- Click network icon → network popup opens
- Click CC icon → control center opens
- Click power button → power menu appears centered
- Click a different module → previous popup closes, new one opens
- Right-click bell → DND toggles, bell changes to peach color

- [ ] **Step 4: Test control center**

- Drag volume slider → `pamixer --get-volume` reflects change
- Drag brightness slider → `brightnessctl info` reflects change
- Click WiFi/BT toggle tiles → state changes visually

- [ ] **Step 5: Test power menu**

- Lock: screen locks with betterlockscreen
- Suspend: system suspends (skip in VM)

- [ ] **Step 6: Restart i3 to verify autostart**

```bash
i3-msg restart
```

Verify bar auto-launches.

- [ ] **Step 7: Commit final fixes**

```bash
git add -A
git commit -m "fix(eww): finalize bar configuration"
```
