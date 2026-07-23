-- Vendored from nvchad/ui v3.0: lua/nvchad/blink/init.lua (BETA)
-- NvChad-styled blink.cmp completion menu, driven by chadrc ui.cmp options.
-- When upgrading to NvChad v3.0, delete this file and use
-- { import = "nvchad.blink.lazyspec" } instead.

local M = {}
local ui = require("nvconfig").ui.cmp
local atom_styled = ui.style == "atom" or ui.style == "atom_colored"

local menu_cols
if atom_styled or ui.icons_left then
  menu_cols = { { "kind_icon" }, { "label" }, { "kind" } }
else
  menu_cols = { { "label" }, { "kind_icon" }, { "kind" } }
end

M.components = {
  kind_icon = {
    text = function(ctx)
      local icons = require "nvchad.icons.lspkind"
      local icon = (icons[ctx.kind] or "󰈚")

      if atom_styled then
        icon = " " .. icon .. " "
      end

      return icon
    end,
  },

  kind = {
    highlight = function(ctx)
      return atom_styled and "comment" or ctx.kind
    end,
  },
}

M.menu = {
  scrollbar = false,
  border = atom_styled and "none" or "single",
  draw = {
    padding = { atom_styled and 0 or 1, 1 },
    columns = menu_cols,
    components = M.components,
  },
}

return M
