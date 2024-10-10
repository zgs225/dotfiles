-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v2.5/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

---@param key string
local function button_prepend_leader(key)
  local leader = vim.g.mapleader
  if leader == nil then
    leader = ""
  end
  return leader .. " " .. key:gsub("^%s*(.-)%s*$", "%1")
end

M.nvdash = {
  load_on_startup = true,

  buttons = {
    { txt = "  Find File", keys = button_prepend_leader "f f", cmd = "Telescope find_files" },
    { txt = "󰈚  Recent Files", keys = button_prepend_leader "f o", cmd = "Telescope oldfiles" },
    { txt = "󰈭  Find Word", keys = button_prepend_leader "f w", cmd = "Telescope live_grep" },
    { txt = "  Bookmarks", keys = button_prepend_leader "f a", cmd = "Telescope marks" },
    { txt = "  Themes", keys = button_prepend_leader "t h", cmd = "Telescope themes" },
    { txt = "  Mappings", keys = button_prepend_leader "c h", cmd = "NvCheatsheet" },

    { txt = "─", hl = "NvDashLazy", no_gap = true, rep = true },

    {
      txt = function()
        local stats = require("lazy").stats()
        local ms = math.floor(stats.startuptime) .. " ms"
        return "  Loaded " .. stats.loaded .. "/" .. stats.count .. " plugins in " .. ms
      end,
      hl = "NvDashLazy",
      no_gap = true,
    },

    { txt = "─", hl = "NvDashLazy", no_gap = true, rep = true },
  },
}

M.ui = {
  tabufline = {
    order = { "treeOffset", "buffers", "tabs" },
  },

  statusline = {
    theme = "default",
  },
}

M.base46 = {
  theme = "solarized_osaka",

  transparency = true,

  hl_override = {
    Comment = { italic = true },
    ["@comment"] = { italic = true },
  },
}

return M
