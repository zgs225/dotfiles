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
         background = palette.background,
         active_tab = {
            bg_color = palette.bright_black,
            fg_color = palette.foreground,
         },
         inactive_tab = {
            bg_color = palette.background,
            fg_color = palette.bright_black,
         },
         inactive_tab_hover = {
            bg_color = palette.black,
            fg_color = palette.foreground,
         },
         new_tab = {
            bg_color = palette.background,
            fg_color = palette.foreground,
         },
         new_tab_hover = {
            bg_color = palette.bright_black,
            fg_color = palette.foreground,
            italic = true,
         },
      },
   }
end

return M
