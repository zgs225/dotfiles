local wezterm = require('wezterm')
local palette_data = require('colors.palette')
local palette = palette_data.palette

local M = {}

M.background = palette.background
M.palette = palette
M.tab_title = palette.tab_title
M.left_status = palette.left_status

local CHROME_KEYS = {
   'cursor_bg',
   'cursor_fg',
   'cursor_border',
   'selection_fg',
   'selection_bg',
   'split',
}

function M.build_colors(scheme_name)
   local colors = {
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
   -- Optional subtables, present only in palettes that fully drive the chrome
   -- (Song Ink). Tokyo Night keeps relying on the builtin scheme for these.
   if palette.ansi then
      colors.ansi = palette.ansi
   end
   if palette.brights then
      colors.brights = palette.brights
   end
   if palette.chrome then
      for _, key in ipairs(CHROME_KEYS) do
         if palette.chrome[key] then
            colors[key] = palette.chrome[key]
         end
      end
   end
   return colors
end

return M
