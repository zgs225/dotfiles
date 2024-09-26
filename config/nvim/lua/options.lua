require "nvchad.options"

local o = vim.o
o.cursorlineopt = "both" -- to enable cursorline!
o.swapfile = false

-- to fix nvim-notify bug, see https://github.com/rcarriga/nvim-notify/issues/188
vim.cmd [[
hi NotifyBackground guibg = #000000
]]
