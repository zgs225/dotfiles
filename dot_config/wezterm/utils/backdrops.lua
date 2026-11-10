local wezterm = require('wezterm')
local platform = require('utils.platform')()
local colors = require('colors.custom')

-- Seeding random numbers before generating for use
-- Known issue with lua math library
-- see: https://stackoverflow.com/questions/20154991/generating-uniform-random-numbers-in-lua
math.randomseed(os.time())
math.random()
math.random()
math.random()

local PATH_SEP = platform.is_win and '\\' or '/'

---@class BackDrops
---@field current_idx number index of current image
---@field files string[] background images
local BackDrops = {}
BackDrops.__index = BackDrops

--- Initialise backdrop controller
---@private
function BackDrops:init()
   local inital = {
      current_idx = 1,
      files = {},
   }
   local backdrops = setmetatable(inital, self)
   -- Only clear on the first evaluation in this process: wezterm re-runs this
   -- config file on every `window:set_config_overrides` (events/dpi.lua does
   -- that when the terminal moves to a display with a different DPI), and
   -- clearing here would re-roll the backdrop on every one of those.
   if not wezterm.GLOBAL.backdrop_picked then
      wezterm.GLOBAL.background = nil
   end
   return backdrops
end

---MUST BE RUN BEFORE ALL OTHER `BackDrops` functions
---Sets the `files` after instantiating `BackDrops`.
---
--- INFO:
---   During the initial load of the config, this function can only invoked in `wezterm.lua`.
---   WezTerm's fs utility `read_dir` (used in this function) works by running on a spawned child process.
---   This throws a coroutine error if the function is invoked in outside of `wezterm.lua` in the -
---   initial load of the Terminal config.
function BackDrops:set_files()
   self.files = wezterm.read_dir(wezterm.config_dir .. PATH_SEP .. 'backdrops')
   -- Keep an already-picked backdrop across config re-evaluations.
   if wezterm.GLOBAL.background == nil then
      wezterm.GLOBAL.background = self.files[1]
   end
   return self
end

---Override the current window options for background.
---This triggers a window redraw (including tab bar).
---@private
---@param window any WezTerm Window see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:_set_opt(window)
   local opts = {
      background = {
         {
            source = { File = wezterm.GLOBAL.background },
            horizontal_align = 'Center',
         },
         {
            source = { Color = colors.background },
            height = '100%',
            width = '100%',
            opacity = 0.75,
         },
      },
   }
   window:set_config_overrides(opts)
end

---Convert the `files` array to a table of `InputSelector` choices
---see: https://wezfurlong.org/wezterm/config/lua/keyassignment/InputSelector.html
function BackDrops:choices()
   local choices = {}
   for idx, file in ipairs(self.files) do
      local name = file:match('([^' .. PATH_SEP .. ']+)$')
      table.insert(choices, {
         id = tostring(idx),
         label = name,
      })
   end
   return choices
end

---Select a random file and redefine the global `wezterm.GLOBAL.background` variable
---Pass in `Window` object to override the current window options
---@param window any? WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:random(window)
   -- Config-load call (`wezterm.lua` passes no window): keep whatever backdrop
   -- this process already picked so that re-evaluations triggered by
   -- `set_config_overrides` don't shuffle the wallpaper under the user. Only the
   -- explicit, window-bound invocation (random-background keybinding) re-rolls.
   if window == nil and wezterm.GLOBAL.backdrop_picked then
      for idx, file in ipairs(self.files) do
         if file == wezterm.GLOBAL.background then
            self.current_idx = idx
            break
         end
      end
      return
   end

   self.current_idx = math.random(#self.files)
   wezterm.GLOBAL.background = self.files[self.current_idx]
   wezterm.GLOBAL.backdrop_picked = true

   if window ~= nil then
      self:_set_opt(window)
   end
end

---Cycle the loaded `files` and select the next background
---@param window any WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:cycle_forward(window)
   if self.current_idx == #self.files then
      self.current_idx = 1
   else
      self.current_idx = self.current_idx + 1
   end
   wezterm.GLOBAL.background = self.files[self.current_idx]
   self:_set_opt(window)
end

---Cycle the loaded `files` and select the previous background
---@param window any WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:cycle_back(window)
   if self.current_idx == 1 then
      self.current_idx = #self.files
   else
      self.current_idx = self.current_idx - 1
   end
   wezterm.GLOBAL.background = self.files[self.current_idx]
   self:_sync_palette()
   self:_set_opt(window)
end

---Set a specific background from the `files` array
---@param window any WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
---@param idx number index of the `files` array
function BackDrops:set_img(window, idx)
   if idx > #self.files or idx < 0 then
      wezterm.log_error('Index out of range')
      return
   end

   self.current_idx = idx
   wezterm.GLOBAL.background = self.files[self.current_idx]
   self:_set_opt(window)
end

return BackDrops:init()
