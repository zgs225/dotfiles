local M = {}

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
  map("n", "?", api.tree.toggle_help, opts "Help")
end

local autocmd = vim.api.nvim_create_autocmd

autocmd({ "BufEnter" }, {
  group = vim.api.nvim_create_augroup("NvimTreePost", { clear = true }),
  callback = function(args)
    local win_n = #vim.api.nvim_tabpage_list_wins(0)
    local buf_name = vim.api.nvim_buf_get_name(args.buf) ---@type string
    local pattern = "^.*NvimTree_%d+$"
    if win_n == 1 and buf_name:match(pattern) ~= nil then
      vim.cmd "q"
    end
  end,
})

return M
