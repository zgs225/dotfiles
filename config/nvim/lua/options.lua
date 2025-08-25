require "nvchad.options"

local o = vim.o
o.cursorlineopt = "both" -- to enable cursorline!
o.swapfile = false

-- to fix nvim-notify bug, see https://github.com/rcarriga/nvim-notify/issues/188
vim.cmd [[
hi NotifyBackground guibg = #000000
]]

-- file type detects

local detect_gotmpl = {
  function()
    if vim.fn.search("{{.+}}", "nw") then
      return "gotmpl"
    end
  end,
  { priority = 200 },
}

vim.filetype.add {
  extension = {
    gotmpl = "gotmpl",
  },

  pattern = {
    [".*/templates/.*%.tmpl"] = detect_gotmpl,
    [".*/templates/.*%.yaml"] = detect_gotmpl,
    [".*%.yaml.tmpl"] = detect_gotmpl,
  },
}

if vim.fn.exists "&messagesopt" == 1 then
  o.messagesopt = "wait:150,history:500"
end

-- Makefile 特定设置
vim.api.nvim_create_autocmd("FileType", {
  pattern = "make",
  callback = function()
    vim.opt_local.expandtab = false
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.list = true
    vim.opt_local.listchars = { tab = "→ ", trail = "·" }
  end,
})
