-- utils/tmux_palette.lua
-- Syncs tmux statusline colors AND wezterm tab bar colors with the current
-- wezterm backdrop palette.

local wezterm = require('wezterm')
local palettes = require('utils.backdrop_palettes')

local M = {}

local SCRIPT_PATH = wezterm.config_dir .. '/scripts/apply-tmux-palette.sh'

--- Apply the palette for the given backdrop filename.
--- 1. Updates wezterm.GLOBAL.tab_colors (read by format-tab-title on next redraw)
--- 2. Runs the shell script to sed-replace tmux format strings (~15ms)
--- @param filename string basename of the backdrop image (e.g. "space.jpg")
function M.apply(filename)
   local pal = palettes[filename]
   if not pal then
      wezterm.log_warn('tmux_palette: no palette for ' .. filename)
      return
   end

   -- Update GLOBAL so format-tab-title picks up new colors on next redraw.
   -- This MUST happen before window:set_config_overrides() triggers the redraw.
   wezterm.GLOBAL.tab_colors = {
      accent = pal.accent,
      dim    = pal.dim,
      fg     = pal.fg,
      alert  = pal.alert,
   }

   -- Sync tmux statusline (synchronous, ~15ms)
   wezterm.run_child_process({
      'bash', SCRIPT_PATH,
      pal.bg,
      pal.fg,
      pal.dim,
      pal.accent,
      pal.accent2,
      pal.accent3,
      pal.warm,
      pal.alert,
      pal.border,
   })
end

return M
