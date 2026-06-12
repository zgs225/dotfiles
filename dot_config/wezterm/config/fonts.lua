local wezterm = require('wezterm')
local platform = require('utils.platform')()

local font = 'CaskaydiaCove Nerd Font'
local font_size = platform.is_mac and 15 or 13

local chinese_font = ''
if platform.is_mac then
   chinese_font = 'PingFang SC'
elseif platform.is_win then
   chinese_font = 'Microsoft YaHei UI'
else
   chinese_font = 'Noto Sans CJK SC'
end

return {
   font = wezterm.font_with_fallback({
      font,
      chinese_font,
   }),
   font_size = font_size,

   --ref: https://wezfurlong.org/wezterm/config/lua/config/freetype_pcf_long_family_names.html#why-doesnt-wezterm-use-the-distro-freetype-or-match-its-configuration
   freetype_load_target = 'Normal', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
   freetype_render_target = 'Normal', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
}
