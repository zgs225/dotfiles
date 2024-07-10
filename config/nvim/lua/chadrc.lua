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

M.ui = {
  theme = "onedark",

  hl_override = {
    Comment = { italic = true },
    ["@comment"] = { italic = true },
  },

  nvdash = {
    load_on_startup = true,

    buttons = {
      { "  Find File", button_prepend_leader "f f", "Telescope find_files" },
      { "󰈚  Recent Files", button_prepend_leader "f o", "Telescope oldfiles" },
      { "󰈭  Find Word", button_prepend_leader "f w", "Telescope live_grep" },
      { "  Bookmarks", button_prepend_leader "f a", "Telescope marks" },
      { "  Themes", button_prepend_leader "t h", "Telescope themes" },
      { "  Mappings", button_prepend_leader "c h", "NvCheatsheet" },
    },
  },

  statusline = {
    theme = "vscode_colored",
  },
}

return M
