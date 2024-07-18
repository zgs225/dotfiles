require("outline").setup {}

local autocmd = vim.api.nvim_create_autocmd

autocmd({ "BufEnter" }, {
  group = vim.api.nvim_create_augroup("Outline", { clear = true }),
  callback = function(args)
    local buf_name = vim.api.nvim_buf_get_name(args.buf) ---@type string
    local suffix = "OUTLINE_1"
    local tab_n = #vim.api.nvim_tabpage_list_wins(0)
    if tab_n == 1 and buf_name:sub(-#suffix) == suffix then
      vim.cmd "quit"
    end
  end,
})
