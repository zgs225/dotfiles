local M = {}

M.renderer = {
  group_empty = true,
}

M.on_attach = function(bufnr)
  local api = require "nvim-tree.api"
  local map = vim.keymap.set

  local function opts(desc)
    return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
  end

  -- default mappings
  api.config.mappings.default_on_attach(bufnr)

  map("n", "s", api.node.open.vertical, opts "Open: Vertical Split")
  map("n", "i", api.node.open.horizontal, opts "Open: Horizontal Split")
  map("n", "x", api.node.navigate.parent_close, opts "Close Parent Folder")
  map("n", "t", api.node.open.tab, opts "Open: In New Tab")
  map("n", "?", api.tree.toggle_help, opts "Help")
end

return M
