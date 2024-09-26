-- A slightly altered version of catppucchin mocha
local palette = {
   rosewater = '#f5e0dc',
   flamingo = '#f2cdcd',
   pink = '#f5c2e7',
   mauve = '#cba6f7',
   red = '#f38ba8',
   maroon = '#eba0ac',
   peach = '#fab387',
   yellow = '#f9e2af',
   green = '#a6e3a1',
   teal = '#94e2d5',
   sky = '#89dceb',
   sapphire = '#74c7ec',
   blue = '#89b4fa',
   lavender = '#b4befe',
   text = '#cdd6f4',
   subtext1 = '#bac2de',
   subtext0 = '#a6adc8',
   overlay2 = '#9399b2',
   overlay1 = '#7f849c',
   overlay0 = '#6c7086',
   surface2 = '#585b70',
   surface1 = '#45475a',
   surface0 = '#313244',
   base = '#002b36',
   mantle = '#181825',
   crust = '#11111b',
}

local colorscheme = {
   background = palette.base,
   tab_bar = {
      background = palette.base,
      active_tab = {
         bg_color = palette.surface2,
         fg_color = palette.text,
      },
      inactive_tab = {
         bg_color = palette.surface0,
         fg_color = palette.subtext1,
      },
      inactive_tab_hover = {
         bg_color = palette.surface0,
         fg_color = palette.text,
      },
      new_tab = {
         bg_color = palette.base,
         fg_color = palette.text,
      },
      new_tab_hover = {
         bg_color = palette.mantle,
         fg_color = palette.text,
         italic = true,
      },
   },
}

return colorscheme
