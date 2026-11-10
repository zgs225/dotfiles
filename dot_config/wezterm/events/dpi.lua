local wezterm = require('wezterm')
local platform = require('utils.platform')()
local fonts = require('config.fonts')

local M = {}

-- Per-output terminal font size — the only place on X11 where "same content,
-- two different-DPI panels" can actually be made to work.
--
-- X11 exposes ONE screen-wide `Xft.dpi`, and no application re-scales when it is
-- moved between outputs (see displayctl: DPI is a single global tier). tmux is
-- not even in the picture — it lays out cells, not pixels; wezterm owns the cell
-- size and tmux re-flows for free via SIGWINCH when the font changes. Scaling
-- the font per output therefore keeps the physical text size identical on both
-- panels, and the tmux status bar / pane borders follow automatically.
--
-- Keys are xrandr output names, which is exactly what
-- `wezterm.gui.screens().active.name` reports here (verified: "eDP-1"; the
-- docked 4K panel appears as "DP-1-1", the MST branch of DP-1).
--
-- Ratio = panel DPI / DPI the base font size was tuned on (the external 4K
-- panel, 163 DPI). Ratios from `xrandr --query` physical size:
--   eDP-1    2560x1600 on 344mm = 189 DPI → 189/163 ≈ 1.157
--   DP-1-1   3840x2160 on 597mm = 163 DPI → 1.0   (Dell U2720QM)
-- Add a row when a new panel shows up; unknown outputs fall back to 1.0 and are
-- reported once via `WEZTERM_DPI_DEBUG=1`.
local RATIO = {
   ['eDP-1'] = 1.157,
   ['DP-1-1'] = 1.0,
   ['DP-1'] = 1.0, -- same panel, still named after its parent port on some MST setups
   ['HDMI-1-0'] = 1.0,
}

local DEBUG = os.getenv('WEZTERM_DPI_DEBUG') ~= nil

---@param name string
---@return number
local function target_for(name)
   local size = fonts.font_size * (RATIO[name] or 1.0)
   return math.floor(size * 100 + 0.5) / 100
end

--- window_id -> last screen name seen for that window
local last_screen = {}

---@param window any wezterm Window
---@param _pane any wezterm Pane
local function apply(window, _pane)
   local gui = wezterm.gui
   local screens = gui and gui.screens and gui.screens()
   local name = screens and screens.active and screens.active.name
   if not name then
      return
   end

   local id = window:window_id()
   if last_screen[id] == name then
      return -- still on the same output, nothing to do
   end
   last_screen[id] = name

   local base = fonts.font_size
   local target = target_for(name)
   local overrides = window:get_config_overrides() or {}
   local current = overrides.font_size

   if DEBUG then
      wezterm.log_info(
         string.format(
            'dpi: window=%d screen=%s base=%.2f target=%.2f current=%s',
            id,
            name,
            base,
            target,
            tostring(current)
         )
      )
   end

   if math.abs(target - base) < 0.005 then
      -- Back on the reference panel: drop our override so config reloads and
      -- `ResetFontSize` keep meaning "config default".
      if current ~= nil then
         overrides.font_size = nil
         window:set_config_overrides(overrides)
      end
   elseif current == nil or math.abs(current - target) > 0.005 then
      -- NOTE: set_config_overrides REPLACES the window's override table, so
      -- carry the existing keys over instead of passing a fresh table.
      overrides.font_size = target
      window:set_config_overrides(overrides)
   end
end

function M.setup()
   -- X11-only concern: macOS/Windows report per-display scale factors natively.
   if not platform.is_linux then
      return
   end
   -- wezterm re-evaluates this whole config file on every
   -- `window:set_config_overrides` call; registering twice would stack handlers.
   if wezterm.GLOBAL.terminal_dpi_hook then
      return
   end
   wezterm.GLOBAL.terminal_dpi_hook = true

   local function guarded(window, pane)
      local ok, err = pcall(apply, window, pane)
      if not ok and not wezterm.GLOBAL.terminal_dpi_error then
         wezterm.GLOBAL.terminal_dpi_error = true -- report once, never spam
         wezterm.log_error('dpi: ' .. tostring(err))
      end
   end

   -- update-status ticks once a second (status_update_interval) and only for the
   -- focused window — cheap, no fork, no xrandr. window-focus-changed is what
   -- makes i3's `move container to output` feel instant: focus follows the
   -- window, so the new output is known the moment it lands there.
   wezterm.on('update-status', guarded)
   wezterm.on('window-focus-changed', guarded)
end

return M
