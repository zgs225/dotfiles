local wezterm = require('wezterm')
local palette_data = require('colors.palette')
local palette = palette_data.palette
local song = palette_data.song

local M = {}

M.background = palette.background
M.palette = palette
M.tmux_mapping = palette_data.tmux_mapping

function M.build_colors(scheme_name)
   return {
      background = palette.background,
      tab_bar = {
         -- Flat mounting band, tabs are text-only: the active tab is marked
         -- by a sky-blue jie-yin underline (events/tab-title.lua), never a
         -- fill block. Song-liquid-glass chrome tokens per
         -- terminal-unification.md §4 — no blue-purple, no color blocks.
         background = song.bg_base,
         active_tab = {
            bg_color = song.bg_base,
            fg_color = song.accent,
         },
         inactive_tab = {
            bg_color = song.bg_base,
            fg_color = song.fg_secondary,
         },
         inactive_tab_hover = {
            bg_color = song.bg_base,
            fg_color = song.fg_primary,
         },
         new_tab = {
            bg_color = song.bg_base,
            fg_color = song.fg_secondary,
         },
         new_tab_hover = {
            bg_color = song.bg_base,
            fg_color = song.fg_primary,
         },
      },
   }
end

return M
