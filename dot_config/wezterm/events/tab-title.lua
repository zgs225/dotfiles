-- events/tab-title.lua
-- Jie-yin (boundary-line) tab bar: no fill, no shape — the active tab is
-- marked by a sky-blue left vertical bar + sky-blue text on the flat
-- mounting band, the most restrained variant. Inactive tabs stay silent
-- (crab-shell blue). Colors: song chrome tokens (colors/palette.lua);
-- backgrounds live in colors/custom.lua.
--
-- Remote panes carry a single Nerd Font glyph in front of the host name
-- (utils/remote-os.lua): the glyph answers "which system", its presence
-- answers "am I remote at all", and the host replaces the pane title —
-- which is stale for any remote shell that never emits OSC 0/2, and turns
-- into the session name under tmux. Local tabs get no glyph, so one glyph
-- keeps meaning exactly one thing.

local wezterm = require('wezterm')
local song = require('colors.palette').song
local remote = require('utils.remote-os')

local M = {}

local COLORS = {
   active = song.accent,
   hover = song.fg_primary,
   dim = song.fg_secondary,
   alert = song.warn,
}

--- Push a text cell with only foreground color (no background override).
--- The tab bar's own bg_color (set in custom.lua) fills the background.
local function _push(cells, fg, attr, text)
   cells[#cells + 1] = { Foreground = { Color = fg } }
   if attr then
      cells[#cells + 1] = { Attribute = attr }
   end
   cells[#cells + 1] = { Text = text }
end

local function _process_name(p)
   return (p or ''):gsub('(.*[/\\])(.*)', '%2'):gsub('%.exe$', '')
end

--- Real panes hand out the process name and the title through methods, and
--- only through properties in older builds; both property reads are nil on
--- 20240203 (found live). Both are only consulted when a pane has no title.
local function _foreground_name(pane)
   local ok, name = pcall(function() return pane:get_foreground_process_name() end)
   if ok and type(name) == 'string' and name ~= '' then return name end
   local prop = pane.foreground_process_name
   if type(prop) == 'string' then return prop end
   return ''
end

local function _pane_title(pane)
   if type(pane.title) == 'string' and pane.title ~= '' then return pane.title end
   local ok, title = pcall(function() return pane:get_title() end)
   if ok and type(title) == 'string' then return title end
   return ''
end

--- Keep the label inside `max_width`. `reserved` counts the cells already
--- spoken for (the remote glyph and its space), so a long host name is
--- truncated before the tab is allowed to overflow.
local function _truncate(title, max_width, reserved)
   local pad = 4 + (reserved or 0) -- 2 spaces each side, plus the glyph slots
   local limit = max_width - pad
   if limit < 6 then limit = 6 end
   if #title > limit then
      title = wezterm.truncate_right(title, limit)
   end
   return title
end

--- Build the tab's cells. Exported so the whole label can be asserted on
--- without a GUI (`format-tab-title` handler return values are not visible
--- through wezterm.emit, which only reports handled/unhandled).
--- @param tab table TabInformation
--- @param hover boolean|nil
--- @param max_width integer tab_max_width, in cells
--- @return table cells for wezterm.format
function M.render(tab, hover, max_width)
   local cells = {}
   local pane = tab.active_pane
   local link = remote.info(pane) -- nil | { host = 'pve', os = 'debian' }

   -- A remote shell sitting at a password prompt, or one that never emits
   -- OSC 0/2, has no title at all (nil, not ''), so the host we were asked to
   -- connect to is the more honest label.
   local title = (link and link.host) or _pane_title(pane)
   if title == '' then title = _process_name(_foreground_name(pane)) end
   title = _truncate(title, max_width, link and 2 or 0)

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
   for _, other in ipairs(tab.panes) do
      if other.has_unseen_output then
         has_unseen = true
         break
      end
   end

   -- Build cells: [bar] ` [glyph] title ` with optional alert dot.
   -- The glyph carries no color of its own: it follows the tab's state, so
   -- "remote" reads as shape (a glyph exists), never as hue.
   if tab.is_active then
      _push(cells, COLORS.active, nil, '▎')
   end
   if link then
      _push(cells, fg, attr, ' ' .. remote.glyph(link.os) .. ' ' .. title)
   else
      _push(cells, fg, attr, ' ' .. title)
   end
   if has_unseen then
      _push(cells, COLORS.alert, { Intensity = 'Bold' }, ' ●')
   end
   _push(cells, fg, attr, ' ')

   return cells
end

M.setup = function()
   wezterm.on('format-tab-title', function(tab, _tabs, _panes, _config, hover, max_width)
      return M.render(tab, hover, max_width)
   end)
end

return M
