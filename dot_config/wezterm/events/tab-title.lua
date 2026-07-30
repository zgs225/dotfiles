-- events/tab-title.lua
-- Minimalist tab bar: no color blocks, no powerline glyphs.
-- Only foreground color + weight distinguish active / inactive / hover.
-- Colors are read from wezterm.GLOBAL.tab_colors (updated on backdrop switch).

local wezterm = require('wezterm')
local palette = require('colors.palette').palette

local M = {}

-- Fallback colors (Tokyo Night) used before any backdrop switch
local FALLBACK = {
   accent = palette.blue,
   dim    = palette.white,
   fg     = palette.foreground,
   alert  = palette.red,
}

local __cells__ = {}

--- Push a text cell with only foreground color (no background override).
--- The tab bar's own bg_color (set in custom.lua) fills the background.
local function _push(fg, attr, text)
   table.insert(__cells__, { Foreground = { Color = fg } })
   table.insert(__cells__, { Attribute = attr })
   table.insert(__cells__, { Text = text })
end

local function _process_name(p)
   local name = p:gsub('(.*[/\\])(.*)', '%2'):gsub('%.exe$', '')
   return name
end

local function _truncate(title, max_width)
   local pad = 4 -- 2 spaces each side
   local limit = max_width - pad
   if limit < 6 then limit = 6 end
   if #title > limit then
      title = wezterm.truncate_right(title, limit)
   end
   return title
end

M.setup = function()
   wezterm.on('format-tab-title', function(tab, _tabs, _panes, _config, hover, max_width)
      __cells__ = {}

      local tc = wezterm.GLOBAL.tab_colors or FALLBACK

      local proc = _process_name(tab.active_pane.foreground_process_name)
      local base = tab.active_pane.title
      local title
      if #proc > 0 and proc ~= base then
         title = proc .. ' ~ ' .. base
      else
         title = base
      end
      title = _truncate(title, max_width)

      -- Choose fg + attribute by state
      local fg, attr
      if tab.is_active then
         fg   = tc.accent
         attr = { Intensity = 'Bold' }
      elseif hover then
         fg   = tc.fg
         attr = { Intensity = 'Normal' }
      else
         fg   = tc.dim
         attr = { Intensity = 'Normal' }
      end

      -- Check for unseen output in any pane
      local has_unseen = false
      for _, pane in ipairs(tab.panes) do
         if pane.has_unseen_output then
            has_unseen = true
            break
         end
      end

      -- Build cells: ` title ` with optional alert dot
      _push(fg, attr, ' ' .. title)
      if has_unseen then
         _push(tc.alert, { Intensity = 'Bold' }, ' ●')
      end
      _push(fg, attr, ' ')

      return __cells__
   end)
end

return M
