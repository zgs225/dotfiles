require("outline").setup {}

local autocmd = vim.api.nvim_create_autocmd

autocmd({ "BufEnter" }, {
  group = vim.api.nvim_create_augroup("Outline", { clear = true }),
  callback = function(args)
    local buf_name = vim.api.nvim_buf_get_name(args.buf) ---@type string
    local pattern = "^.*OUTLINE_%d+"
    local win_n = #vim.api.nvim_tabpage_list_wins(0)
    if win_n == 1 and buf_name:match(pattern) ~= nil then
      vim.cmd "quit"
    end
  end,
})
