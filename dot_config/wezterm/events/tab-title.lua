-- events/tab-title.lua
-- Jie-yin (boundary-line) tab bar: no fill, no shape — the active tab is
-- marked by a sky-blue left vertical bar + sky-blue text on the flat
-- mounting band, the most restrained variant. Inactive tabs stay silent
-- (crab-shell blue). Colors: song chrome tokens (colors/palette.lua);
-- backgrounds live in colors/custom.lua.

local wezterm = require('wezterm')
local song = require('colors.palette').song

local M = {}

local COLORS = {
   active = song.accent,
   hover = song.fg_primary,
   dim = song.fg_secondary,
   alert = song.warn,
}

local __cells__ = {}

--- Push a text cell with only foreground color (no background override).
--- The tab bar's own bg_color (set in custom.lua) fills the background.
local function _push(fg, attr, text)
   table.insert(__cells__, { Foreground = { Color = fg } })
   if attr then
      table.insert(__cells__, { Attribute = attr })
   end
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

      local proc = _process_name(tab.active_pane.foreground_process_name)
      local base = tab.active_pane.title
      local title = base
      if title == '' then title = proc end
      title = _truncate(title, max_width)

      -- Choose fg + attribute by state: the jie-yin is a sky-blue left
      -- vertical bar (design §4.3) — wezterm tab cells ignore Underline,
      -- so the bar glyph carries the mark instead.
      local fg, attr
      if tab.is_active then
         fg = COLORS.active
         attr = { Intensity = 'Bold' }
      elseif hover then
         fg = COLORS.hover
         attr = { Intensity = 'Normal' }
      else
         fg = COLORS.dim
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

      -- Build cells: [bar] ` title ` with optional alert dot
      if tab.is_active then
         _push(COLORS.active, nil, '▎')
      end
      _push(fg, attr, ' ' .. title)
      if has_unseen then
         _push(COLORS.alert, { Intensity = 'Bold' }, ' ●')
      end
      _push(fg, attr, ' ')

      return __cells__
   end)
end

return M
