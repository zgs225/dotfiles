local wezterm = require('wezterm')
local gpu_adapters = require('utils.gpu_adapter')
local platform = require('utils.platform')()
local colors = require('colors.custom').build_colors('Tokyo Night')

local function pick_gpu()
   if platform.is_linux then
      local igpu_gl = gpu_adapters:pick_manual('Gl', 'IntegratedGpu')
      if igpu_gl then
         return igpu_gl
      end
   end
   return gpu_adapters:pick_best()
end

local power_preference = platform.is_linux and 'LowPower' or 'HighPerformance'

return {
   animation_fps = 60,
   max_fps = 60,
   front_end = 'WebGpu',
   webgpu_power_preference = power_preference,
   webgpu_preferred_adapter = pick_gpu(),

   -- color scheme
   color_scheme = 'Tokyo Night',
   colors = colors,

   -- background
   background = {
      {
         source = { File = wezterm.GLOBAL.background },
         horizontal_align = 'Center',
      },
      {
         source = { Color = colors.background },
         height = '100%',
         width = '100%',
         opacity = 0.88,
      },
   },

   -- scrollbar
   enable_scroll_bar = false,

   -- tab bar: hidden — tmux manages windows via its own (transparent) status bar.
   -- The wezterm tab bar is a separate GPU layer that cannot render background
   -- images, so it always appears as a solid-color strip.  Hiding it lets the
   -- backdrop fill the entire window edge-to-edge.
   -- If you ever need native wezterm tabs (e.g. SSH domains), set enable_tab_bar
   -- back to true; the tab-title.lua styling and palette sync are still wired up.
   enable_tab_bar = false,

   -- window
   window_padding = {
      left = 5,
      right = 5,
      top = 10,
      bottom = 5,
   },
   window_close_confirmation = 'NeverPrompt',
   window_frame = {
      active_titlebar_bg = '#090909',
      -- font = fonts.font,
      -- font_size = fonts.font_size,
   },
   inactive_pane_hsb = {
      saturation = 0.9,
      brightness = 0.65,
   },
}
