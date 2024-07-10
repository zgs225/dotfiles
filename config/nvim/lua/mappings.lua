require "nvchad.mappings"

-- add yours here
local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("n", "<leader>q", ":q<CR>", { desc = "General quit current buffer" })
map("n", "<leader>w", ":w<CR>", { desc = "General save current buffer" })
map("n", "<C-p>", ":Telescope find_files<CR>")

-- Tab navigation
map("n", "tp", ":tabprevious<CR>", { desc = "Tab previous" })
map("n", "tn", ":tabnext<CR>", { desc = "Tab next" })
map("n", "tm", ":tabmove", { desc = "Tab move" })

map("n", "<F5>", "<cmd>NvimTreeToggle<CR>", { desc = "nvimtree toggle window" })
map("n", "<leader>n", "<cmd>NvimTreeFocus<CR>", { desc = "nvimtree focus" })
-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
