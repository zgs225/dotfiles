local wezterm = require('wezterm')
local gpu_adapters = require('utils.gpu_adapter')
local platform = require('utils.platform')()
local fonts = require('config.fonts')
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
         opacity = 0.75,
      },
   },

   -- scrollbar
   enable_scroll_bar = false,

   -- tab bar: visible, but hidden while there is only a single tab — tmux
   -- manages windows via its own (transparent) status bar, so the strip only
   -- appears when native wezterm tabs actually carry information.
   -- The tab bar is a separate GPU layer that cannot render background
   -- images; it is styled as a flat mounting band with the song-liquid-glass
   -- chrome tokens (colors/custom.lua, events/tab-title.lua).
   enable_tab_bar = true,
   hide_tab_bar_if_only_one_tab = true,

   -- window
   window_padding = {
      left = 5,
      right = 5,
      top = 10,
      bottom = 5,
   },
   window_close_confirmation = 'NeverPrompt',
   window_frame = {
      active_titlebar_bg = colors.tab_bar.background,
      font = fonts.font,
      font_size = fonts.font_size,
   },
   inactive_pane_hsb = {
      saturation = 0.9,
      brightness = 0.65,
   },
}
