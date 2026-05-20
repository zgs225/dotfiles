require "nvchad.mappings"

-- add yours here
local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("n", "<leader>q", ":q<CR>", { desc = "General quit current buffer" })
map("n", "<leader>w", ":w<CR>", { desc = "General save current buffer" })
map("n", "<C-p>", function()
  require("telescope").extensions.frecency.frecency {}
end, { desc = "Frecency file search" })

-- Tab navigation
map("n", "tp", ":tabprevious<CR>", { desc = "Tab previous" })
map("n", "tn", ":tabnext<CR>", { desc = "Tab next" })
map("n", "tm", ":tabmove", { desc = "Tab move" })

map("n", "<leader>n", "<cmd>NvimTreeFocus<CR>", { desc = "nvimtree focus" })
-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

-- Show Diagnostics under the line in popup window
map("n", "<leader>dp", function()
  vim.diagnostic.open_float { scope = "l" }
end, { desc = "LSP Diagnostics under the line" })

-- Terminal mode window navigation with state restore
local term_nav_group = vim.api.nvim_create_augroup("TermNavRestore", {})
local restore_on_enter = {}

local function terminal_navigate(dir)
  local bufnr = vim.api.nvim_get_current_buf()
  local was_term_mode = (vim.api.nvim_get_mode().mode == "t")
  if was_term_mode then
    restore_on_enter[bufnr] = true
    vim.cmd("stopinsert")
  end
  vim.cmd("wincmd " .. dir)
end

vim.api.nvim_create_autocmd("BufEnter", {
  group = term_nav_group,
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    if restore_on_enter[bufnr] then
      restore_on_enter[bufnr] = nil
      vim.schedule(function() vim.cmd("startinsert") end)
    end
  end,
})

map("t", "<C-h>", function() terminal_navigate("h") end, { desc = "terminal switch window left" })
map("t", "<C-l>", function() terminal_navigate("l") end, { desc = "terminal switch window right" })
map("t", "<C-j>", function() terminal_navigate("j") end, { desc = "terminal switch window down" })
map("t", "<C-k>", function() terminal_navigate("k") end, { desc = "terminal switch window up" })
