local wezterm = require('wezterm')
local palette_data = require('colors.palette')
local palette = palette_data.palette

local M = {}

M.background = palette.background
M.palette = palette
M.tmux_mapping = palette_data.tmux_mapping

function M.build_colors(scheme_name)
   return {
      background = palette.background,
      tab_bar = {
         -- All backgrounds use the same dark color → no visible color blocks.
         -- The tab bar visually merges with the terminal viewport's overlay.
         background = palette.background,
         active_tab = {
            bg_color = palette.background,
            fg_color = palette.blue,
         },
         inactive_tab = {
            bg_color = palette.background,
            fg_color = palette.white,
         },
         inactive_tab_hover = {
            bg_color = palette.background,
            fg_color = palette.foreground,
         },
         new_tab = {
            bg_color = palette.background,
            fg_color = palette.white,
         },
         new_tab_hover = {
            bg_color = palette.background,
            fg_color = palette.foreground,
         },
      },
   }
end

return M
